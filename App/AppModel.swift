import Foundation
import SwiftUI
import YahpazDomain

@MainActor
final class AppModel: ObservableObject {
    enum Tab: String, Hashable {
        case mine
        case myShifts = "my_shifts"
        case contacts
        case events
        case shifts
        case reports
        case users
        case profile

        static func fromMobileView(_ view: String) -> Tab {
            Tab(rawValue: view) ?? .mine
        }
    }

    enum ShiftFormRoute: Identifiable, Hashable {
        case create
        case edit(String)

        var id: String {
            switch self {
            case .create: return "create"
            case .edit(let id): return id
            }
        }

        var shiftId: String? {
            switch self {
            case .create: return nil
            case .edit(let id): return id
            }
        }
    }

    enum AdminHubSegment: String, Hashable {
        case users
        case reports
    }

    enum EventFormRoute: Identifiable, Hashable {
        case create
        case edit(String)

        var id: String {
            switch self {
            case .create: return "create"
            case .edit(let id): return id
            }
        }

        var eventId: String? {
            switch self {
            case .create: return nil
            case .edit(let id): return id
            }
        }
    }

    @Published var booting = true
    @Published var forceUpdate: ForceUpdateRequired?
    @Published var optionalUpdate: OptionalUpdateAvailable?
    @Published var userId: String?
    @Published var profile: ProfileRecord?
    @Published var roles: [String] = []
    @Published var actualRoles: [String] = []
    @Published var impersonating = false
    @Published var impersonationName: String?
    @Published var impersonationCallsign: String?
    @Published var previewRole: String?
    @Published var feedbackHiddenUntilRefresh = false
    @Published var fillEventId: String?
    @Published var events: [EventListItem] = []
    @Published var eventsFailed = false
    @Published var eventsLoading = false
    @Published var shifts: [ShiftListItem] = []
    @Published var shiftsFailed = false
    @Published var shiftsLoading = false
    @Published var tab: Tab = .mine
    @Published var toast: String?
    @Published var toastTone: StampTone = .done
    @Published var trackToken: String?
    @Published var mustChangePassword = false
    @Published var vehicles: [ProfileVehicle] = []
    @Published var vehiclesLoading = false
    @Published var vehiclesFailed = false
    @Published var contacts: [UnitContact] = []
    @Published var contactsLoading = false
    @Published var contactsFailed = false
    @Published var unitShifts: [ShiftListItem] = []
    @Published var unitShiftsFailed = false
    @Published var unitShiftsLoading = false
    @Published var assignableProfiles: [AssignableProfile] = []
    @Published var assignableProfilesLoading = false
    @Published var assignableProfilesFailed = false
    @Published var shiftForm: ShiftFormRoute?
    @Published var eventForm: EventFormRoute?
    @Published var unitEvents: [EventListItem] = []
    @Published var myActiveUnitEvents: [EventListItem] = []
    @Published var myActiveEventPrefs: [MyActiveEventPrefRow] = []
    @Published var myActivePinnedEvents: [EventListItem] = []
    @Published var unitEventsFailed = false
    @Published var unitEventsLoading = false
    @Published var showOthersCreatedEvents = false
    @Published var lookups = EventLookups()
    @Published var lookupsLoading = false
    @Published var lookupsFailed = false
    @Published var privacyOpen = false
    @Published var reportKind: ReportKindId = .openDocumentation
    @Published var reportRows: [ReportRow] = []
    @Published var reportFrom: String?
    @Published var reportTo: String?
    @Published var reportLoading = false
    @Published var reportFailed = false
    @Published var adminUsers: [AdminUserListItem] = []
    @Published var adminUsersLoading = false
    @Published var adminUsersFailed = false
    @Published var adminHubSegment: AdminHubSegment = .users

    private var toastTask: Task<Void, Never>?
    private var lastSessionReportAtMs: Int64?

    var isSignedIn: Bool { userId != nil && profile != nil }
    var canManageUnit: Bool { managesUnit(roles) }
    var canAdmin: Bool { isAdmin(roles) }

