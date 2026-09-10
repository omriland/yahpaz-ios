import PhotosUI
import SwiftUI
import YahpazDomain

private struct MediaDraft: Identifiable {
    let id: String
    let image: UIImage
    let data: Data
    let mimeType: String
    var takenWhen: EventMediaTakenWhen?
    var treatedPlateIds: [String]
    var caption: String
    var uploading: Bool
    var error: String?
}

struct FillMediaTab: View {
    let eventId: String
    let viewerId: String?
    let canWrite: Bool
    let leftoverError: String?
    let dropUnfinishedTick: Int
    var onUnfinishedChange: (Int) -> Void
    var onToast: (String, StampTone) -> Void

    @State private var items: [EventMedia] = []
    @State private var plates: [EventMediaPlateOption] = []
    @State private var drafts: [MediaDraft] = []
    @State private var loading = true
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var viewer: EventMedia?
    @State private var immersive = false
    @State private var editing = false
    @State private var confirmDelete = false
    @State private var editTakenWhen: EventMediaTakenWhen = .beforeTreatment
    @State private var editPlateIds: [String] = []
    @State private var editCaption = ""
    @State private var editError: String?
    @State private var savingEdit = false
    @State private var deleting = false

    private var inFlight: Int { drafts.filter(\.uploading).count }
    private var addEnabled: Bool { canWrite && canAddMoreMedia(savedCount: items.count, inFlightCount: inFlight) }
    private var remaining: Int { slotsRemaining(savedCount: items.count, inFlightCount: inFlight) }

