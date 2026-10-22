import SwiftUI
import YahpazDomain

struct EventFormView: View {
    let eventId: String?
    @EnvironmentObject private var app: AppModel

    @State private var eventDate = returnDateToInput(israelToday())
    @State private var policeEventId = ""
    @State private var patrolCallsignPrefix = ""
    @State private var patrolCallsignNumber = ""
    @State private var startTime = nowTimeJerusalem()
    @State private var endTime = ""
    @State private var createdAt = ""
    @State private var createdEventId: String?
    @State private var eventTypeId = ""
    @State private var roadId = ""
    @State private var districtId = ""
    @State private var location = ""
    @State private var locationPlaceId: String?
    @State private var locationLat: Double?
    @State private var locationLng: Double?
    @State private var locationPinSource: String?
    @State private var locationPinnedAt: String?
    @State private var locationPinnedBy: String?
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
    @State private var removeResponderId: String?
    @State private var quietSaving = false
    @State private var quietPending = false
    @State private var pendingSave: Bool?
    @State private var stashRestored = false
    @State private var formSession = UUID().uuidString

    private var editing: Bool { eventId != nil }
    private var persistedEventId: String? { eventId ?? createdEventId }
    private var ageLocked: Bool { editing && isEventEditAgeLocked(createdAt: createdAt, roles: app.roles) }