    func bootstrap() async {
        booting = true
        let check = await checkSideloadUpdates(currentBuild: installedBuildNumber())
        if let force = check.force {
            forceUpdate = force
            optionalUpdate = nil
            booting = false
            await reportSessionIfDue()
            return
        }
        let skipped = OptionalUpdatePrefs.skippedLatestBuild
        optionalUpdate = check.optional.flatMap { update in
            update.latestBuild != skipped ? update : nil
        }
        if let id = await YahpazAPI.shared.sessionUserId() {
            try? await applySession(userId: id)
        } else {
            userId = nil
            profile = nil
        }
        forceUpdate = nil
        booting = false
    }

    func dismissOptionalUpdate() {
        optionalUpdate = nil
    }

    func onForeground() {
        Task { await reportSessionIfDue() }
    }

    func applyIncomingURL(_ url: URL) {
        if let token = parseTrackToken(from: url.absoluteString) {
            trackToken = token
        }
    }

    func signIn(email: String, password: String) async -> String? {
        if let error = await YahpazAPI.shared.signIn(email: email, password: password) {
            return error
        }
        if let id = await YahpazAPI.shared.sessionUserId() {
            do {
                try await applySession(userId: id)
                return nil
            } catch {
                return error.localizedDescription
            }
        }
        return "הכניסה נכשלה. בדקו את החיבור ונסו שוב."
    }

    func signOut() async {
        await PushRegistration.shared.removeCurrentToken()
        await YahpazAPI.shared.signOut()
        userId = nil
        profile = nil
        roles = []
        actualRoles = []
        impersonating = false
        impersonationName = nil
        impersonationCallsign = nil
        previewRole = nil
        feedbackHiddenUntilRefresh = false
        fillEventId = nil
        events = []
        shifts = []
        vehicles = []
        vehiclesFailed = false
        vehiclesLoading = false
        contacts = []
        contactsFailed = false
        contactsLoading = false
        unitShifts = []
        unitShiftsFailed = false
        unitShiftsLoading = false
        assignableProfiles = []
        assignableProfilesFailed = false
        assignableProfilesLoading = false
        shiftForm = nil
        eventForm = nil
        unitEvents = []
        myActiveUnitEvents = []
        myActiveEventPrefs = []
        myActivePinnedEvents = []
        unitEventsFailed = false
        unitEventsLoading = false
        showOthersCreatedEvents = false
        lookups = EventLookups()
        lookupsFailed = false
        lookupsLoading = false
        mustChangePassword = false
        privacyOpen = false
        reportKind = .openDocumentation
        reportRows = []
        reportFrom = nil
        reportTo = nil
        reportLoading = false
        reportFailed = false
        adminUsers = []
        adminUsersLoading = false
        adminUsersFailed = false
        adminHubSegment = .users
        tab = .mine
    }

    func reloadEvents() async {
        guard userId != nil else { return }
        let hadEvents = !events.isEmpty
        if !hadEvents { eventsLoading = true }
        eventsFailed = false
        do {
            events = try await YahpazAPI.shared.fetchMyEvents()
        } catch {
            switch listReloadFailure(hadItems: hadEvents, cancelled: isLoadCancellation(error)) {
            case .ignore:
                break
            case .toast:
                showToast("טעינת האירועים נכשלה. בדקו את החיבור ונסו שוב.", tone: .pending)
            case .failed:
                eventsFailed = true
            }
        }
        eventsLoading = false
    }

    func reloadShifts() async {
        guard userId != nil else { return }
        let hadShifts = !shifts.isEmpty
        if !hadShifts { shiftsLoading = true }
        shiftsFailed = false
        do {
            shifts = try await YahpazAPI.shared.fetchMyShifts()
        } catch {
            switch listReloadFailure(hadItems: hadShifts, cancelled: isLoadCancellation(error)) {
            case .ignore:
                break
            case .toast:
                showToast("טעינת המשמרות נכשלה. בדקו את החיבור ונסו שוב.", tone: .pending)
            case .failed:
                shiftsFailed = true
            }
        }
        shiftsLoading = false
    }

