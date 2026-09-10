import AVFoundation
import PhotosUI
import SwiftUI
import YahpazDomain

struct FeedbackMiniFab: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "bubble.left")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(FieldTheme.textOnAccent)
                .frame(width: 56, height: 56)
                .background(FieldTheme.accent)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(FEEDBACK_LABEL)
    }
}

func feedbackPagePathForUi(
    fillEventId: String?,
    tab: AppModel.Tab,
    overlay: String
) -> String {
    let tabName: String
    switch tab {
    case .mine: tabName = "inbox"
    case .myShifts: tabName = "my_shifts"
    case .contacts: tabName = "contacts"
    case .events: tabName = "events"
    case .shifts: tabName = "shifts"
    case .users: tabName = "users"
    case .reports: tabName = "reports"
    case .profile: tabName = "profile"
    }
    return feedbackPagePath(fillEventId: fillEventId, tab: tabName, toolsDestination: overlay)
}

func feedbackOverlayName(eventForm: AppModel.EventFormRoute?, shiftForm: AppModel.ShiftFormRoute?) -> String {
    if let eventForm {
        switch eventForm {
        case .create: return "NEW_EVENT"
        case .edit: return "EDIT_EVENT"
        }
    }
    if let shiftForm {
        switch shiftForm {
        case .create: return "NEW_SHIFT"
        case .edit: return "EDIT_SHIFT"
        }
    }
    return "HUB"
}

struct FeedbackSheet: View {
    let pagePath: String
    let onDismiss: () -> Void
    let onHideUntilRefresh: () -> Void
    let onSubmit: (String, String, Data?, String?, [FeedbackAttachmentUpload]) async -> String?