    /// Nothing may be written while the form is still loading, blocked, or waiting for the foreign-lead ack.
    private var writesBlocked: Bool {
        assignedBlocked || foreignEditPending || (editing && !loaded) || loadFailed || ageLocked
    }

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
                Text(responders.isEmpty ? EVENT_DELETE_CONFIRM : EVENT_DELETE_CONFIRM_WITH_RESPONDERS)
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
        .task {
            restoreStashedDraft()
        }
        .task(id: currentDraft()) {
            await autosave()
        }
        .onDisappear {
            flushOnLeave()
        }
        .confirmationDialog(
            eventResponderRemoveConfirm(removeResponderName),
            isPresented: Binding(
                get: { removeResponderId != nil },
                set: { if !$0 { removeResponderId = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(EVENT_ASSIGN_REMOVE, role: .destructive) {
                if let id = removeResponderId { dropResponder(id) }
                removeResponderId = nil
            }
            Button(EVENT_ASSIGN_REMOVE_CANCEL, role: .cancel) { removeResponderId = nil }
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
        } else if ageLocked {
            lockedState
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
        VStack(alignment: .leading, spacing: 16) {
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

            EventFormSection(title: EVENT_FORM_LEADS_SECTION) {
                EventShiftLeadsFields(
                    roles: app.roles,
                    viewerId: app.userId,
                    eventExists: editing || createdEventId != nil,
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
            }

            EventFormSection(title: EVENT_FORM_DETAILS_SECTION) {
                ReturnDateField(label: "תאריך", error: errors.eventDate, text: $eventDate)

                EventFormTwoColumn {
                    LookupPickerField(
                        label: "סוג אירוע",
                        options: app.lookups.eventTypes,
                        selectedId: eventTypeId,
                        placeholder: "בחירת סוג",
                        searchPlaceholder: "חיפוש סוג אירוע",
                        error: errors.eventType
                    ) { eventTypeId = $0 }
                } trailing: {
                    FormField(
                        label: "מספר אירוע",
                        keyboard: .numberPad,
                        mono: true,
                        error: formError == POLICE_EVENT_ID_DUPLICATE_ERROR ? formError : nil,
                        text: Binding(
                            get: { policeEventId },
                            set: {
                                policeEventId = policeEventIdForInput($0)
                                if formError == POLICE_EVENT_ID_DUPLICATE_ERROR { formError = nil }
                            }
                        )
                    )
                }

                EventFormFieldNote(note: PATROL_CALLSIGN_FIELD_NOTE)
                EventFormTwoColumn {
                    FormField(
                        label: PATROL_CALLSIGN_PREFIX_LABEL,
                        text: Binding(
                            get: { patrolCallsignPrefix },
                            set: { patrolCallsignPrefix = patrolCallsignPrefixForInput($0) }
                        )
                    )
                } trailing: {
                    FormField(
                        label: PATROL_CALLSIGN_NUMBER_LABEL,
                        keyboard: .numberPad,
                        mono: true,
                        text: Binding(
                            get: { patrolCallsignNumber },
                            set: { patrolCallsignNumber = patrolCallsignNumberForInput($0) }
                        )
                    )
                }

                EventFormFieldNote(note: EVENT_TIMES_FIELD_NOTE, tooltip: EVENT_TIMES_FIELD_TOOLTIP)
                EventFormTwoColumn {
                    EventTimeField(label: EVENT_START_TIME_LABEL, text: $startTime)
                } trailing: {
                    EventTimeField(label: EVENT_END_TIME_LABEL, text: $endTime)
                }

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
                if districtNeedsStation(app.lookups.districts, districtId: districtId) {
                    FormField(label: EVENT_STATION_LABEL, text: Binding(
                        get: { station },
                        set: { station = String($0.prefix(STATION_MAX_LENGTH)) }
                    ))
                }

                EventFormFieldNote(note: LOCATION_FIELD_NOTE, tooltip: LOCATION_FIELD_TOOLTIP)
                LocationPlacesField(
                    value: LocationPinFields(
                        location: location,
                        locationPlaceId: locationPlaceId,
                        locationLat: locationLat,
                        locationLng: locationLng,
                        locationPinSource: locationPinSource,
                        locationPinnedAt: locationPinnedAt,
                        locationPinnedBy: locationPinnedBy
                    ),
                    error: errors.location,
                    required: districtNeedsLocation(app.lookups.districts, districtId: districtId),
                    roadName: app.lookups.roads.first(where: { $0.id == roadId })?.name,
                    placeholder: "",
                    onChange: { pin in
                        location = pin.location
                        locationPlaceId = pin.locationPlaceId
                        locationLat = pin.locationLat
                        locationLng = pin.locationLng
                        locationPinSource = pin.locationPinSource
                        locationPinnedAt = pin.locationPinnedAt
                        locationPinnedBy = pin.locationPinnedBy
                        if errors.location != nil {
                            errors.location = nil
                        }
                    },
                    onJunctionCommit: { junction in
                        let nextRoadId = roadIdAfterJunctionSelection(
                            currentRoadId: roadId,
                            junctionRoads: junction.roads,
                            lookups: app.lookups.roads
                        )
                        if !nextRoadId.isEmpty, nextRoadId != roadId {
                            roadId = nextRoadId
                            errors.road = nil
                        }
                    },
                    onAutocompleteUnavailable: {
                        app.showToast(EVENT_LOCATION_PLACES_UNAVAILABLE, tone: .pending)
                    }
                )
                LookupPickerField(
                    label: "כביש",
                    options: app.lookups.roads,
                    selectedId: roadId,
                    placeholder: "בחירת כביש",
                    searchPlaceholder: "חיפוש כביש",
                    error: errors.road
                ) { roadId = $0 }
                FormArea(label: "הערות", minHeight: 96, text: $notes)
            }

            EventFormSection(title: EVENT_FORM_RESPONDERS_SECTION) {
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
                    onResponderTap: { detailResponderId = $0 },
                    rowCaptions: Dictionary(uniqueKeysWithValues: responders.map {
                        ($0.responderId, assignedResponderCaption(totalKm: $0.totalKm, hasVehicle: $0.hasVehicle))
                    }),
                    onRemove: { id in
                        if let row = responders.first(where: { $0.responderId == id }), eventResponderHasFilledFields(row) {
                            removeResponderId = id
                        } else {
                            dropResponder(id)
                        }
                    }
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
            }

            if !eventReleasedToResponders(
                origin: "manual",
                policeEventId: policeEventId,
                patrolCallsignNumber: patrolCallsignNumber,
                hasRoad: !roadId.isEmpty,
                patrolCallsignPrefix: patrolCallsignPrefix
            ) {
                Text(RESPONDERS_HELD_FOR_POLICE_ID_NOTE)
                    .font(TypeScale.caption)
                    .foregroundStyle(FieldTheme.textMuted)
            }
            if let formError, formError != POLICE_EVENT_ID_DUPLICATE_ERROR {
                Text(formError)
                    .font(TypeScale.caption)
                    .foregroundStyle(FieldTheme.alert)
            }
            if formError == nil, let status = saveStatus {
                Text(status)
                    .font(TypeScale.caption)
                    .foregroundStyle(FieldTheme.textMuted)
            }
            PrimaryButton(title: eventFormPrimaryTitle(editing: editing), busy: saving, enabled: !deleting) {
                persist(allowPartial: false)
            }
            GhostButton(title: eventFormDraftTitle(editing: editing), enabled: !saving && !deleting) {
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
            patrolCallsign: formatPatrolCallsign(patrolCallsignPrefix, patrolCallsignNumber),
            patrolCallsignPrefix: patrolCallsignPrefix,
            patrolCallsignNumber: patrolCallsignNumber,
            startTime: startTime,
            endTime: endTime,
            createdAt: createdAt,
            eventTypeId: eventTypeId,
            roadId: roadId,
            districtId: districtId,
            location: location,
            locationPlaceId: locationPlaceId,
            locationLat: locationLat,
            locationLng: locationLng,
            locationPinSource: locationPinSource,
            locationPinnedAt: locationPinnedAt,
            locationPinnedBy: locationPinnedBy,
            station: station,
            notes: notes,
            responders: responders,
            isCancelled: isCancelled,
            busLane: busLane,
            shiftLeadId: shiftLeadId,
            secondaryLeads: secondaryLeads
        )
    }

    private var removeResponderName: String {
        guard let id = removeResponderId else { return "" }
        return app.assignableProfiles.first(where: { $0.id == id })?.fullName ?? ""
    }

    private func dropResponder(_ id: String) {
        responders = toggleEventResponder(responders, responderId: id)
        if detailResponderId == id { detailResponderId = nil }
    }

    /// `שומר…` while a write is queued, then the autosave promise.
    private var saveStatus: String? {
        if persistedEventId != nil {
            let pending = persistedDraft?.forPersistCompare() != currentDraft().forPersistCompare()
            return saving || quietSaving || pending ? "שומר…" : "השינויים נשמרים אוטומטית."
        }
        if currentDraft().hasDetailBeyondOpen() {
            return saving || quietSaving ? "שומר…" : "הטיוטה נשמרת אוטומטית במכשיר."
        }
        return nil
    }

    private func persist(allowPartial: Bool, quiet: Bool = false) {
        if deleting { return }
        if saving || quietSaving {
            if quiet { quietPending = true } else { pendingSave = allowPartial }
            return
        }
        if assignedBlocked {
            if !quiet { formError = ASSIGNED_VOLUNTEER_EVENT_EDIT_ERROR }
            return
        }
        if ageLocked {
            if !quiet { formError = EVENT_EDIT_LOCKED_TOOLTIP }
            return
        }
        if isForeignShiftLeadEvent(viewerId: app.userId, shiftLeadId: shiftLeadId) && !foreignEditAcked {
            return
        }
        let current = currentDraft()
        if !editing && createIncludesSelfAssign(shiftLeadId: app.userId ?? "", responders: current.responders) {
            if !quiet { formError = EVENT_SELF_ASSIGN_ON_CREATE_ERROR }
            return
        }
        if current.responders.contains(where: {
            $0.hasVehicle && !$0.totalKm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && leadKmForSave(hasVehicle: $0.hasVehicle, totalKm: $0.totalKm) == nil
        }) {
            if !quiet { formError = "קילומטרים חייבים להיות מספר." }
            return
        }
        let partial = allowPartial || quiet
        let next = partial
            ? validateEventDraftPartial(current)
            : validateEventDraft(current, districts: app.lookups.districts)
        if !next.isEmpty {
            if !quiet {
                errors = next
                formError = next.eventDate ?? next.formMessage
            }
            return
        }
        if !quiet {
            errors = next
            formError = nil
        }
        Task {
            if quiet { quietSaving = true } else { saving = true }
            if let eventId = persistedEventId {
                let error = await app.updateUnitEvent(
                    eventId,
                    draft: current,
                    previousIsCancelled: previousIsCancelled,
                    allowPartial: partial,
                    previousDraft: persistedDraft,
                    stay: (allowPartial && !editing) || quiet,
                    quiet: quiet
                )
                if !quiet { formError = error }
                if error == nil { persistedDraft = current }
            } else {
                let outcome = await app.createUnitEvent(
                    current,
                    allowPartial: partial,
                    stay: partial,
                    quiet: quiet,
                    formSession: formSession
                )
                if !quiet { formError = outcome.error }
                // A full create closes the form too: record the row so the leave-flush
                // does not stash the event it just created as a new device draft.
                if outcome.error == nil, let id = outcome.eventId {
                    createdEventId = id
                    persistedDraft = current
                    EventDraftStore.clear()
                }
            }
            if quiet { quietSaving = false } else { saving = false }
            if let explicit = pendingSave {
                pendingSave = nil
                quietPending = false
                persist(allowPartial: explicit)
            } else if quietPending {
                quietPending = false
                persist(allowPartial: true, quiet: true)
            }
        }
    }

    /// 800 ms after the last change: stash a new event on the device, then save quietly.
    private func autosave() async {
        try? await Task.sleep(nanoseconds: 800_000_000)
        if Task.isCancelled || writesBlocked || deleting { return }
        let draft = currentDraft()
        if persistedEventId == nil {
            guard draft.hasDetailBeyondOpen() else { return }
            EventDraftStore.stash(draft)
        }
        if let stored = persistedDraft, stored.forPersistCompare() == draft.forPersistCompare() { return }
        persist(allowPartial: true, quiet: true)
    }

    private func restoreStashedDraft() {
        guard !editing, createdEventId == nil, !stashRestored else { return }
        stashRestored = true
        guard let stashed = EventDraftStore.read(), stashed.hasDetailBeyondOpen() else { return }
        if !stashed.eventDate.isEmpty { eventDate = stashed.eventDate }
        policeEventId = stashed.policeEventId
        patrolCallsignPrefix = stashed.patrolCallsignPrefix
        patrolCallsignNumber = stashed.patrolCallsignNumber
        if !stashed.startTime.isEmpty { startTime = stashed.startTime }
        endTime = stashed.endTime
        eventTypeId = stashed.eventTypeId
        roadId = stashed.roadId
        districtId = stashed.districtId
        location = stashed.location
        locationPlaceId = stashed.locationPlaceId
        locationLat = stashed.locationLat
        locationLng = stashed.locationLng
        locationPinSource = stashed.locationPinSource
        locationPinnedAt = stashed.locationPinnedAt
        locationPinnedBy = stashed.locationPinnedBy
        station = stashed.station
        notes = stashed.notes
        responders = stashed.responders
        isCancelled = stashed.isCancelled
        busLane = stashed.busLane
        secondaryLeads = stashed.secondaryLeads
    }

    /// The form is closing: keep a new draft on the device and send the last keystrokes.
    private func flushOnLeave() {
        let draft = currentDraft()
        if !editing && persistedEventId == nil && draft.hasDetailBeyondOpen() {
            EventDraftStore.stash(draft)
        }
        if writesBlocked { return }
        app.flushEventForm(
            formSession: formSession,
            eventId: persistedEventId,
            draft: draft,
            previousDraft: persistedDraft,
            previousIsCancelled: previousIsCancelled,
            replaceExisting: !editing
        )
    }

    /// Past the 7-day lock the form only explains why, and still lets the owner or an admin delete.
    private var lockedState: some View {
        VStack(alignment: .leading, spacing: 12) {
            EmptyState(title: EVENT_EDIT_LOCKED_TOOLTIP, actionTitle: "חזרה") {
                app.closeEventForm()
            }
            if canDeleteUnassignedEvent(
                canManageUnit: app.canManageUnit,
                viewerIsAdmin: app.canAdmin,
                viewerId: app.userId,
                shiftLeadId: shiftLeadId
            ) {
                if let formError {
                    Text(formError)
                        .font(TypeScale.caption)
                        .foregroundStyle(FieldTheme.alert)
                }
                GhostButton(title: EVENT_DELETE_TITLE, enabled: !deleting, danger: true) {
                    confirmDelete = true
                }
            }
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
            let ownerIds = Set(vehicles.map(\.userId))
            let draft = detail.toDraft(vehicleOwnerIds: ownerIds)
            eventDate = draft.eventDate
            policeEventId = draft.policeEventId
            patrolCallsignPrefix = draft.patrolCallsignPrefix
            patrolCallsignNumber = draft.patrolCallsignNumber
            startTime = draft.startTime
            endTime = draft.endTime
            createdAt = draft.createdAt
            eventTypeId = draft.eventTypeId
            roadId = draft.roadId
            districtId = draft.districtId
            location = draft.location
            locationPlaceId = draft.locationPlaceId
            locationLat = draft.locationLat
            locationLng = draft.locationLng
            locationPinSource = draft.locationPinSource
            locationPinnedAt = draft.locationPinnedAt
            locationPinnedBy = draft.locationPinnedBy
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
            persistedDraft = detail.toPersistedDraft(vehicleOwnerIds: ownerIds)
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

private struct EventFormSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(TypeScale.section)
                .foregroundStyle(FieldTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
                .overlay(alignment: .top) {
                    Rectangle().fill(FieldTheme.hairline).frame(height: 1)
                }
                .padding(.top, 8)
            content
        }
    }
}

private struct EventFormTwoColumn<Leading: View, Trailing: View>: View {
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            leading
                .frame(maxWidth: .infinity, alignment: .leading)
            trailing
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct EventFormFieldNote: View {
    let note: String
    var tooltip: String? = nil
    @State private var showTip = false

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            Text(note)
                .font(TypeScale.caption)
                .foregroundStyle(FieldTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if let tooltip, !tooltip.isEmpty {
                Button {
                    showTip = true
                } label: {
                    Text("?")
                        .font(TypeScale.bodyStrong)
                        .foregroundStyle(FieldTheme.accent)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("מידע נוסף")
                .alert("", isPresented: $showTip) {
                    Button("סגירה", role: .cancel) {}
                } message: {
                    Text(tooltip)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct EventTimeField: View {
    let label: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 8) {
                Text(label)
                    .font(TypeScale.label)
                    .foregroundStyle(FieldTheme.textSecondary)
                Spacer(minLength: 8)
                Button(TIME_NOW_LABEL) {
                    text = nowTimeJerusalem()
                }
                .font(TypeScale.caption)
                .foregroundStyle(FieldTheme.accent)
                .frame(minHeight: 32)
                .buttonStyle(.plain)
                .accessibilityLabel(TIME_NOW_LABEL)
            }
            TimeField(label: "", text: $text)
        }
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