    func reloadVehicles() async {
        guard userId != nil else { return }
        let hadVehicles = !vehicles.isEmpty
        if !hadVehicles { vehiclesLoading = true }
        vehiclesFailed = false
        do {
            vehicles = try await YahpazAPI.shared.fetchMyVehicles()
        } catch {
            switch listReloadFailure(hadItems: hadVehicles, cancelled: isLoadCancellation(error)) {
            case .ignore:
                break
            case .toast:
                showToast("טעינת הרכבים נכשלה. בדקו את החיבור ונסו שוב.", tone: .pending)
            case .failed:
                vehiclesFailed = true
            }
        }
        vehiclesLoading = false
    }

    func reloadContacts() async {
        guard userId != nil else { return }
        let hadContacts = !contacts.isEmpty
        if !hadContacts { contactsLoading = true }
        contactsFailed = false
        do {
            contacts = try await YahpazAPI.shared.fetchUnitContacts()
        } catch {
            switch listReloadFailure(hadItems: hadContacts, cancelled: isLoadCancellation(error)) {
            case .ignore:
                break
            case .toast:
                showToast(CONTACTS_FAILED_TITLE, tone: .pending)
            case .failed:
                contactsFailed = true
            }
        }
        contactsLoading = false
    }

    func reloadUnitShifts() async {
        guard userId != nil else { return }
        let hadRows = !unitShifts.isEmpty
        if !hadRows { unitShiftsLoading = true }
        unitShiftsFailed = false
        do {
            unitShifts = try await YahpazAPI.shared.fetchUnitShifts()
        } catch {
            switch listReloadFailure(hadItems: hadRows, cancelled: isLoadCancellation(error)) {
            case .ignore:
                break
            case .toast:
                showToast(UNIT_SHIFTS_LOAD_FAILED, tone: .pending)
            case .failed:
                unitShiftsFailed = true
            }
        }
        unitShiftsLoading = false
    }

    func reloadAssignableProfiles() async {
        guard userId != nil else { return }
        let hadRows = !assignableProfiles.isEmpty
        if !hadRows { assignableProfilesLoading = true }
        assignableProfilesFailed = false
        do {
            assignableProfiles = try await YahpazAPI.shared.fetchAssignableProfiles()
        } catch {
            if !hadRows { assignableProfilesFailed = true }
        }
        assignableProfilesLoading = false
    }

    func openCreateShift() {
        shiftForm = .create
    }

    func openEditShift(_ shiftId: String) {
        shiftForm = .edit(shiftId)
    }

    func closeShiftForm() {
        shiftForm = nil
    }

    func openCreateEvent() {
        eventForm = .create
    }

    func openEditEvent(_ eventId: String) {
        eventForm = .edit(eventId)
    }

    func closeEventForm() {
        eventForm = nil
    }

    func setShowOthersCreatedEvents(_ show: Bool) {
        if showOthersCreatedEvents == show { return }
        showOthersCreatedEvents = show
        unitEvents = []
        Task { await reloadUnitEvents() }
    }

    func reloadUnitEvents() async {
        guard userId != nil else { return }
        let snapshotRoles = roles
        let snapshotUserId = userId
        let showOthers = showOthersCreatedEvents
        let hadRows = !unitEvents.isEmpty || !myActiveUnitEvents.isEmpty
        if !hadRows { unitEventsLoading = true }
        unitEventsFailed = false
        do {
            let ownOnlyId = unitEventsCreatedByFilter(
                roles: snapshotRoles,
                showOthersCreated: showOthers,
                userId: snapshotUserId
            )
            let events = try await YahpazAPI.shared.fetchUnitEvents(shiftLeadId: ownOnlyId)
            let active = try await YahpazAPI.shared.fetchMyActiveUnitEvents()
            let prefs = try await YahpazAPI.shared.fetchMyActiveEventPrefs()
            let knownIds = Set(events.map(\.id) + active.map(\.id))
            let pinnedIds = Set(prefs.filter { $0.kind == "pin" }.map(\.eventId))
            let extra = try await YahpazAPI.shared.fetchUnitEventsByIds(Array(pinnedIds.subtracting(knownIds)))
            unitEvents = events
            myActiveUnitEvents = active
            myActiveEventPrefs = prefs
            myActivePinnedEvents = extra
            unitEventsFailed = false
        } catch {
            switch listReloadFailure(hadItems: hadRows, cancelled: isLoadCancellation(error)) {
            case .ignore:
                break
            case .toast:
                showToast(UNIT_EVENTS_LOAD_FAILED, tone: .pending)
            case .failed:
                unitEventsFailed = true
            }
        }
        unitEventsLoading = false
    }

