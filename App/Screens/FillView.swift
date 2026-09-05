import SwiftUI
import YahpazDomain

private enum FillPane {
    case docs
    case media
}

private let fillStashDebounceNs: UInt64 = 600_000_000

struct FillView: View {
    let eventId: String
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var context: FillContext?
    @State private var draft = ResponderFillDraft.empty()
    @State private var errors = ResponderFillErrors()
    @State private var formError: String?
    @State private var loading = true
    @State private var failed = false
    @State private var savingDraft = false
    @State private var completing = false
    @State private var plateLookupGeneration = 0
    @State private var pane: FillPane = .docs
    @State private var unfinishedMediaDrafts = 0
    @State private var dropUnfinishedTick = 0
    @State private var plateScanOpen = false
    @State private var localSavedAt: Int64 = 0
    @State private var restoredFromDevice = false
    @State private var stashTask: Task<Void, Never>?

    var body: some View {
        Group {
            if loading {
                ProgressView("טוען את הדיווח…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if failed || context == nil {
                EmptyState(
                    title: "טעינת הדיווח נכשלה. בדקו את החיבור ונסו שוב.",
                    actionTitle: "רענון"
                ) {
                    Task { await load() }
                }
            } else if let context {
                filled(context)
            }
        }
        .background(FieldTheme.page.ignoresSafeArea())
        .navigationTitle("השלמת התיעוד שלי")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("חזרה") { onFillBack() }
                    .foregroundStyle(FieldTheme.accent)
            }
        }
        .yahpazKeyboardAccessory()
        .safeAreaInset(edge: .top, spacing: 0) {
            if let context, !isReadOnly(context), localSavedAt > 0 {
                Text("נשמר במכשיר \(fillDraftSavedLabel(savedAtMillis: localSavedAt))")
                    .font(TypeScale.caption)
                    .foregroundStyle(FieldTheme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
            } else if let context, !isReadOnly(context) {
                Text("הפרטים נשמרים במכשיר עד לשליחה.")
                    .font(TypeScale.caption)
                    .foregroundStyle(FieldTheme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
            }
        }
        .task(id: eventId) {
            let loadState = (context != nil && context?.eventId == eventId && !failed) ? "ready" : "loading"
            if shouldKeepLiveFormBoot(
                loadState: loadState,
                hasTypedDraft: context != nil && context?.eventId == eventId
            ) {
                return
            }
            await load()
        }
        .onChange(of: draft) { _, _ in
            guard let fill = context, !isReadOnly(fill) else { return }
            FillDraftStore.rememberLive(assignmentId: fill.assignmentId, draft: draft)
            stashTask?.cancel()
            stashTask = Task {
                try? await Task.sleep(nanoseconds: fillStashDebounceNs)
                if Task.isCancelled { return }
                persistLocalDraft()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background || phase == .inactive {
                persistLocalDraft()
            }
        }
        .onAppear { app.fillEventId = eventId }
        .onDisappear {
            persistLocalDraft()
            if app.fillEventId == eventId { app.fillEventId = nil }
        }
        .fullScreenCover(isPresented: $plateScanOpen) {
            PlateScanView(
                onDismiss: { plateScanOpen = false },
                onPlateScanned: { digits in
                    plateScanOpen = false
                    commitTreatedPlate(pendingOverride: digits)
                }
            )
        }
    }

    private func filled(_ context: FillContext) -> some View {
        let readOnly = isReadOnly(context)
        let mediaWritable = !context.isCancelled
        return VStack(spacing: 0) {
            HStack(spacing: 8) {
                fillPaneTab(label: EVENT_MEDIA_DOCS_TAB_LABEL, selected: pane == .docs) {
                    pane = .docs
                }
                fillPaneTab(label: EVENT_MEDIA_TAB_LABEL, selected: pane == .media) {
                    pane = .media
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            ZStack {
                docsForm(context)
                    .opacity(pane == .docs ? 1 : 0)
                    .allowsHitTesting(pane == .docs)
                FillMediaTab(
                    eventId: context.eventId,
                    viewerId: app.userId,
                    canWrite: mediaWritable,
                    leftoverError: errors.eventMedia,
                    dropUnfinishedTick: dropUnfinishedTick,
                    onUnfinishedChange: { unfinishedMediaDrafts = $0 },
                    onToast: { text, tone in app.showToast(text, tone: tone) }
                )
                .opacity(pane == .media ? 1 : 0)
                .allowsHitTesting(pane == .media)
            }
            if !readOnly && pane == .docs {
                VStack(spacing: 8) {
                    PrimaryButton(title: "סיום דיווח", busy: completing) {
                        Task { await save(complete: true) }
                    }
                    GhostButton(title: "שמירת טיוטה", enabled: !savingDraft && !completing) {
                        Task { await save(complete: false) }
                    }
                }
                .padding(16)
                .background(FieldTheme.raised)
                .overlay(alignment: .top) { Rectangle().fill(FieldTheme.hairline).frame(height: 1) }
            }
        }
    }

    private func fillPaneTab(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(selected ? TypeScale.bodyStrong : TypeScale.body)
                .foregroundStyle(selected ? FieldTheme.accent : FieldTheme.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(selected ? FieldTheme.accentSubtle : FieldTheme.raised)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(selected ? FieldTheme.accent : FieldTheme.strong, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func docsForm(_ context: FillContext) -> some View {
        let readOnly = isReadOnly(context)
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                summary(context)
                if restoredFromDevice && !readOnly {
                    Text("שוחזרו פרטים שנשמרו במכשיר ולא נשלחו. בדקו אותם ולחצו על סיום דיווח.")
                        .font(TypeScale.body)
                        .foregroundStyle(FieldTheme.textPrimary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(FieldTheme.accentSubtle)
                }
                if context.isCancelled {
                    Text("האירוע נסגר. לא ניתן לערוך את הדיווח.")
                        .font(TypeScale.body)
                        .foregroundStyle(FieldTheme.textPrimary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(FieldTheme.accentSubtle)
                }
                if readOnly {
                    StampWithNote(
                        stamp: participationStamp(context.participationStatus, isViewer: true),
                        note: leadKmPendingNote(context.participationStatus, totalKm: context.totalKm)
                    )
                    if let updated = context.updatedAt {
                        Text(completedCaption(context, updatedAt: updated))
                            .font(TypeScale.caption)
                            .foregroundStyle(FieldTheme.textMuted)
                    }
                }
                Text("הפרטים שלי")
                    .font(TypeScale.section)
                    .foregroundStyle(FieldTheme.textPrimary)
                if context.vehicles.isEmpty {
                    Text("לא מקושר רכב למשתמש. פנו למנהל המערכת.")
                        .font(TypeScale.caption)
                        .foregroundStyle(FieldTheme.alert)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("לוחית רישוי")
                            .font(TypeScale.label)
                            .foregroundStyle(FieldTheme.textSecondary)
                        Picker("לוחית רישוי", selection: $draft.vehiclePlate) {
                            Text("בחירת רכב").tag("")
                            ForEach(context.vehicles) { vehicle in
                                Text(vehicle.label).tag(vehicle.plate)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .padding(.horizontal, 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(errors.vehiclePlate == nil ? FieldTheme.strong : FieldTheme.alert, lineWidth: 1)
                        )
                        .disabled(readOnly)
                        if let error = errors.vehiclePlate {
                            Text(error).font(TypeScale.caption).foregroundStyle(FieldTheme.alert)
                        }
                    }
                }
                FormField(
                    label: "מד אוץ התחלה",
                    keyboard: .numberPad,
                    mono: true,
                    error: errors.odometerStart,
                    text: $draft.odometerStart
                )
                .disabled(readOnly)
                FormField(
                    label: "מד אוץ סיום",
                    keyboard: .numberPad,
                    mono: true,
                    error: errors.odometerEnd,
                    text: $draft.odometerEnd
                )
                .disabled(readOnly)
                FormField(label: "נתיב נסיעה", error: errors.route, text: $draft.route)
                    .disabled(readOnly)
                FormArea(label: "פירוט הטיפול", error: errors.treatmentDetail, text: $draft.treatmentDetail)
                    .disabled(readOnly)
                treatedPlatesSection(readOnly: readOnly)
                FormArea(label: "הערות לטיפול", minHeight: 80, text: $draft.treatmentNotes)
                    .disabled(readOnly)
                if let formError {
                    Text(formError)
                        .font(TypeScale.body)
                        .foregroundStyle(FieldTheme.alert)
                }
            }
            .padding(16)
            .padding(.bottom, 120)
        }
        .yahpazFormScroll()
    }

    @ViewBuilder
    private func treatedPlatesSection(readOnly: Bool) -> some View {
        if readOnly {
            if !draft.treatedPlates.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("מספרי כלי רכב")
                        .font(TypeScale.label)
                        .foregroundStyle(FieldTheme.textSecondary)
                    ForEach(draft.treatedPlates, id: \.plateNumber) { row in
                        treatedPlateRow(row, removable: false)
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("מספרי כלי רכב")
                    .font(TypeScale.label)
                    .foregroundStyle(FieldTheme.textSecondary)
                ForEach(draft.treatedPlates, id: \.plateNumber) { row in
                    treatedPlateRow(row, removable: true)
                }
                HStack(alignment: .bottom, spacing: 8) {
                    TextField("xx-xxx-xx", text: Binding(
                        get: { draft.treatedPlatePending },
                        set: { draft.treatedPlatePending = digitsOnly($0) }
                    ))
                    .font(TypeScale.numeric)
                    .foregroundStyle(FieldTheme.textPrimary)
                    .keyboardType(.numbersAndPunctuation)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.done)
                    .onSubmit { commitTreatedPlate() }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .background(FieldTheme.raised)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(errors.treatedPlates == nil ? FieldTheme.strong : FieldTheme.alert, lineWidth: 1)
                    )
                    .environment(\.layoutDirection, .leftToRight)
                    Button("הוספה") { commitTreatedPlate() }
                        .font(TypeScale.bodyStrong)
                        .foregroundStyle(FieldTheme.accent)
                        .frame(minHeight: 44)
                        .padding(.horizontal, 12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(FieldTheme.strong, lineWidth: 1)
                        )
                }
                Button {
                    plateScanOpen = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "camera")
                        Text("סריקה ניסיונית")
                            .font(TypeScale.bodyStrong)
                    }
                    .foregroundStyle(FieldTheme.accent)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(FieldTheme.strong, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                if let error = errors.treatedPlates {
                    Text(error)
                        .font(TypeScale.caption)
                        .foregroundStyle(FieldTheme.alert)
                }
            }
        }
    }

    private func treatedPlateRow(_ row: TreatedPlate, removable: Bool) -> some View {
        HStack(spacing: 8) {
            LicensePlateView(plate: row.plateNumber)
            CarLogo(slug: row.logoSlug)
            if let caption = treatedPlateCaption(model: row.model, color: row.color) {
                Text(caption)
                    .font(TypeScale.body)
                    .foregroundStyle(FieldTheme.textSecondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Spacer(minLength: 0)
            }
            if removable {
                TextField("איפה הרכב הושאר", text: Binding(
                    get: { row.leftWhere ?? "" },
                    set: {
                        draft.treatedPlates = setTreatedPlateLeftWhere(
                            draft.treatedPlates,
                            plateDigitsKey: row.plateNumber,
                            leftWhere: $0
                        )
                    }
                ))
                .font(TypeScale.body)
                .foregroundStyle(FieldTheme.textPrimary)
                .padding(.horizontal, 8)
                .frame(minWidth: 140, maxWidth: 140, minHeight: 44, alignment: .leading)
                .background(FieldTheme.raised)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(FieldTheme.strong, lineWidth: 1)
                )
                Button {
                    draft.treatedPlates = removeTreatedPlate(
                        draft.treatedPlates,
                        plateDigitsKey: row.plateNumber
                    )
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FieldTheme.textMuted)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("הסרת מספר \(row.plateNumber)")
            } else if let left = row.leftWhere?.trimmingCharacters(in: .whitespacesAndNewlines), !left.isEmpty {
                Text(left)
                    .font(TypeScale.body)
                    .foregroundStyle(FieldTheme.textSecondary)
                    .lineLimit(2)
                    .frame(width: 140, alignment: .leading)
            }
        }
    }

    private func summary(_ context: FillContext) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            LedgerRow(label: "תאריך", value: formatDate(context.eventDate))
            LedgerRow(label: "מספר אירוע", value: context.policeEventId ?? "")
            LedgerRow(label: "סוג אירוע", value: context.eventTypeName ?? "")
            LedgerRow(label: "כביש", value: context.roadName ?? "")
            LedgerRow(label: "מיקום", value: context.location ?? "")
            LedgerRow(label: "אחמ״ש", value: context.shiftLeadName ?? "")
        }
        .padding(16)
        .background(FieldTheme.raised)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(FieldTheme.hairline, lineWidth: 1)
        )
    }

    private func isReadOnly(_ fill: FillContext) -> Bool {
        fill.participationStatus == .done || fill.eventStatus == .done || fill.isCancelled
    }

    private func nowMillis() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }

    private func persistLocalDraft() {
        guard let fill = context, !isReadOnly(fill) else { return }
        let now = nowMillis()
        FillDraftStore.stash(assignmentId: fill.assignmentId, draft: draft, now: now)
        localSavedAt = now
    }

    private func onFillBack() {
        switch decideFillBack(onMediaPane: pane == .media, unfinishedMediaDraftCount: unfinishedMediaDrafts) {
        case .dropUnfinishedPhoto:
            dropUnfinishedTick += 1
        case .showDocs:
            pane = .docs
        case .leave:
            persistLocalDraft()
            dismiss()
        }
    }

    private func commitTreatedPlate(pendingOverride: String? = nil) {
        let result = YahpazDomain.commitTreatedPlate(
            pending: pendingOverride ?? draft.treatedPlatePending,
            plates: draft.treatedPlates
        )
        switch result {
        case let .error(message):
            errors.treatedPlates = message
        case let .ok(plate, plates):
            draft.treatedPlates = plates
            draft.treatedPlatePending = ""
            errors.treatedPlates = nil
            enqueuePlateLookup(plate.plateNumber)
        }
    }

    private func enqueuePlateLookup(_ plateNumber: String) {
        plateLookupGeneration += 1
        let generation = plateLookupGeneration
        Task {
            let hit = await lookupPlate(plate: plateNumber)
            guard generation <= plateLookupGeneration, let hit else { return }
            draft.treatedPlates = applyTreatedPlateLookup(
                draft.treatedPlates,
                plateDigitsKey: plateNumber,
                hit: hit
            )
        }
    }

    private func completedCaption(_ context: FillContext, updatedAt: String) -> String {
        var parts = ["הדיווח הושלם ב־\(formatDateTime(updatedAt))."]
        if let note = leadKmPendingNote(context.participationStatus, totalKm: context.totalKm) {
            parts.append("\(note).")
        }
        parts.append("רק אחמ״ש יכול לערוך לאחר סיום.")
        return parts.joined(separator: " ")
    }

    private func load() async {
        loading = true
        failed = false
        restoredFromDevice = false
        do {
            let next = try await YahpazAPI.shared.fetchFillContext(eventId: eventId)
            context = next
            if let next {
                let now = nowMillis()
                let live = FillDraftStore.liveDraft(assignmentId: next.assignmentId)
                let stashed = FillDraftStore.read(assignmentId: next.assignmentId, now: now)
                if let live, live != next.draft {
                    draft = live
                    restoredFromDevice = true
                    localSavedAt = stashed?.savedAt ?? now
                } else if shouldPreferStashedFillDraft(
                    stashed: stashed?.draft,
                    savedAt: stashed?.savedAt,
                    server: next.draft,
                    now: now
                ), let stashed {
                    draft = stashed.draft
                    restoredFromDevice = true
                    localSavedAt = stashed.savedAt
                } else {
                    draft = next.draft
                    localSavedAt = stashed?.savedAt ?? 0
                }
            } else {
                failed = true
            }
        } catch {
            failed = true
        }
        loading = false
    }

    private func save(complete: Bool) async {
        guard let context else { return }
        formError = nil
        let nextErrors = validateResponderFillDraft(
            draft,
            mode: complete ? .complete : .draft,
            allowedPlates: context.vehicles.map(\.plate),
            totalKm: context.totalKm,
            unfinishedMediaDraftCount: unfinishedMediaDrafts
        )
        errors = nextErrors
        if nextErrors.eventMedia != nil {
            pane = .media
        }
        if complete { completing = true } else { savingDraft = true }
        let error = await YahpazAPI.shared.saveFill(
            context: context,
            draft: draft,
            complete: complete,
            unfinishedMediaDraftCount: unfinishedMediaDrafts
        )
        completing = false
        savingDraft = false
        if let error {
            formError = error
            if error == errors.eventMedia {
                pane = .media
            }
            app.showToast(error, tone: .pending)
            return
        }
        if complete {
            FillDraftStore.clear(assignmentId: context.assignmentId)
        }
        app.showToast(complete ? "הדיווח הושלם" : "הטיוטה נשמרה", tone: .done)
        await app.reloadEvents()
        dismiss()
    }
}
