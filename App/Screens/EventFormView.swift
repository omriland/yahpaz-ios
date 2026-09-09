import SwiftUI
import YahpazDomain

struct EventFormView: View {
    let eventId: String?
    @EnvironmentObject private var app: AppModel

    @State private var eventDate = returnDateToInput(israelToday())
    @State private var policeEventId = ""
    @State private var patrolCallsign = ""
    @State private var eventTypeId = ""
    @State private var roadId = ""
    @State private var districtId = ""
    @State private var location = ""
    @State private var station = ""
    @State private var notes = ""
    @State private var responders: [EventResponderDraft] = []
    @State private var isCancelled = false
    @State private var busLane = false
    @State private var previousIsCancelled = false
    @State private var shiftLeadId = ""
    @State private var shiftLeadName = ""
    @State private var shiftLeadCallsign = ""
    @State private var secondaryLeads: [SecondaryLead] = []
    @State private var shiftLeadUsers: [AssignableProfile] = []
    @State private var persistedDraft: EventDraft?
    @State private var foreignEditAcked = false
    @State private var assignedBlocked = false
    @State private var loaded = true
    @State private var loadFailed = false
    @State private var errors = EventDraftErrors()
    @State private var formError: String?
    @State private var saving = false
    @State private var confirmDelete = false
    @State private var deleting = false
    @State private var deleteHint: String?
    @State private var vehicleOwnerIds: Set<String> = []
    @State private var detailResponderId: String?

    private var editing: Bool { eventId != nil }