    @State private var kind: String?
    @State private var bodyText = ""
    @State private var error: String?
    @State private var busy = false
    @State private var recording = false
    @State private var elapsed = 0
    @State private var audioURL: URL?
    @State private var recorder: AVAudioRecorder?
    @State private var files: [FeedbackPickedUi] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var timerTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("סוג")
                    .font(TypeScale.label)
                    .foregroundStyle(FieldTheme.textMuted)
                HStack(spacing: 8) {
                    KindChip(label: FEEDBACK_KIND_BUG, selected: kind == "bug") {
                        kind = "bug"
                        error = nil
                    }
                    KindChip(label: FEEDBACK_KIND_SUGGESTION, selected: kind == "suggestion") {
                        kind = "suggestion"
                        error = nil
                    }
                }
                Text("הערה")
                    .font(TypeScale.label)
                    .foregroundStyle(FieldTheme.textMuted)
                Text("אפשר לכתוב, להקליט, לצרף קבצים, או לשלב.")
                    .font(TypeScale.caption)
                    .foregroundStyle(FieldTheme.textMuted)
                TextField("למשל: אחרי שמירה המסך נשאר ריק", text: $bodyText, axis: .vertical)
                    .lineLimit(4...10)
                    .padding(12)
                    .frame(minHeight: 120, alignment: .topLeading)
                    .background(FieldTheme.sunken)
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundStyle(FieldTheme.hairline),
                        alignment: .bottom
                    )
                    .onChange(of: bodyText) { _, next in
                        if next.count > FEEDBACK_BODY_MAX {
                            bodyText = String(next.prefix(FEEDBACK_BODY_MAX))
                        }
                        error = nil
                    }
                recordControls
                Text("קבצים")
                    .font(TypeScale.label)
                    .foregroundStyle(FieldTheme.textMuted)
                Text(FEEDBACK_ATTACH_HINT)
                    .font(TypeScale.caption)
                    .foregroundStyle(FieldTheme.textMuted)
                ForEach(Array(files.enumerated()), id: \.offset) { index, file in
                    HStack(spacing: 8) {
                        Text(file.name)
                            .font(TypeScale.body)
                            .foregroundStyle(FieldTheme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button {
                            files.remove(at: index)
                            error = nil
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(FieldTheme.alert)
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .disabled(busy || recording)
                        .accessibilityLabel("הסרת קובץ")
                    }
                }
                if files.count < FEEDBACK_ATTACH_MAX {
                    PhotosPicker(
                        selection: $pickerItems,
                        maxSelectionCount: FEEDBACK_ATTACH_MAX,
                        matching: .any(of: [.images, .videos])
                    ) {
                        HStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle.angled")
                            Text(FEEDBACK_ATTACH_ADD)
                                .font(TypeScale.bodyStrong)
                        }
                        .foregroundStyle(FieldTheme.accent)
                        .frame(minHeight: 44)
                    }
                    .disabled(busy || recording)
                }
                if let error {
                    Text(error)
                        .font(TypeScale.caption)
                        .foregroundStyle(FieldTheme.alert)
                }
                PrimaryButton(
                    title: busy ? "שולח…" : "שליחה",
                    busy: busy,
                    enabled: !busy && !recording
                ) {
                    Task { await submit() }
                }
                Button {
                    guard !busy, !recording else { return }
                    releaseRecorder()
                    deleteAudio()
                    onHideUntilRefresh()
                    onDismiss()
                } label: {
                    Text(FEEDBACK_HIDE_UNTIL_REFRESH)
                        .font(TypeScale.body)
                        .foregroundStyle(FieldTheme.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                .disabled(busy || recording)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
            }
            .yahpazFormScroll()
            .yahpazKeyboardAccessory()
            .background(FieldTheme.page.ignoresSafeArea())
            .navigationTitle(FEEDBACK_LABEL)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("סגירה") {
                        guard !busy, !recording else { return }
                        onDismiss()
                    }
                    .disabled(busy || recording)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(busy)
        .onChange(of: pickerItems) { _, items in
            Task { await ingestPicker(items) }
        }
        .onChange(of: recording) { _, isRecording in
            timerTask?.cancel()
            guard isRecording else { return }
            let started = Date()
            timerTask = Task { @MainActor in
                while !Task.isCancelled {
                    let seconds = Int(Date().timeIntervalSince(started))
                    elapsed = seconds
                    if shouldAutoStopRecording(seconds) {
                        stopRecording()
                        break
                    }
                    try? await Task.sleep(nanoseconds: 250_000_000)
                }
            }
        }
        .onDisappear {
            timerTask?.cancel()
            releaseRecorder()
        }
    }

    @ViewBuilder
    private var recordControls: some View {
        if recording {
            HStack(spacing: 12) {
                Button {
                    stopRecording()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "stop.fill")
                        Text("עצירת הקלטה")
                    }
                    .foregroundStyle(FieldTheme.accent)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                Text("\(formatRecordSeconds(elapsed)) / \(formatRecordSeconds(FEEDBACK_RECORD_MAX_SECONDS))")
                    .font(TypeScale.numeric)
                    .foregroundStyle(FieldTheme.textSecondary)
            }
        } else if audioURL != nil {
            HStack(spacing: 8) {
                Text("הקלטה מוכנה")
                    .font(TypeScale.body)
                    .foregroundStyle(FieldTheme.textPrimary)
                Button {
                    deleteAudio()
                    elapsed = 0
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(FieldTheme.alert)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("מחיקת הקלטה")
            }
        } else {
            Button {
                Task { await startRecordingTapped() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "mic")
                    Text("הקלטת הודעה")
                }
                .foregroundStyle(FieldTheme.accent)
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
        }
    }

    private func startRecordingTapped() async {
        let granted = await requestMic()
        if granted {
            error = startRecording()
        } else {
            error = FEEDBACK_MIC_ERROR
        }
    }

    private func requestMic() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    private func startRecording() -> String? {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("yahpaz-feedback-\(Int(Date().timeIntervalSince1970 * 1000)).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 96_000,
        ]
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            let rec = try AVAudioRecorder(url: file, settings: settings)
            rec.prepareToRecord()
            guard rec.record() else {
                try? FileManager.default.removeItem(at: file)
                return FEEDBACK_MIC_ERROR
            }
            deleteAudio()
            audioURL = file
            recorder = rec
            elapsed = 0
            recording = true
            return nil
        } catch {
            try? FileManager.default.removeItem(at: file)
            return FEEDBACK_MIC_ERROR
        }
    }

    private func stopRecording() {
        recorder?.stop()
        recorder = nil
        recording = false
        guard let url = audioURL else { return }
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0
        if size <= 0 {
            try? FileManager.default.removeItem(at: url)
            audioURL = nil
        }
    }

    private func releaseRecorder() {
        recorder?.stop()
        recorder = nil
        recording = false
    }

    private func deleteAudio() {
        if let url = audioURL {
            try? FileManager.default.removeItem(at: url)
        }
        audioURL = nil
    }

    private func ingestPicker(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        var next = files
        var nextError: String?
        for item in items {
            if next.count >= FEEDBACK_ATTACH_MAX {
                nextError = FEEDBACK_ATTACH_COUNT_ERROR
                break
            }
            guard let data = try? await item.loadTransferable(type: Data.self), !data.isEmpty else {
                continue
            }
            let mime = item.supportedContentTypes.first?.preferredMIMEType ?? ""
            let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "bin"
            let name = "קובץ.\(ext)"
            let fileError: String?
            if data.isEmpty {
                fileError = feedbackAttachmentKind(mime: mime, name: name) == nil
                    ? FEEDBACK_ATTACH_TYPE_ERROR
                    : nil
            } else {
                fileError = feedbackAttachmentError(FeedbackPickedMeta(name: name, mime: mime, size: data.count))
            }
            if let fileError {
                nextError = fileError
                continue
            }
            next.append(FeedbackPickedUi(name: name, mime: mime, bytes: data))
        }
        files = next
        error = nextError
        pickerItems = []
    }

    private func submit() async {
        let next = feedbackSubmitError(kind: kind, body: bodyText, hasAudio: audioURL != nil)
        if next != nil || kind == nil {
            error = next
            return
        }
        busy = true
        let bytes: Data? = {
            guard let url = audioURL else { return nil }
            return try? Data(contentsOf: url)
        }()
        let uploads = files.map { FeedbackAttachmentUpload(name: $0.name, mime: $0.mime, bytes: $0.bytes) }
        let check = addFeedbackAttachments(
            current: [],
            incoming: uploads.map { FeedbackPickedMeta(name: $0.name, mime: $0.mime, size: $0.bytes.count) }
        )
        if let checkError = check.error {
            busy = false
            error = checkError
            return
        }
        let fail = await onSubmit(
            kind ?? "bug",
            bodyText,
            bytes,
            bytes == nil ? nil : "audio/mp4",
            uploads
        )
        busy = false
        if let fail {
            error = fail
        } else {
            deleteAudio()
            onDismiss()
        }
    }
}

private struct KindChip: View {
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(TypeScale.bodyStrong)
                .foregroundStyle(selected ? FieldTheme.accent : FieldTheme.textSecondary)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .overlay(
                    Capsule()
                        .stroke(selected ? FieldTheme.accent : FieldTheme.hairline, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct FeedbackPickedUi {
    var name: String
    var mime: String
    var bytes: Data
}