    var body: some View {
        let grouped = groupMediaByTakenWhen(items)
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(EVENT_MEDIA_TITLE)
                            .font(TypeScale.label)
                            .foregroundStyle(FieldTheme.textSecondary)
                        Spacer()
                        if canWrite {
                            Text("\(items.count)/\(EVENT_MEDIA_CAP)")
                                .font(TypeScale.caption)
                                .foregroundStyle(FieldTheme.textMuted)
                        }
                    }
                    if let leftoverError {
                        Text(leftoverError)
                            .font(TypeScale.caption)
                            .foregroundStyle(FieldTheme.alert)
                    }
                    if loading {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding(.vertical, 24)
                            Spacer()
                        }
                    }
                    if !loading && items.isEmpty && drafts.isEmpty && !canWrite {
                        Text(EVENT_MEDIA_EMPTY)
                            .font(TypeScale.body)
                            .foregroundStyle(FieldTheme.textMuted)
                    }
                    mediaBand(
                        heading: eventMediaTakenWhenLabel(.beforeTreatment),
                        items: grouped.before
                    )
                    mediaBand(
                        heading: eventMediaTakenWhenLabel(.duringAfterTreatment),
                        items: grouped.during
                    )
                    ForEach(drafts) { draft in
                        mediaDraftCard(draft)
                    }
                }
                .padding(16)
            }
            if canWrite {
                VStack(spacing: 8) {
                    PhotosPicker(
                        selection: $pickerItems,
                        maxSelectionCount: max(1, remaining),
                        matching: .images
                    ) {
                        HStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle.angled")
                            Text("הוספת תמונות")
                                .font(TypeScale.bodyStrong)
                        }
                        .foregroundStyle(addEnabled ? FieldTheme.accent : FieldTheme.textMuted)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(FieldTheme.strong, lineWidth: 1)
                        )
                    }
                    .disabled(!addEnabled)
                    if !addEnabled {
                        Text(EVENT_MEDIA_CAP_ERROR)
                            .font(TypeScale.caption)
                            .foregroundStyle(FieldTheme.textMuted)
                    }
                }
                .padding(16)
                .background(FieldTheme.raised)
            }
        }
        .task(id: eventId) {
            loading = true
            items = await YahpazAPI.shared.listEventMedia(eventId: eventId)
            plates = await YahpazAPI.shared.listEventMediaPlates(eventId: eventId)
            loading = false
        }
        .onChange(of: drafts.count) { _, _ in
            onUnfinishedChange(drafts.filter { $0.takenWhen == nil }.count)
        }
        .onChange(of: drafts.map(\.takenWhen)) { _, _ in
            onUnfinishedChange(drafts.filter { $0.takenWhen == nil }.count)
        }
        .onChange(of: dropUnfinishedTick) { _, tick in
            guard tick > 0 else { return }
            guard let last = drafts.last(where: { $0.takenWhen == nil && !$0.uploading }) else { return }
            drafts.removeAll { $0.id == last.id }
        }
        .onChange(of: pickerItems) { _, items in
            Task { await ingestPicker(items) }
        }
        .sheet(item: $viewer) { current in
            mediaViewer(current)
        }
        .fullScreenCover(isPresented: $immersive) {
            if let url = viewer.flatMap({ $0.signedUrl }).flatMap(URL.init(string:)) {
                ImmersiveImageViewer(url: url, caption: viewer?.caption) {
                    immersive = false
                }
            }
        }
    }

    @ViewBuilder
    private func mediaBand(heading: String, items: [EventMedia]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(heading)
                    .font(TypeScale.label)
                    .foregroundStyle(FieldTheme.textSecondary)
                let rows = stride(from: 0, to: items.count, by: 2).map { Array(items[$0..<min($0 + 2, items.count)]) }
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 8) {
                        ForEach(row) { item in
                            Button {
                                openViewer(item)
                            } label: {
                                mediaThumb(url: item.signedUrl, caption: item.caption ?? heading)
                            }
                            .buttonStyle(.plain)
                        }
                        if row.count == 1 { Spacer(minLength: 0) }
                    }
                }
            }
        }
    }

    private func mediaThumb(url: String?, caption: String) -> some View {
        Group {
            if let url, let parsed = URL(string: url) {
                AsyncImage(url: parsed) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        FieldTheme.sunken
                    }
                }
            } else {
                FieldTheme.sunken
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(FieldTheme.hairline, lineWidth: 1)
        )
        .accessibilityLabel(caption)
    }

    private func mediaDraftCard(_ draft: MediaDraft) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topLeading) {
                Image(uiImage: draft.image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .aspectRatio(4 / 3, contentMode: .fit)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                if draft.uploading {
                    Color.black.opacity(0.35)
                    ProgressView().tint(.white)
                }
                Button {
                    drafts.removeAll { $0.id == draft.id }
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                }
                .disabled(draft.uploading)
                .accessibilityLabel("הסרה")
            }
            mediaPlateChecklist(
                selected: draft.treatedPlateIds,
                enabled: !draft.uploading
            ) { next in
                patchDraft(draft.id) { $0.treatedPlateIds = next }
            }
            FormField(
                label: "תיאור",
                enabled: !draft.uploading,
                placeholder: "למשל: פגיעה בגלגל קדמי",
                text: Binding(
                    get: { draft.caption },
                    set: { value in patchDraft(draft.id) { $0.caption = value } }
                )
            )
            takenWhenPicker(value: draft.takenWhen, enabled: !draft.uploading, required: true) { when in
                startUpload(id: draft.id, takenWhen: when)
            }
            if let error = draft.error {
                Text(error)
                    .font(TypeScale.caption)
                    .foregroundStyle(FieldTheme.alert)
            }
            if draft.uploading {
                Text("מעלה…")
                    .font(TypeScale.caption)
                    .foregroundStyle(FieldTheme.textMuted)
            }
            if draft.error != nil {
                GhostButton(
                    title: "נסו שוב",
                    enabled: draft.takenWhen != nil && !draft.uploading
                ) {
                    if let when = draft.takenWhen {
                        startUpload(id: draft.id, takenWhen: when)
                    }
                }
            }
        }
        .padding(12)
        .background(FieldTheme.raised)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(FieldTheme.hairline, lineWidth: 1)
        )
    }

    private func takenWhenPicker(
        value: EventMediaTakenWhen?,
        enabled: Bool,
        required: Bool,
        onChange: @escaping (EventMediaTakenWhen) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("מתי צולמה")
                .font(TypeScale.label)
                .foregroundStyle(FieldTheme.textSecondary)
            ForEach(EventMediaTakenWhen.allCases, id: \.rawValue) { option in
                let selected = value == option
                Button {
                    onChange(option)
                } label: {
                    Text(eventMediaTakenWhenLabel(option))
                        .font(selected ? TypeScale.bodyStrong : TypeScale.body)
                        .foregroundStyle(selected ? FieldTheme.accent : FieldTheme.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .padding(.horizontal, 12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(
                                    selected
                                        ? FieldTheme.accent
                                        : (required && value == nil ? FieldTheme.alert : FieldTheme.strong),
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(.plain)
                .disabled(!enabled)
            }
        }
    }

    @ViewBuilder
    private func mediaPlateChecklist(
        selected: [String],
        enabled: Bool,
        onChange: @escaping ([String]) -> Void
    ) -> some View {
        if plates.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("רכבים בתמונה")
                    .font(TypeScale.label)
                    .foregroundStyle(FieldTheme.textSecondary)
                ForEach(plates) { plate in
                    let checked = selected.contains(plate.id)
                    Button {
                        onChange(togglePlateId(selected, id: plate.id))
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: checked ? "checkmark.square.fill" : "square")
                                .foregroundStyle(checked ? FieldTheme.accent : FieldTheme.textMuted)
                            mediaPlateRow(plate)
                            Spacer(minLength: 0)
                        }
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .disabled(!enabled)
                }
            }
        }
    }

    private func mediaPlateRow(_ plate: EventMediaPlateOption) -> some View {
        let caption = treatedPlateCaption(model: plate.model, color: plate.color)
        return HStack(spacing: 8) {
            CarLogo(slug: plate.logoSlug)
            LicensePlateView(plate: plate.plateNumber)
            if let caption {
                Text(caption)
                    .font(TypeScale.caption)
                    .foregroundStyle(FieldTheme.textSecondary)
                    .lineLimit(1)
            }
        }
    }

    private func mediaViewer(_ current: EventMedia) -> some View {
        let own = canWrite && viewerId != nil && current.uploadedBy == viewerId
        let linked = plates.filter { current.treatedPlateIds.contains($0.id) }
        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(eventMediaTakenWhenLabel(current.takenWhen))
                        .font(TypeScale.section)
                        .foregroundStyle(FieldTheme.textPrimary)
                    if let url = current.signedUrl, let parsed = URL(string: url) {
                        Button { immersive = true } label: {
                            AsyncImage(url: parsed) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().scaledToFit()
                                default:
                                    FieldTheme.sunken.frame(height: 180)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: 420)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(EVENT_MEDIA_NETWORK)
                            .font(TypeScale.body)
                            .foregroundStyle(FieldTheme.textMuted)
                    }
                    if editing {
                            takenWhenPicker(value: editTakenWhen, enabled: !savingEdit, required: false) {
                                editTakenWhen = $0
                            }
                            mediaPlateChecklist(selected: editPlateIds, enabled: !savingEdit) {
                                editPlateIds = $0
                            }
                            FormField(
                                label: "תיאור",
                                enabled: !savingEdit,
                                placeholder: "למשל: פגיעה בגלגל קדמי",
                                text: Binding(
                                    get: { editCaption },
                                    set: {
                                        editCaption = $0
                                        editError = nil
                                    }
                                )
                            )
                            if let editError {
                                Text(editError).font(TypeScale.caption).foregroundStyle(FieldTheme.alert)
                            }
                            PrimaryButton(title: "שמירה", busy: savingEdit) {
                                Task { await saveEdit(current) }
                            }
                            GhostButton(title: "ביטול", enabled: !savingEdit) { editing = false }
                        } else {
                            Text("תיאור")
                                .font(TypeScale.label)
                                .foregroundStyle(FieldTheme.textSecondary)
                            Text(current.caption?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "—")
                                .font(TypeScale.body)
                                .foregroundStyle(FieldTheme.textPrimary)
                            Text("רכבים בתמונה")
                                .font(TypeScale.label)
                                .foregroundStyle(FieldTheme.textSecondary)
                            if linked.isEmpty {
                                Text("—").font(TypeScale.body).foregroundStyle(FieldTheme.textPrimary)
                            } else {
                                ForEach(linked) { plate in
                                    mediaPlateRow(plate)
                                }
                            }
                            Text(
                                [current.uploaderName, formatDateTime(current.createdAt)]
                                    .compactMap { $0 }
                                    .joined(separator: " · ")
                            )
                            .font(TypeScale.caption)
                            .foregroundStyle(FieldTheme.textMuted)
                            if own {
                                GhostButton(title: "עריכה") { editing = true }
                                GhostButton(title: "מחיקה", danger: true) { confirmDelete = true }
                            }
                        }
                }
                .padding(16)
            }
            .yahpazFormScroll()
            .yahpazKeyboardAccessory()
            .background(FieldTheme.page.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("סגירה") {
                        viewer = nil
                        editing = false
                        confirmDelete = false
                    }
                }
            }
            .confirmationDialog("למחוק את התמונה?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("מחיקה", role: .destructive) {
                    Task { await deleteCurrent(current) }
                }
                Button("ביטול", role: .cancel) {}
            } message: {
                Text("לא ניתן לשחזר.")
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private func openViewer(_ item: EventMedia) {
        viewer = item
        editing = false
        confirmDelete = false
        editTakenWhen = item.takenWhen
        editPlateIds = item.treatedPlateIds
        editCaption = item.caption ?? ""
        editError = nil
    }

    private func patchDraft(_ id: String, _ body: (inout MediaDraft) -> Void) {
        drafts = drafts.map { row in
            guard row.id == id else { return row }
            var next = row
            body(&next)
            return next
        }
    }

    private func ingestPicker(_ picked: [PhotosPickerItem]) async {
        guard !picked.isEmpty, addEnabled else {
            pickerItems = []
            return
        }
        let take = Array(picked.prefix(remaining))
        var next: [MediaDraft] = []
        for item in take {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data)
            else { continue }
            let mime = item.supportedContentTypes.first?.preferredMIMEType ?? "image/jpeg"
            next.append(
                MediaDraft(
                    id: UUID().uuidString,
                    image: image,
                    data: data,
                    mimeType: mime,
                    takenWhen: nil,
                    treatedPlateIds: [],
                    caption: "",
                    uploading: false,
                    error: nil
                )
            )
        }
        drafts.append(contentsOf: next)
        pickerItems = []
        plates = await YahpazAPI.shared.listEventMediaPlates(eventId: eventId)
    }

    private func startUpload(id: String, takenWhen: EventMediaTakenWhen) {
        guard let draft = drafts.first(where: { $0.id == id }) else { return }
        patchDraft(id) {
            $0.uploading = true
            $0.error = nil
            $0.takenWhen = takenWhen
        }
        Task {
            let compressed = compressEventImage(data: draft.data, mimeType: draft.mimeType)
            guard case let .ok(image) = compressed else {
                if case let .error(message) = compressed {
                    patchDraft(id) {
                        $0.uploading = false
                        $0.error = message
                    }
                }
                return
            }
            let latest = drafts.first(where: { $0.id == id }) ?? draft
            let result = await YahpazAPI.shared.uploadEventMedia(
                eventId: eventId,
                jpegBytes: image.bytes,
                width: image.width,
                height: image.height,
                takenWhen: takenWhen,
                treatedPlateIds: latest.treatedPlateIds,
                caption: latest.caption.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            )
            switch result {
            case .uploaded(let media):
                drafts.removeAll { $0.id == id }
                items.append(media)
                onToast(EVENT_MEDIA_ADDED, .done)
            case .error(let message):
                patchDraft(id) {
                    $0.uploading = false
                    $0.error = message
                }
            case .done:
                patchDraft(id) {
                    $0.uploading = false
                    $0.error = EVENT_MEDIA_NETWORK
                }
            }
        }
    }

    private func saveEdit(_ current: EventMedia) async {
        if let issue = captionError(editCaption) {
            editError = issue
            return
        }
        savingEdit = true
        let result = await YahpazAPI.shared.updateEventMedia(
            id: current.id,
            takenWhen: editTakenWhen,
            treatedPlateIds: editPlateIds,
            caption: editCaption.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )
        savingEdit = false
        switch result {
        case .done:
            var next = current
            next.takenWhen = editTakenWhen
            next.treatedPlateIds = editPlateIds
            let trimmed = editCaption.trimmingCharacters(in: .whitespacesAndNewlines)
            next.caption = trimmed.isEmpty ? nil : trimmed
            items = items.map { $0.id == next.id ? next : $0 }
            viewer = next
            editing = false
            onToast(EVENT_MEDIA_UPDATED, .done)
        case .error(let message):
            editError = message
            onToast(message, .pending)
        case .uploaded:
            break
        }
    }

    private func deleteCurrent(_ current: EventMedia) async {
        deleting = true
        let result = await YahpazAPI.shared.deleteEventMedia(id: current.id, storagePath: current.storagePath)
        deleting = false
        switch result {
        case .done:
            items.removeAll { $0.id == current.id }
            immersive = false
            viewer = nil
            confirmDelete = false
            onToast(EVENT_MEDIA_DELETED, .done)
        case .error(let message):
            onToast(message, .pending)
        case .uploaded:
            break
        }
    }
}

private struct ImmersiveImageViewer: View {
    let url: URL
    let caption: String?
    var onDismiss: () -> Void
    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnifyGesture()
                                .onChanged { value in
                                    scale = min(8, max(1, value.magnification))
                                    if scale <= 1.01 { offset = .zero }
                                }
                        )
                default:
                    ProgressView().tint(.white)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
            }
            .padding(8)
            .accessibilityLabel("סגירה")
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