    private var foreignEditPending: Bool {
        editing && loaded && !loadFailed && !assignedBlocked
            && isForeignShiftLeadEvent(viewerId: app.userId, shiftLeadId: shiftLeadId)
            && !foreignEditAcked
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
            .navigationTitle(editing ? EVENT_EDIT_TITLE : EVENT_NEW_TITLE)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("חזרה") { app.closeEventForm() }
                        .foregroundStyle(FieldTheme.accent)
                }
            }
            .yahpazKeyboardAccessory()
            .confirmationDialog(EVENT_DELETE_TITLE, isPresented: $confirmDelete, titleVisibility: .visible) {
                Button(EVENT_DELETE_ACTION, role: .destructive) { performEventDelete() }
                Button("ביטול", role: .cancel) {}
            } message: {
                Text(EVENT_DELETE_CONFIRM)
            }
        }
        .task(id: app.userId) {
            if app.lookups.isEmpty && !app.lookupsLoading {
                await app.reloadLookups()
            }
            if !editing && shiftLeadId.isEmpty {
                shiftLeadId = app.userId ?? ""
                shiftLeadName = app.profile?.fullName ?? ""
                shiftLeadCallsign = app.profile?.callsign ?? ""
            }
            if canManageSecondaryLeads(app.roles) {
                shiftLeadUsers = (try? await YahpazAPI.shared.fetchShiftLeadProfiles()) ?? []
            }
        }
        .task(id: eventId) {
            await loadDetail()
        }
        .task(id: responders.map(\.responderId).sorted().joined(separator: ",")) {
            await refreshVehicleOwners()
        }
        .onChange(of: responders.count) { _, _ in
            confirmDelete = false
            deleteHint = nil
        }
        .sheet(isPresented: Binding(
            get: { foreignEditPending },
            set: { presented in
                if !presented && !foreignEditAcked {
                    app.closeEventForm()
                }
            }
        )) {
            foreignEditSheet
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "he"))
        }
        .sheet(item: Binding(
            get: { detailResponderId.map { ResponderRoute(id: $0) } },
            set: { detailResponderId = $0?.id }
        )) { route in
            if let responder = responders.first(where: { $0.responderId == route.id }),
               let profile = app.assignableProfiles.first(where: { $0.id == route.id })
            {
                EventResponderDetailSheet(
                    profile: profile,
                    responder: responder,
                    vehicleKinds: app.lookups.vehicleKinds,
                    busLane: busLane,
                    onToggleBusLane: { busLane = $0 },
                    onDismiss: { detailResponderId = nil },
                    onChange: { updated in
                        responders = updateEventResponder(responders, responderId: updated.responderId) { _ in updated }
                    }
                )
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "he"))
            }
        }
    }

    @ViewBuilder
    private var formBody: some View {
        if loadFailed {
            EmptyState(title: EVENT_EDIT_LOAD_FAILED, actionTitle: "חזרה") {
                app.closeEventForm()
            }
        } else if editing && !loaded {
            ProgressView("טוען אירוע…")
                .frame(maxWidth: .infinity, minHeight: 120)
        } else if assignedBlocked {
            EmptyState(title: ASSIGNED_VOLUNTEER_EVENT_EDIT_ERROR, actionTitle: "חזרה") {
                app.closeEventForm()
            }
        } else if foreignEditPending {
            Color.clear.frame(height: 1)
        } else if app.lookupsFailed && app.lookups.isEmpty {
            EmptyState(
                title: "טעינת הרשימות נכשלה. בדקו את החיבור ונסו שוב.",
                actionTitle: "רענון"
            ) {
                Task { await app.reloadLookups() }
            }
        } else if app.lookups.isEmpty {
            ProgressView("טוען רשימות…")
                .frame(maxWidth: .infinity, minHeight: 120)
        } else {
            fields
        }
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: 12) {
            if editing {
                FormCheckbox(
                    label: EVENT_CANCELLED_LABEL,
                    checked: isCancelled,
                    enabled: !isCancelled || app.canManageUnit
                ) { next in
                    formError = canToggleEventCancelled(next: next, canClearCancelled: app.canManageUnit)
                    if formError == nil { isCancelled = next }
                }
            }
            EventShiftLeadsFields(
                roles: app.roles,
                viewerId: app.userId,
                eventExists: editing,
                shiftLeadId: shiftLeadId,
                shiftLeadName: shiftLeadName,
                shiftLeadCallsign: shiftLeadCallsign,
                secondaryLeads: secondaryLeads,
                shiftLeadUsers: shiftLeadUsers
            ) { mainId, mainName, mainCallsign, secondaries in
                shiftLeadId = mainId
                shiftLeadName = mainName
                shiftLeadCallsign = mainCallsign
                secondaryLeads = secondaries
            }
            ReturnDateField(label: "תאריך", error: errors.eventDate, text: $eventDate)
            HStack(alignment: .top, spacing: 12) {
                FormField(label: "מספר אירוע", keyboard: .numberPad, mono: true, text: $policeEventId)
                FormField(label: EVENT_PATROL_CALLSIGN_LABEL, keyboard: .numberPad, mono: true, text: $patrolCallsign)
            }
            HStack(alignment: .top, spacing: 12) {
                LookupPickerField(
                    label: "סוג אירוע",
                    options: app.lookups.eventTypes,
                    selectedId: eventTypeId,
                    placeholder: "בחירת סוג",
                    searchPlaceholder: "חיפוש סוג אירוע",
                    error: errors.eventType
                ) { eventTypeId = $0 }
                LookupPickerField(
                    label: "שלוחה",
                    options: app.lookups.districts,
                    selectedId: districtId,
                    placeholder: "בחירת שלוחה",
                    searchPlaceholder: "חיפוש שלוחה",
                    allowClear: true
                ) { next in
                    roadId = applyDistrictRoadDefault(
                        previousDistrictId: districtId,
                        nextDistrictId: next,
                        districts: app.lookups.districts,
                        roads: app.lookups.roads,
                        currentRoadId: roadId
                    )
                    station = stationAfterDistrictChange(app.lookups.districts, nextDistrictId: next, currentStation: station)
                    districtId = next
                }
            }
            if districtNeedsStation(app.lookups.districts, districtId: districtId) {
                FormField(label: EVENT_STATION_LABEL, text: Binding(
                    get: { station },
                    set: { station = String($0.prefix(STATION_MAX_LENGTH)) }
                ))
            }
            HStack(alignment: .top, spacing: 12) {
                LookupPickerField(
                    label: "כביש",
                    options: app.lookups.roads,
                    selectedId: roadId,
                    placeholder: "בחירת כביש",
                    searchPlaceholder: "חיפוש כביש",
                    error: errors.road
                ) { roadId = $0 }
                FormField(
                    label: "מיקום",
                    error: errors.location,
                    placeholder: "למשל: מחלף שורק",
                    text: $location
                )
            }
            CrewAssignmentSection(
                assignOpenLabel: EVENT_ASSIGN_OPEN,
                assignCloseLabel: EVENT_ASSIGN_CLOSE,
                profiles: app.assignableProfiles,
                selectedIds: responders.map(\.responderId),
                caption: eventDraftSummary(responderCount: responders.count),
                emptyHint: EVENT_ASSIGN_EMPTY,
                emptyRoster: "אין משתמשים פעילים להקצאה.",
                emptyQuery: "לא נמצאו מתנדבים להקצאה",
                disabledIds: editing ? [] : Set([app.userId].compactMap { $0 }),
                disabledHint: EVENT_SELF_ASSIGN_DISABLED_HINT,
                onResponderTap: { detailResponderId = $0 }
            ) { id in
                if !isSelfAssignDisabledOnCreate(isCreate: !editing, currentUserId: app.userId, profileId: id) {
                    responders = toggleEventResponder(responders, responderId: id, hasVehicle: vehicleOwnerIds.contains(id))
                    if responders.contains(where: { $0.responderId == id }) {
                        detailResponderId = id
                    } else if detailResponderId == id {
                        detailResponderId = nil
                    }
                }
            }
            FormArea(label: "הערות", minHeight: 96, text: $notes)
            if let formError {
                Text(formError)
                    .font(TypeScale.caption)
                    .foregroundStyle(FieldTheme.alert)
            }
            PrimaryButton(title: EVENT_SAVE_TITLE, busy: saving, enabled: !deleting) {
                persist(allowPartial: false)
            }
            GhostButton(title: EVENT_SAVE_DRAFT_TITLE, enabled: !saving && !deleting) {
                persist(allowPartial: true)
            }
            if showEventDelete {
                if let deleteHint {
                    Text(deleteHint)
                        .font(TypeScale.caption)
                        .foregroundStyle(FieldTheme.alert)
                }
                GhostButton(
                    title: EVENT_DELETE_TITLE,
                    enabled: !deleting,
                    danger: true,
                    action: onDeletePressed
                )
            }
        }
    }

    private var showEventDelete: Bool {
        editing && loaded && !loadFailed && app.canManageUnit && shouldShowCockpitDelete(
            cockpitDeleteBlock(responderCount: responders.count, shiftLeadId: shiftLeadId, viewer: deleteViewer)
        )
    }

    private var deleteViewer: CockpitDeleteViewer {
        CockpitDeleteViewer(userId: app.userId, isAdmin: app.canAdmin)
    }

    private func currentDraft() -> EventDraft {
        EventDraft(
            eventDate: eventDate,
            policeEventId: policeEventId,
            patrolCallsign: patrolCallsign,
            eventTypeId: eventTypeId,
            roadId: roadId,
            districtId: districtId,
            location: location,
            station: station,
            notes: notes,
            responders: responders,
            isCancelled: isCancelled,
            busLane: busLane,
            shiftLeadId: shiftLeadId,
            secondaryLeads: secondaryLeads
        )
    }

    private func persist(allowPartial: Bool) {
        if deleting || saving { return }
        if assignedBlocked {
            formError = ASSIGNED_VOLUNTEER_EVENT_EDIT_ERROR
            return
        }
        if isForeignShiftLeadEvent(viewerId: app.userId, shiftLeadId: shiftLeadId) && !foreignEditAcked {
            return
        }
        let current = currentDraft()
        if !editing && createIncludesSelfAssign(shiftLeadId: app.userId ?? "", responders: current.responders) {
            formError = EVENT_SELF_ASSIGN_ON_CREATE_ERROR
            return
        }
        let next = allowPartial
            ? validateEventDraftPartial(current)
            : validateEventDraft(current, districts: app.lookups.districts)
        errors = next
        if !next.isEmpty {
            formError = next.eventDate ?? next.formMessage
            return
        }
        formError = nil
        Task {
            saving = true
            if let eventId {
                formError = await app.updateUnitEvent(
                    eventId,
                    draft: current,
                    previousIsCancelled: previousIsCancelled,
                    allowPartial: allowPartial,
                    previousDraft: persistedDraft
                )
            } else {
                formError = await app.createUnitEvent(current, allowPartial: allowPartial)
            }
            saving = false
        }
    }

    private func onDeletePressed() {
        guard eventId != nil else { return }
        if saving || deleting { return }
        switch cockpitDeleteClick(
            armed: false,
            responderCount: responders.count,
            shiftLeadId: shiftLeadId,
            viewer: deleteViewer
        ) {
        case .blocked(let block):
            confirmDelete = false
            deleteHint = cockpitDeleteHint(block)
        case .arm, .delete:
            deleteHint = nil
            confirmDelete = true
        }
    }

    private func performEventDelete() {
        guard let eventId else { return }
        Task {
            deleting = true
            let error = await app.deleteUnitEvent(eventId)
            deleting = false
            if let error {
                formError = error
                confirmDelete = false
            }
        }
    }

    private func loadDetail() async {
        guard let eventId else {
            loaded = true
            loadFailed = false
            return
        }
        loaded = false
        loadFailed = false
        assignedBlocked = false
        do {
            let detail = try await YahpazAPI.shared.fetchEventFormDetail(eventId: eventId)
            let vehicles = try await YahpazAPI.shared.fetchVehiclesForResponders(detail.responders.map(\.responderId))
            let draft = detail.toDraft(vehicleOwnerIds: Set(vehicles.map(\.userId)))
            eventDate = draft.eventDate
            policeEventId = draft.policeEventId
            patrolCallsign = draft.patrolCallsign
            eventTypeId = draft.eventTypeId
            roadId = draft.roadId
            districtId = draft.districtId
            location = draft.location
            station = draft.station
            notes = draft.notes
            responders = draft.responders
            isCancelled = draft.isCancelled
            busLane = draft.busLane
            previousIsCancelled = draft.isCancelled
            shiftLeadId = detail.shiftLeadId ?? ""
            shiftLeadName = detail.shiftLead?.fullName ?? ""
            shiftLeadCallsign = detail.shiftLead?.callsign ?? ""
            secondaryLeads = draft.secondaryLeads
            persistedDraft = draft
            foreignEditAcked = false
            assignedBlocked = draft.blocksAssignedVolunteerEdit(viewerId: app.userId)
            loaded = true
        } catch {
            loadFailed = true
            assignedBlocked = false
            loaded = true
        }
    }

    private func refreshVehicleOwners() async {
        let ids = responders.map(\.responderId)
        if ids.isEmpty {
            vehicleOwnerIds = []
            return
        }
        let owners = Set((try? await YahpazAPI.shared.fetchVehiclesForResponders(ids))?.map(\.userId) ?? [])
        vehicleOwnerIds = owners
        let updated = responders.map { row in
            var copy = row
            copy.hasVehicle = owners.contains(row.responderId)
            return copy
        }
        if updated != responders { responders = updated }
    }

    private var foreignEditSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(foreignEventEditTitle(foreignEventEditLeadName(fullName: shiftLeadName, callsign: shiftLeadCallsign)))
                .font(TypeScale.section)
                .foregroundStyle(FieldTheme.textPrimary)
            Text(FOREIGN_EVENT_EDIT_BODY)
                .font(TypeScale.body)
                .foregroundStyle(FieldTheme.textSecondary)
            PrimaryButton(title: FOREIGN_EVENT_EDIT_CONFIRM) {
                foreignEditAcked = true
            }
            Button(FOREIGN_EVENT_EDIT_CANCEL) { app.closeEventForm() }
                .font(TypeScale.body)
                .foregroundStyle(FieldTheme.accent)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .trailing)
                .buttonStyle(.plain)
        }
        .padding(16)
        .background(FieldTheme.page.ignoresSafeArea())
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled()
    }
}