    func reloadLookups() async {
        guard userId != nil else { return }
        lookupsLoading = true
        lookupsFailed = false
        do {
            async let lookupsReq = YahpazAPI.shared.fetchEventLookups()
            async let profilesReq = YahpazAPI.shared.fetchAssignableProfiles()
            lookups = try await lookupsReq
            assignableProfiles = try await profilesReq
            lookupsFailed = false
            assignableProfilesFailed = false
        } catch {
            lookupsFailed = true
        }
        lookupsLoading = false
    }

    func createUnitEvent(_ draft: EventDraft, allowPartial: Bool = false, stay: Bool = false) async -> EventSaveOutcome {
        let outcome = await YahpazAPI.shared.createUnitEvent(
            draft,
            districts: lookups.districts,
            vehicleKinds: lookups.vehicleKinds,
            allowPartial: allowPartial
        )
        if outcome.error != nil { return outcome }
        await reloadUnitEvents()
        Task { await reloadEvents() }
        showToast(allowPartial ? EVENT_DRAFT_PARTIAL_SAVED : EVENT_DRAFT_SAVED, tone: .done)
        if !stay {
            tab = .events
            closeEventForm()
        }
        return outcome
    }

    func updateUnitEvent(
        _ eventId: String,
        draft: EventDraft,
        previousIsCancelled: Bool,
        allowPartial: Bool = false,
        previousDraft: EventDraft? = nil,
        stay: Bool = false
    ) async -> String? {
        if let error = await YahpazAPI.shared.updateUnitEvent(
            eventId: eventId,
            draft: draft,
            districts: lookups.districts,
            vehicleKinds: lookups.vehicleKinds,
            viewerIsAdmin: canManageUnit,
            previousIsCancelled: previousIsCancelled,
            allowPartial: allowPartial,
            previousDraft: previousDraft
        ) {
            return error
        }
        await reloadUnitEvents()
        Task { await reloadEvents() }
        showToast(allowPartial ? EVENT_DRAFT_PARTIAL_SAVED : EVENT_DRAFT_SAVED, tone: .done)
        if !stay {
            tab = .events
            closeEventForm()
        }
        return nil
    }

    func deleteUnitEvent(_ eventId: String) async -> String? {
        if let error = await YahpazAPI.shared.deleteUnitEvent(eventId: eventId) { return error }
        await reloadUnitEvents()
        Task { await reloadEvents() }
        showToast(EVENT_DELETED, tone: .done)
        closeEventForm()
        return nil
    }

