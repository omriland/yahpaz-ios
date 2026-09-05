import SwiftUI
import YahpazDomain

struct ShiftFormView: View {
    let shiftId: String?
    @EnvironmentObject private var app: AppModel

    @State private var shiftDate = returnDateToInput(israelToday())
    @State private var shiftKind = ""
    @State private var vehicleType = ""
    @State private var personalVehicleId: String?
    @State private var notes = ""
    @State private var responderIds: [String] = []
    @State private var crewVehicles: [CrewVehicleRow] = []
    @State private var vehiclesLoaded = false
    @State private var loaded = true
    @State private var loadFailed = false
    @State private var errors = ShiftDraftErrors()
    @State private var formError: String?
    @State private var saving = false

    private var editing: Bool { shiftId != nil }
    private var identityLocked: Bool { !canEditShiftIdentity(app.roles) }
    private var includePersonal: Bool { vehiclesLoaded && !crewVehicles.isEmpty }

    private var vehicleOptions: [(String, String)] {
        var base = offeredShiftVehicleTypes(includePersonal: includePersonal)
            .map { ($0, shiftVehicleTypeLabel($0)) }
        if !vehicleType.isEmpty && !base.contains(where: { $0.0 == vehicleType }) {
            base.append((vehicleType, shiftVehicleTypeLabel(vehicleType)))
        }
        return base
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    formBody
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .yahpazFormScroll()
            .background(FieldTheme.page.ignoresSafeArea())
            .navigationTitle(editing ? SHIFT_EDIT_TITLE : SHIFT_NEW_TITLE)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("חזרה") { app.closeShiftForm() }
                        .foregroundStyle(FieldTheme.accent)
                }
            }
            .yahpazKeyboardAccessory()
        }
        .task(id: app.userId) {
            if app.assignableProfiles.isEmpty && !app.assignableProfilesLoading {
                await app.reloadAssignableProfiles()
            }
        }
        .task(id: shiftId) {
            await loadDetail()
        }
        .task(id: responderIds.joined(separator: ",")) {
            await loadCrewVehicles()
        }
    }

    @ViewBuilder
    private var formBody: some View {
        if loadFailed {
            EmptyState(title: SHIFT_EDIT_LOAD_FAILED, actionTitle: "חזרה") {
                app.closeShiftForm()
            }
        } else if editing && !loaded {
            ProgressView("טוען משמרת…")
                .frame(maxWidth: .infinity, minHeight: 120)
        } else if app.assignableProfilesFailed && app.assignableProfiles.isEmpty {
            EmptyState(
                title: "טעינת רשימת המתנדבים נכשלה. בדקו את החיבור ונסו שוב.",
                actionTitle: "רענון"
            ) {
                Task { await app.reloadAssignableProfiles() }
            }
        } else if app.assignableProfiles.isEmpty {
            ProgressView("טוען מתנדבים…")
                .frame(maxWidth: .infinity, minHeight: 120)
        } else {
            fields
        }
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: 12) {
            ReturnDateField(
                label: "תאריך",
                error: errors.shiftDate,
                enabled: !identityLocked,
                text: $shiftDate
            )
            OptionRowSelector(
                label: "שם משמרת",
                options: SHIFT_KIND_ORDER.map { ($0, shiftKindLabel($0)) },
                selected: shiftKind,
                enabled: !identityLocked,
                error: errors.shiftKind
            ) { shiftKind = $0 }
            OptionRowSelector(
                label: "סוג רכב",
                options: vehicleOptions,
                selected: vehicleType,
                enabled: !identityLocked,
                error: errors.vehicleType
            ) { next in
                vehicleType = next
                if next != "personal" { personalVehicleId = nil }
            }
            if vehicleType == "personal" && includePersonal {
                LookupPickerField(
                    label: "לוחית",
                    options: crewVehicles.map {
                        LookupOption(id: $0.id, name: crewVehicleLabel(plateNumber: $0.plateNumber, model: $0.model))
                    },
                    selectedId: personalVehicleId ?? "",
                    placeholder: responderIds.isEmpty ? "יש לשבץ מתנדבים תחילה" : "בחירת לוחית",
                    searchPlaceholder: "חיפוש לוחית",
                    error: errors.plate,
                    enabled: !identityLocked
                ) { personalVehicleId = $0.isEmpty ? nil : $0 }
            }
            CrewAssignmentSection(
                assignOpenLabel: SHIFT_ASSIGN_OPEN,
                assignCloseLabel: SHIFT_ASSIGN_CLOSE,
                profiles: app.assignableProfiles,
                selectedIds: responderIds,
                caption: shiftCrewSummary(responderIds.count),
                emptyHint: SHIFT_ASSIGN_EMPTY,
                emptyRoster: "אין משתמשים פעילים לשיבוץ.",
                emptyQuery: "לא נמצאו מתנדבים לשיבוץ",
                error: errors.crew,
                removeLabel: EVENT_ASSIGN_REMOVE
            ) { responderIds = toggleCrewSelection(responderIds, responderId: $0) }
            FormArea(label: "הערות כלליות", minHeight: 96, text: $notes)
            if let formError {
                Text(formError)
                    .font(TypeScale.caption)
                    .foregroundStyle(FieldTheme.alert)
            }
            PrimaryButton(title: SHIFT_SAVE_TITLE, busy: saving, action: save)
        }
    }

    private func currentDraft() -> ShiftDraft {
        ShiftDraft(
            shiftDate: shiftDate,
            shiftKind: shiftKind,
            vehicleType: vehicleType,
            notes: notes,
            responderIds: responderIds,
            personalVehicleId: personalVehicleId
        )
    }

    private func save() {
        let draft = currentDraft()
        let next = validateShiftDraft(draft)
        errors = next
        if !next.isEmpty {
            formError = next.formMessage
            return
        }
        formError = nil
        Task {
            saving = true
            if let shiftId {
                formError = await app.updateUnitShift(shiftId, draft: draft)
            } else {
                formError = await app.createUnitShift(draft)
            }
            saving = false
        }
    }

    private func loadDetail() async {
        guard let shiftId else {
            loaded = true
            loadFailed = false
            return
        }
        loaded = false
        loadFailed = false
        do {
            let detail = try await YahpazAPI.shared.fetchShiftFormDetail(shiftId: shiftId)
            let draft = detail.toDraft()
            shiftDate = draft.shiftDate
            shiftKind = draft.shiftKind
            vehicleType = draft.vehicleType
            personalVehicleId = draft.personalVehicleId
            notes = draft.notes
            responderIds = draft.responderIds
            loaded = true
        } catch {
            loadFailed = true
            loaded = true
        }
    }

    private func loadCrewVehicles() async {
        if responderIds.isEmpty {
            if editing && !loaded { return }
            crewVehicles = []
            vehiclesLoaded = true
            personalVehicleId = nil
            if vehicleType == "personal" { vehicleType = "" }
            return
        }
        vehiclesLoaded = false
        do {
            let rows = try await YahpazAPI.shared.fetchVehiclesForResponders(responderIds)
            crewVehicles = rows
            vehiclesLoaded = true
            personalVehicleId = keepPersonalVehicleId(personalVehicleId, availableIds: Set(rows.map(\.id)))
            if vehicleType == "personal" && rows.isEmpty { vehicleType = "" }
        } catch {
            crewVehicles = []
            vehiclesLoaded = false
        }
    }
}