private struct ResponderRoute: Identifiable, Hashable {
    var id: String
}

private struct EventShiftLeadsFields: View {
    let roles: [String]
    let viewerId: String?
    let eventExists: Bool
    let shiftLeadId: String
    let shiftLeadName: String
    let shiftLeadCallsign: String
    let secondaryLeads: [SecondaryLead]
    let shiftLeadUsers: [AssignableProfile]
    let onChange: (String, String, String, [SecondaryLead]) -> Void

    private var canChangeMain: Bool {
        canChangeEventMainLead(
            roles: roles,
            eventExists: eventExists,
            viewerIsCurrentMain: viewerId != nil && viewerId == shiftLeadId,
            hasSecondaries: !secondaryLeads.isEmpty
        )
    }

    private var canManage: Bool { canManageSecondaryLeads(roles) }

    private var excludeIds: Set<String> {
        Set([shiftLeadId] + secondaryLeads.map(\.userId))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if canChangeMain {
                LookupPickerField(
                    label: eventLeadFieldLabel(hasSecondaries: !secondaryLeads.isEmpty),
                    options: shiftLeadUsers.map { LookupOption(id: $0.id, name: $0.display) },
                    selectedId: shiftLeadId,
                    placeholder: "בחירת אחמ״ש",
                    searchPlaceholder: "חיפוש אחמ״ש"
                ) { nextId in
                    if nextId == shiftLeadId { return }
                    let nextPerson = shiftLeadUsers.first(where: { $0.id == nextId })
                    let reassigned = reassignMainLeads(
                        previousMainId: shiftLeadId,
                        nextMainId: nextId,
                        previousMainName: shiftLeadName,
                        previousMainCallsign: shiftLeadCallsign,
                        secondaries: secondaryLeads
                    )
                    onChange(
                        reassigned.mainId,
                        nextPerson?.fullName ?? "",
                        nextPerson?.callsign ?? "",
                        reassigned.secondaries
                    )
                }
            } else {
                LedgerRow(
                    label: eventLeadFieldLabel(hasSecondaries: !secondaryLeads.isEmpty),
                    value: formatLeadPerson(shiftLeadName, callsign: shiftLeadCallsign)
                )
                if canManage {
                    Text(MAIN_LEAD_LOCKED_HINT)
                        .font(TypeScale.caption)
                        .foregroundStyle(FieldTheme.textMuted)
                }
            }
            ForEach(secondaryLeads) { row in
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(SECONDARY_LEAD_LABEL)
                            .font(TypeScale.caption)
                            .foregroundStyle(FieldTheme.textMuted)
                        Text(row.display.isEmpty ? "—" : row.display)
                            .font(TypeScale.body)
                            .foregroundStyle(FieldTheme.textPrimary)
                        if row.locked {
                            Text(SECONDARY_LEAD_LOCKED_HINT)
                                .font(TypeScale.caption)
                                .foregroundStyle(FieldTheme.textMuted)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if canRemoveSecondaryLead(roles: roles, locked: row.locked) {
                        Button("הסרה") {
                            onChange(
                                shiftLeadId,
                                shiftLeadName,
                                shiftLeadCallsign,
                                secondaryLeads.filter { $0.userId != row.userId }
                            )
                        }
                        .font(TypeScale.caption)
                        .foregroundStyle(FieldTheme.alert)
                        .frame(minHeight: 44)
                        .buttonStyle(.plain)
                        .accessibilityLabel(SECONDARY_LEAD_REMOVE)
                    }
                }
                .frame(minHeight: 44)
            }
            if canManage {
                SecondaryLeadPicker(
                    people: shiftLeadUsers,
                    excludeIds: excludeIds
                ) { person in
                    onChange(
                        shiftLeadId,
                        shiftLeadName,
                        shiftLeadCallsign,
                        secondaryLeads + [
                            SecondaryLead(userId: person.id, locked: false, fullName: person.fullName, callsign: person.callsign)
                        ]
                    )
                }
            }
        }
    }
}