    func addEventToMyActiveBoard(_ eventId: String) async {
        let autoIds = Set(myActiveUnitEvents.map(\.id))
        let alreadyAuto = autoIds.contains(eventId)
        let previousForEvent = myActiveEventPrefs.filter { $0.eventId == eventId }
        let previousPinned = myActivePinnedEvents
        let viewer = userId ?? ""
        let event = (unitEvents + myActiveUnitEvents + myActivePinnedEvents).first(where: { $0.id == eventId })
        let nextPrefs = prefsAfterAddToMyActive(
            prefs: myActiveEventPrefs.map { ActivePref(eventId: $0.eventId, kind: $0.kind) },
            eventId: eventId,
            alreadyAuto: alreadyAuto
        ).toPrefRows(existing: myActiveEventPrefs, userId: viewer)
        myActiveEventPrefs = nextPrefs
        if let event, !alreadyAuto, !myActivePinnedEvents.contains(where: { $0.id == eventId }) {
            myActivePinnedEvents.append(event)
        }
        if let error = await YahpazAPI.shared.addEventToMyActive(eventId: eventId, alreadyAuto: alreadyAuto) {
            myActiveEventPrefs = prefsRestoringEvent(
                prefs: myActiveEventPrefs.map { ActivePref(eventId: $0.eventId, kind: $0.kind) },
                eventId: eventId,
                previous: previousForEvent.map { ActivePref(eventId: $0.eventId, kind: $0.kind) }
            ).toPrefRows(existing: previousForEvent + myActiveEventPrefs, userId: viewer)
            myActivePinnedEvents = previousPinned
            showToast(error, tone: .pending)
        }
    }

    func removeEventFromMyActiveBoard(_ eventId: String) async {
        let viewerId = userId
        let event = (unitEvents + myActiveUnitEvents + myActivePinnedEvents).first(where: { $0.id == eventId })
        if let event, let viewerId,
           !canRemoveFromMyActive(
                viewerId: viewerId,
                shiftLeadId: event.shiftLeadId,
                status: event.status,
                isCancelled: event.isCancelled
           )
        {
            showToast(MY_ACTIVE_REMOVE_LOCKED, tone: .pending)
            return
        }
        let autoIds = Set(myActiveUnitEvents.map(\.id))
        if let error = await YahpazAPI.shared.removeEventFromMyActive(eventId: eventId, isAuto: autoIds.contains(eventId)) {
            showToast(error, tone: .pending)
            return
        }
        await reloadUnitEvents()
        showToast(MY_ACTIVE_EVENT_DISMISSED, tone: .done)
    }

    func createUnitShift(_ draft: ShiftDraft) async -> String? {
        if let error = await YahpazAPI.shared.createUnitShift(draft) { return error }
        await reloadUnitShifts()
        Task { await reloadShifts() }
        showToast(SHIFT_DRAFT_SAVED, tone: .done)
        tab = .shifts
        closeShiftForm()
        return nil
    }

    func updateUnitShift(_ shiftId: String, draft: ShiftDraft) async -> String? {
        if let error = await YahpazAPI.shared.updateUnitShift(shiftId: shiftId, draft: draft) { return error }
        await reloadUnitShifts()
        Task { await reloadShifts() }
        showToast(SHIFT_DRAFT_SAVED, tone: .done)
        tab = .shifts
        closeShiftForm()
        return nil
    }

    /// Reports share one slot of state, so opening a different kind clears the previous rows.
    func openReport(_ kind: ReportKindId) {
        let switching = reportKind != kind
        reportKind = kind
        if switching {
            reportRows = []
            reportFrom = nil
            reportTo = nil
        }
        reportFailed = false
    }

    func reloadReport(from: String, to: String) async {
        guard userId != nil else { return }
        let kind = reportKind
        reportFrom = from
        reportTo = to
        let hadRows = !reportRows.isEmpty
        if !hadRows { reportLoading = true }
        reportFailed = false
        do {
            reportRows = try await YahpazAPI.shared.fetchReport(kind, from: from, to: to)
            reportFailed = false
        } catch {
            switch listReloadFailure(hadItems: hadRows, cancelled: isLoadCancellation(error)) {
            case .ignore:
                break
            case .toast:
                showToast(REPORT_FAILED_TITLE, tone: .pending)
            case .failed:
                reportFailed = true
            }
        }
        reportLoading = false
    }

    /// The only report write today: replace the lead's km with the responder's odometer.
    /// `ReportRow.actionId` carries the assignment id the loader put there.
    func applyReportRowAction(_ actionId: String) async -> String? {
        if let error = await YahpazAPI.shared.applyLeadKmFromOdometer(actionId) {
            return error
        }
        if let from = reportFrom, let to = reportTo {
            await reloadReport(from: from, to: to)
        }
        showToast(KM_DISCREPANCY_APPLIED, tone: .done)
        return nil
    }

    func reloadAdminUsers() async {
        guard userId != nil else { return }
        let hadRows = !adminUsers.isEmpty
        if !hadRows { adminUsersLoading = true }
        adminUsersFailed = false
        do {
            adminUsers = try await YahpazAPI.shared.fetchAdminUsers()
            adminUsersFailed = false
        } catch {
            switch listReloadFailure(hadItems: hadRows, cancelled: isLoadCancellation(error)) {
            case .ignore:
                break
            case .toast:
                showToast("טעינת המשתמשים נכשלה. בדקו את החיבור ונסו שוב.", tone: .pending)
            case .failed:
                adminUsersFailed = true
            }
        }
        adminUsersLoading = false
    }

    func inviteUser(_ draft: InviteDraft) async -> AdminUsersActionResult {
        let result = await YahpazAPI.shared.inviteAdminUser(draft)
        if result.ok { await reloadAdminUsers() }
        return result
    }

    func saveAdminUser(_ draft: InviteDraft) async -> String? {
        if let error = await YahpazAPI.shared.saveAdminUser(draft) { return error }
        await reloadAdminUsers()
        showToast(USER_SAVED, tone: .done)
        return nil
    }

    func deleteAdminUser(_ userId: String) async -> String? {
        if let error = await YahpazAPI.shared.deleteAdminUser(userId: userId) { return error }
        await reloadAdminUsers()
        showToast(USER_DELETED, tone: .done)
        return nil
    }

    func resendAdminInvite(_ userId: String) async -> AdminUsersActionResult {
        await YahpazAPI.shared.resendAdminInvite(userId: userId)
    }

    func copyAdminInviteLink(_ userId: String) async -> AdminUsersActionResult {
        await YahpazAPI.shared.copyAdminInviteLink(userId: userId)
    }

    func setAdminUserOtp(userId: String, kind: String, enabled: Bool) async -> String? {
        if let error = await YahpazAPI.shared.setAdminUserOtp(userId: userId, kind: kind, enabled: enabled) {
            return error
        }
        await reloadAdminUsers()
        showToast(otpFlagToast(kind: kind, enabled: enabled), tone: .done)
        return nil
    }

    func deleteAdminVehicle(vehicleId: String) async -> String? {
        await YahpazAPI.shared.deleteAdminVehicle(vehicleId: vehicleId)
    }

    func archiveAdminVehicle(vehicleId: String) async -> String? {
        await YahpazAPI.shared.archiveAdminVehicle(vehicleId: vehicleId)
    }

    func unarchiveAdminVehicle(vehicleId: String) async -> String? {
        await YahpazAPI.shared.unarchiveAdminVehicle(vehicleId: vehicleId)
    }

    func setUserActive(userId: String, active: Bool) async -> String? {
        if let error = await YahpazAPI.shared.setAdminUserActive(userId: userId, active: active) {
            return error
        }
        await reloadAdminUsers()
        showToast(setActiveToast(next: active), tone: .done)
        return nil
    }

    func defaultReportRange(for kind: ReportKindId) -> (String, String) {
        YahpazDomain.defaultReportRange(spec: reportSpec(kind), today: israelToday())
    }

    /// A row is tappable only when the viewer is the responder who still owns the documentation.
    func ownsEventParticipation(_ eventId: String) -> Bool {
        guard let viewer = userId else { return false }
        let event = (unitEvents + events).first { $0.id == eventId }
        return event?.ownParticipation(userId: viewer) != nil
    }