private struct SecondaryLeadPicker: View {
    let people: [AssignableProfile]
    let excludeIds: Set<String>
    let onAdd: (AssignableProfile) -> Void

    @State private var open = false
    @State private var query = ""

    private var visible: [AssignableProfile] {
        filterShiftLeadPicker(people: people, excludeIds: Array(excludeIds), query: query)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GhostButton(title: SECONDARY_LEAD_ADD) {
                query = ""
                open = true
            }
        }
        .sheet(isPresented: $open) {
            VStack(alignment: .leading, spacing: 12) {
                Text(SECONDARY_LEAD_ADD)
                    .font(TypeScale.section)
                    .foregroundStyle(FieldTheme.textPrimary)
                FormField(label: "חיפוש", placeholder: "חיפוש אחמ״ש", text: $query)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if visible.isEmpty {
                            Text(people.isEmpty ? SECONDARY_LEAD_PICKER_EMPTY : SECONDARY_LEAD_PICKER_NONE)
                                .font(TypeScale.body)
                                .foregroundStyle(FieldTheme.textMuted)
                                .padding(.vertical, 16)
                        }
                        ForEach(visible) { person in
                            Button {
                                onAdd(person)
                                open = false
                            } label: {
                                HStack {
                                    Text(person.display)
                                        .font(TypeScale.body)
                                        .foregroundStyle(FieldTheme.textPrimary)
                                    Spacer(minLength: 8)
                                    Text("הוספה")
                                        .font(TypeScale.caption)
                                        .foregroundStyle(FieldTheme.accent)
                                }
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                GhostButton(title: EVENT_ASSIGN_CLOSE) { open = false }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 24)
            .background(FieldTheme.page.ignoresSafeArea())
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .environment(\.layoutDirection, .rightToLeft)
            .environment(\.locale, Locale(identifier: "he"))
        }
    }
}

private struct EventResponderDetailSheet: View {
    let profile: AssignableProfile
    let responder: EventResponderDraft
    let vehicleKinds: [LookupOption]
    var busLane: Bool
    let onToggleBusLane: (Bool) -> Void
    let onDismiss: () -> Void
    let onChange: (EventResponderDraft) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(profile.display)
                        .font(TypeScale.section)
                        .foregroundStyle(FieldTheme.textPrimary)
                HStack(alignment: .top, spacing: 12) {
                    TimeField(label: "שעת התחלה", text: Binding(
                        get: { responder.startTime },
                        set: { value in
                            var next = responder
                            next.startTime = value
                            onChange(next)
                        }
                    ))
                    TimeField(label: "שעת סיום", text: Binding(
                        get: { responder.endTime },
                        set: { value in
                            var next = responder
                            next.endTime = value
                            onChange(next)
                        }
                    ))
                }
                FormField(
                    label: "קילומטרים",
                    keyboard: .decimalPad,
                    mono: true,
                    enabled: responder.hasVehicle,
                    placeholder: responder.hasVehicle ? nil : NO_VEHICLE_KM_PLACEHOLDER,
                    text: Binding(
                        get: { responder.hasVehicle ? responder.totalKm : "" },
                        set: { value in
                            var next = responder
                            next.totalKm = value
                            onChange(next)
                        }
                    )
                )
                FormCheckbox(label: "אמצעים", checked: responder.emergencyMeans) { value in
                    var next = responder
                    next.emergencyMeans = value
                    onChange(next)
                }
                FormCheckbox(label: "נת״צ", checked: busLane, onChange: onToggleBusLane)
                Text("רכבים שטופלו")
                    .font(TypeScale.label)
                    .foregroundStyle(FieldTheme.textSecondary)
                if vehicleKinds.isEmpty {
                    Text("אין סוגי רכב ברשימה הסגורה.")
                        .font(TypeScale.caption)
                        .foregroundStyle(FieldTheme.textMuted)
                } else {
                    ForEach(vehicleKinds) { kind in
                        TreatedVehicleStepper(
                            label: kind.name,
                            value: treatedQuantity(responder, vehicleKindId: kind.id)
                        ) { delta in
                            onChange(
                                bumpTreatedVehicle(
                                    [responder],
                                    responderId: responder.responderId,
                                    vehicleKindId: kind.id,
                                    delta: delta
                                ).first ?? responder
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
            }
            .yahpazFormScroll()
            .yahpazKeyboardAccessory()
            .background(FieldTheme.page.ignoresSafeArea())
            .navigationTitle(profile.display)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("סגירה", action: onDismiss)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private struct TreatedVehicleStepper: View {
    let label: String
    let value: Int
    let onDelta: (Int) -> Void

    var body: some View {
        HStack {
            Text(label)
                .font(TypeScale.body)
                .foregroundStyle(FieldTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 4) {
                Button("−") { if value > 0 { onDelta(-1) } }
                    .font(TypeScale.section)
                    .foregroundStyle(value > 0 ? FieldTheme.accent : FieldTheme.textMuted)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .disabled(value <= 0)
                    .buttonStyle(.plain)
                    .accessibilityLabel("הפחתה")
                Text("\(value)")
                    .font(TypeScale.numeric)
                    .foregroundStyle(FieldTheme.textPrimary)
                    .frame(minWidth: 36)
                    .accessibilityLabel("\(value)")
                Button("+") { onDelta(1) }
                    .font(TypeScale.section)
                    .foregroundStyle(FieldTheme.accent)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)
                    .accessibilityLabel("הוספה")
            }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(FieldTheme.raised)
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(FieldTheme.hairline, lineWidth: 1)
        )
    }
}