    func showToast(_ text: String, tone: StampTone = .done) {
        toast = text
        toastTone = tone
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            if !Task.isCancelled { toast = nil }
        }
    }

    func saveAvailability(status: AvailabilityStatus, availableFrom: String?) async -> String? {
        guard let userId else { return "יש להתחבר מחדש." }
        if let error = await YahpazAPI.shared.saveAvailability(
            userId: userId,
            status: status,
            availableFrom: availableFrom
        ) {
            return error
        }
        if var current = profile {
            current.availability = status
            current.availableFrom = status == .available ? nil : availableFrom.flatMap { normalizeReturnDate($0) } ?? availableFrom
            profile = current
        }
        showToast("הזמינות עודכנה.", tone: .done)
        return nil
    }

    func createOwnVehicle(plateNumber: String, model: String) async -> String? {
        await YahpazAPI.shared.createOwnVehicle(plateNumber: plateNumber, model: model)
    }

    func updateOwnVehicle(vehicleId: String, plateNumber: String, model: String) async -> String? {
        await YahpazAPI.shared.updateOwnVehicle(vehicleId: vehicleId, plateNumber: plateNumber, model: model)
    }

    func setDefaultVehicle(vehicleId: String) async -> String? {
        await YahpazAPI.shared.setDefaultVehicle(vehicleId: vehicleId)
    }

    func deleteOwnVehicle(vehicleId: String) async -> String? {
        await YahpazAPI.shared.deleteOwnVehicle(vehicleId: vehicleId)
    }

    func archiveOwnVehicle(vehicleId: String) async -> String? {
        await YahpazAPI.shared.archiveOwnVehicle(vehicleId: vehicleId)
    }

    func unarchiveOwnVehicle(vehicleId: String) async -> String? {
        await YahpazAPI.shared.unarchiveOwnVehicle(vehicleId: vehicleId)
    }

    func isVehicleAttachedToEvents(userId: String, vehicleId: String, plateNumber: String) async -> Bool {
        await YahpazAPI.shared.isVehicleAttachedToEvents(
            userId: userId,
            vehicleId: vehicleId,
            plateNumber: plateNumber
        )
    }

    func openPrivacy() {
        privacyOpen = true
    }

    func hideFeedbackUntilRefresh() {
        feedbackHiddenUntilRefresh = true
    }

    func submitUserFeedback(
        kind: String,
        body: String,
        pagePath: String?,
        audioBytes: Data?,
        audioMime: String?,
        attachments: [FeedbackAttachmentUpload]
    ) async -> String? {
        let error = await YahpazAPI.shared.submitUserFeedback(
            kind: kind,
            body: body,
            pagePath: pagePath,
            audioBytes: audioBytes,
            audioMime: audioMime,
            attachments: attachments
        )
        if error == nil {
            showToast(FEEDBACK_SENT, tone: .done)
        }
        return error
    }

    func startRolePreview(_ role: AppRole) async {
        ViewAsStore.clearImpersonation()
        ViewAsStore.writeRolePreview(role.rawValue)
        guard let id = await YahpazAPI.shared.sessionUserId() else { return }
        try? await applySession(userId: id)
        showToast(ROLE_PREVIEW_STARTED, tone: .done)
    }

    func stopRolePreview() async {
        ViewAsStore.clearRolePreview()
        guard let id = await YahpazAPI.shared.sessionUserId() else { return }
        try? await applySession(userId: id)
        showToast(ROLE_PREVIEW_STOPPED, tone: .done)
    }

    func startImpersonation(targetUserId: String) async -> String? {
        if let error = await YahpazAPI.shared.startImpersonation(targetUserId: targetUserId) {
            return error
        }
        guard let id = await YahpazAPI.shared.sessionUserId() else {
            return "פתיחת הצפייה נכשלה. נסו שוב."
        }
        do {
            try await applySession(userId: id)
            showToast(IMPERSONATION_STARTED, tone: .done)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func stopImpersonation() async {
        let error = await YahpazAPI.shared.stopImpersonation()
        if let error {
            showToast(error, tone: .pending)
            if error.contains("התחברו") {
                userId = nil
                profile = nil
            }
            return
        }
        guard let id = await YahpazAPI.shared.sessionUserId() else {
            userId = nil
            profile = nil
            showToast(IMPERSONATION_STOPPED, tone: .done)
            return
        }
        try? await applySession(userId: id)
        showToast(IMPERSONATION_STOPPED, tone: .done)
    }

    func closePrivacy() {
        privacyOpen = false
    }

    func completePasswordChange(_ password: String) async -> String? {
        if let error = await YahpazAPI.shared.updatePassword(password) {
            return error
        }
        mustChangePassword = false
        if var current = profile {
            current.mustChangePassword = false
            profile = current
        }
        PushRegistration.shared.requestAfterSignIn()
        showToast("הסיסמה עודכנה.", tone: .done)
        return nil
    }

    private func applySession(userId: String) async throws {
        do {
            let (profile, roles) = try await YahpazAPI.shared.loadProfile()
            let preview = parseRolePreviewRole(ViewAsStore.rolePreviewRaw())
            let visible = effectiveRoles(roles, previewRole: preview)
            let impersonation = ViewAsStore.readImpersonation()
            self.userId = userId
            self.profile = profile
            self.actualRoles = roles
            self.roles = visible
            self.impersonating = impersonation != nil
            self.impersonationName = impersonation?.targetFullName
            self.impersonationCallsign = impersonation?.targetCallsign
            self.previewRole = preview?.rawValue
            self.tab = Tab.fromMobileView(defaultMobileView(visible))
            self.mustChangePassword = profile.mustChangePassword
            self.fillEventId = nil
            if !profile.mustChangePassword {
                PushRegistration.shared.requestAfterSignIn()
            }
            await reloadEvents()
            await reloadShifts()
            await reloadVehicles()
            Task { await reloadContacts() }
            if managesUnit(visible) {
                Task { await reloadUnitShifts() }
                Task { await reloadUnitEvents() }
            }
            if isAdmin(visible) {
                Task { await reloadAdminUsers() }
            }
            await reportSessionIfDue()
        } catch {
            self.userId = nil
            self.profile = nil
            self.roles = []
            self.actualRoles = []
            self.impersonating = false
            self.impersonationName = nil
            self.impersonationCallsign = nil
            self.previewRole = nil
            self.fillEventId = nil
            self.vehicles = []
            self.vehiclesFailed = false
            self.vehiclesLoading = false
            self.contacts = []
            self.contactsFailed = false
            self.contactsLoading = false
            self.unitShifts = []
            self.unitShiftsFailed = false
            self.unitShiftsLoading = false
            self.assignableProfiles = []
            self.assignableProfilesFailed = false
            self.assignableProfilesLoading = false
            self.shiftForm = nil
            self.eventForm = nil
            self.unitEvents = []
            self.myActiveUnitEvents = []
            self.myActiveEventPrefs = []
            self.myActivePinnedEvents = []
            self.unitEventsFailed = false
            self.unitEventsLoading = false
            self.lookups = EventLookups()
            self.lookupsFailed = false
            self.lookupsLoading = false
            self.reportKind = .openDocumentation
            self.reportRows = []
            self.reportFrom = nil
            self.reportTo = nil
            self.reportLoading = false
            self.reportFailed = false
            self.adminUsers = []
            self.adminUsersLoading = false
            self.adminUsersFailed = false
            self.adminHubSegment = .users
            throw error
        }
    }

    private func reportSessionIfDue() async {
        guard await YahpazAPI.shared.sessionUserId() != nil else { return }
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        guard shouldReportSession(lastSuccessAtMs: lastSessionReportAtMs, nowMs: now) else { return }
        let params = sessionRpcParams(
            versionCode: installedBuildNumber(),
            versionName: installedVersionName()
        )
        do {
            try await YahpazAPI.shared.reportSession(
                versionCode: params.versionCode,
                versionName: params.versionName
            )
            lastSessionReportAtMs = now
        } catch {
            // Same as Android `runCatching`: a failed heartbeat must not block the session.
        }
    }
}

private extension [ActivePref] {
    func toPrefRows(existing: [MyActiveEventPrefRow], userId: String) -> [MyActiveEventPrefRow] {
        map { pref in
            existing.first(where: { $0.eventId == pref.eventId && $0.kind == pref.kind })
                ?? MyActiveEventPrefRow(userId: userId, eventId: pref.eventId, kind: pref.kind)
        }
    }
}
