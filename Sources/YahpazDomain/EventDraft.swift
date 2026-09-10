import Foundation

public let EVENT_DRAFT_DATE_ERROR = "יש לבחור תאריך."
public let EVENT_DRAFT_TYPE_ERROR = "יש לבחור סוג אירוע."
public let EVENT_DRAFT_ROAD_ERROR = "יש לבחור כביש."
public let EVENT_DRAFT_LOCATION_ERROR = "יש לבחור או להזין מיקום."
public let EVENT_DRAFT_FORM_ERROR = "יש למלא תאריך, סוג אירוע וכביש כדי ליצור אירוע."
public let EVENT_DRAFT_FORM_LOCATION_ERROR = "יש למלא תאריך, סוג אירוע, כביש ומיקום כדי ליצור אירוע."
public let EVENT_DRAFT_SAVE_FAILED = "שמירת האירוע נכשלה. בדקו את החיבור ונסו שוב."
public let EVENT_DRAFT_SAVED = "האירוע נשמר."
public let EVENT_NEW_TITLE = "אירוע חדש"
public let EVENT_EDIT_TITLE = "עריכת אירוע"
public let EVENT_SAVE_TITLE = "שמירת אירוע"
public let EVENT_SAVE_DRAFT_TITLE = "שמירת טיוטה"
public let EVENT_CREATE_TITLE = "יצירת אירוע"
public let EVENT_CREATE_DRAFT_TITLE = "שמירה כטיוטה"
public let EVENT_FORM_DETAILS_SECTION = "פרטי האירוע"
public let EVENT_FORM_RESPONDERS_SECTION = "מתנדבים"
public let EVENT_TIMES_FIELD_NOTE =
    "שימו לב! מעתה הזנת זמנים תהיה עבור האירוע כולו ולא לכל מתנדב בנפרד"
public let EVENT_TIMES_FIELD_TOOLTIP =
    "זמן ההתחלה יהיה זמן היציאה של המתנדב הראשון וזמן הסיום יהיה זמן העזיבה של המתנדב האחרון"
public let PATROL_CALLSIGN_FIELD_NOTE =
    "אתם מתבקשים להזין או\"ק מלא של הניידת כולל קידומת (אביב, חוף וכו')"
public let LOCATION_FIELD_NOTE = "חדש! הזנת כביש באופן אוטומטי מבוסס על המיקום הנבחר"
public let LOCATION_FIELD_TOOLTIP =
    "מיקמנו את שדה 'מיקום' ראשון כדי להקל עליכם והטמענו הזנה אוטומטית של מספר הכביש. במקרה של כביש וק\"מ או מיקום שאינו נמצא, תוכלו עדין להזין מספר כביש באופן ידני"
public let EVENT_DRAFT_PARTIAL_SAVED = "הטיוטה נשמרה."
public let EVENT_PATROL_CALLSIGN_LABEL = "או״ק ניידת"
public let EVENT_LOCATION_PLACEHOLDER = "למשל: מחלף שורק"
public let EVENT_LOCATION_SEARCHING = "מחפשים צמתים ומקומות…"
public let EVENT_LOCATION_JUNCTIONS_UNAVAILABLE = "חיפוש הצמתים אינו זמין כרגע."
public let EVENT_LOCATION_GROUP_JUNCTIONS = "צמתים ומחלפים"
public let EVENT_LOCATION_GROUP_GOOGLE = "תוצאות ממפות Google"
public let EVENT_LOCATION_PLACES_UNAVAILABLE = "השלמת מיקום מגוגל אינה זמינה כרגע. אפשר להזין מיקום ידנית."
public let EVENT_STATION_LABEL = "תחנה"
public let STATION_MAX_LENGTH = 80
public let MY_ACTIVE_EVENTS_TITLE = "האירועים הפעילים שלי"
public let MY_ACTIVE_EVENT_DISMISSED = "הוסר מהאירועים הפעילים."
public let NO_VEHICLE_KM_PLACEHOLDER = "מתנדב ללא רכב"
public let EVENT_ASSIGN_OPEN = "מתנדבים"
public let EVENT_ASSIGN_CLOSE = "סגירת הקצאה"
public let EVENT_ASSIGN_EMPTY = "בלי מתנדב משובץ האירוע נשאר בהזנה ואינו מוצג למתנדבים."
public let EVENT_SELF_ASSIGN_ON_CREATE_ERROR = "לא ניתן לשבץ את יוצר האירוע כמתנדב."
public let EVENT_SELF_ASSIGN_DISABLED_HINT = "לא ניתן לשבץ"
public let EVENT_EDIT_LOAD_FAILED = "טעינת האירוע נכשלה. בדקו את החיבור ונסו שוב."
public let UNIT_EVENTS_LOAD_FAILED = "טעינת האירועים נכשלה. בדקו את החיבור ונסו שוב."
public let UNIT_EVENTS_CAPTION = "מציג 80 אירועים אחרונים - ניתן לחפש גם אירועים ישנים יותר"

/// Single system שלוחה that makes מיקום mandatory. Matches the web `systemDistricts`.
public let SYSTEM_DISTRICT_CODE = "station_other_duplicated"

public func sortLookupsBySortOrder(_ items: [LookupOption]) -> [LookupOption] {
    items.sorted {
        if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
        return $0.name < $1.name
    }
}

public struct TreatedVehicleDraft: Equatable, Sendable {
    public var vehicleKindId: String
    public var quantity: Int

    public init(vehicleKindId: String, quantity: Int) {
        self.vehicleKindId = vehicleKindId
        self.quantity = quantity
    }
}

public struct EventResponderDraft: Equatable, Sendable {
    public var responderId: String
    public var assignmentId: String
    public var startTime: String
    public var endTime: String
    public var totalKm: String
    public var emergencyMeans: Bool
    public var treated: [TreatedVehicleDraft]
    public var status: ParticipationStatus
    public var hasVehicle: Bool

    public init(
        responderId: String,
        assignmentId: String = "",
        startTime: String = "",
        endTime: String = "",
        totalKm: String = "",
        emergencyMeans: Bool = false,
        treated: [TreatedVehicleDraft] = [],
        status: ParticipationStatus = .pending,
        hasVehicle: Bool = true
    ) {
        self.responderId = responderId
        self.assignmentId = assignmentId
        self.startTime = startTime
        self.endTime = endTime
        self.totalKm = totalKm
        self.emergencyMeans = emergencyMeans
        self.treated = treated
        self.status = status
        self.hasVehicle = hasVehicle
    }
}

public let NEW_RESPONDER_EMERGENCY_MEANS = true

public struct EventDraft: Equatable, Sendable {
    public var eventDate: String
    public var policeEventId: String
    public var patrolCallsign: String
    public var eventTypeId: String
    public var roadId: String
    public var districtId: String
    public var location: String
    public var locationPlaceId: String?
    public var locationLat: Double?
    public var locationLng: Double?
    public var locationPinSource: String?
    public var locationPinnedAt: String?
    public var locationPinnedBy: String?
    public var station: String
    public var notes: String
    public var responders: [EventResponderDraft]
    public var isCancelled: Bool
    public var busLane: Bool
    public var shiftLeadId: String
    public var secondaryLeads: [SecondaryLead]
    public var startTime: String
    public var endTime: String

    public init(
        eventDate: String,
        policeEventId: String = "",
        patrolCallsign: String = "",
        eventTypeId: String = "",
        roadId: String = "",
        districtId: String = "",
        location: String = "",
        locationPlaceId: String? = nil,
        locationLat: Double? = nil,
        locationLng: Double? = nil,
        locationPinSource: String? = nil,
        locationPinnedAt: String? = nil,
        locationPinnedBy: String? = nil,
        station: String = "",
        notes: String = "",
        responders: [EventResponderDraft] = [],
        isCancelled: Bool = false,
        busLane: Bool = false,
        shiftLeadId: String = "",
        secondaryLeads: [SecondaryLead] = [],
        startTime: String = "",
        endTime: String = ""
    ) {
        self.eventDate = eventDate
        self.policeEventId = policeEventId
        self.patrolCallsign = patrolCallsign
        self.eventTypeId = eventTypeId
        self.roadId = roadId
        self.districtId = districtId
        self.location = location
        self.locationPlaceId = locationPlaceId
        self.locationLat = locationLat
        self.locationLng = locationLng
        self.locationPinSource = locationPinSource
        self.locationPinnedAt = locationPinnedAt
        self.locationPinnedBy = locationPinnedBy
        self.station = station
        self.notes = notes
        self.responders = responders
        self.isCancelled = isCancelled
        self.busLane = busLane
        self.shiftLeadId = shiftLeadId
        self.secondaryLeads = secondaryLeads
        self.startTime = startTime
        self.endTime = endTime
    }

    public var locationPin: LocationPinFields {
        LocationPinFields(
            location: location,
            locationPlaceId: locationPlaceId,
            locationLat: locationLat,
            locationLng: locationLng,
            locationPinSource: locationPinSource,
            locationPinnedAt: locationPinnedAt,
            locationPinnedBy: locationPinnedBy
        )
    }

    public mutating func applyLocationPin(_ pin: LocationPinFields) {
        location = pin.location
        locationPlaceId = pin.locationPlaceId
        locationLat = pin.locationLat
        locationLng = pin.locationLng
        locationPinSource = pin.locationPinSource
        locationPinnedAt = pin.locationPinnedAt
        locationPinnedBy = pin.locationPinnedBy
    }

    public var responderIds: [String] { responders.map(\.responderId) }

    /// Equality for confirm-without-change: ignore client-only flags that refresh after load.
    public func forPersistCompare() -> EventDraft {
        var copy = self
        copy.responders = responders.map {
            var row = $0
            row.hasVehicle = false
            return row
        }
        copy.secondaryLeads = secondaryLeads.map {
            var row = $0
            row.addedAt = nil
            return row
        }
        return copy
    }
}

public struct EventDraftErrors: Equatable, Sendable {
    public var eventDate: String?
    public var eventType: String?
    public var road: String?
    public var location: String?

    public init(
        eventDate: String? = nil,
        eventType: String? = nil,
        road: String? = nil,
        location: String? = nil
    ) {
        self.eventDate = eventDate
        self.eventType = eventType
        self.road = road
        self.location = location
    }

    public var isEmpty: Bool {
        eventDate == nil && eventType == nil && road == nil && location == nil
    }

    /// Matching web copy: the location variant only when מיקום is the missing piece.
    public var formMessage: String? {
        if isEmpty { return nil }
        if location != nil { return EVENT_DRAFT_FORM_LOCATION_ERROR }
        return EVENT_DRAFT_FORM_ERROR
    }
}

public func districtNeedsLocation(_ districts: [LookupOption], districtId: String) -> Bool {
    if districtId.isEmpty { return false }
    return districts.first(where: { $0.id == districtId })?.code == SYSTEM_DISTRICT_CODE
}

/// Optional תחנה name — same system שלוחה as mandatory מיקום.
public func districtNeedsStation(_ districts: [LookupOption], districtId: String) -> Bool {
    districtNeedsLocation(districts, districtId: districtId)
}

public func stationForSave(_ districts: [LookupOption], districtId: String, station: String) -> String? {
    if !districtNeedsStation(districts, districtId: districtId) { return nil }
    let trimmed = station.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return nil }
    return String(trimmed.prefix(STATION_MAX_LENGTH))
}

public func stationAfterDistrictChange(
    _ districts: [LookupOption],
    nextDistrictId: String,
    currentStation: String
) -> String {
    districtNeedsStation(districts, districtId: nextDistrictId) ? currentStation : ""
}

/// Draft save: date only, matching web `allowPartial`.
public func validateEventDraftPartial(_ draft: EventDraft) -> EventDraftErrors {
    EventDraftErrors(
        eventDate: normalizeReturnDate(draft.eventDate) == nil ? EVENT_DRAFT_DATE_ERROR : nil
    )
}

/// Minimum to create an event: date + event type + road (+ מיקום for the system שלוחה).
public func validateEventDraft(_ draft: EventDraft, districts: [LookupOption] = []) -> EventDraftErrors {
    EventDraftErrors(
        eventDate: normalizeReturnDate(draft.eventDate) == nil ? EVENT_DRAFT_DATE_ERROR : nil,
        eventType: draft.eventTypeId.isEmpty ? EVENT_DRAFT_TYPE_ERROR : nil,
        road: draft.roadId.isEmpty ? EVENT_DRAFT_ROAD_ERROR : nil,
        location: districtNeedsLocation(districts, districtId: draft.districtId) && draft.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? EVENT_DRAFT_LOCATION_ERROR
            : nil
    )
}

/// End clock earlier than start ⇒ overnight (end on event_date + 1).
public func isOvernightEnd(startTime: String, endTime: String) -> Bool {
    if startTime.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || endTime.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    {
        return false
    }
    return endTime < startTime
}

/// Wall-clock timestamp for Postgres `timestamp without time zone`.
public func wallTimestamp(eventDate: String, timeHm: String, dayOffset: Int = 0) -> String? {
    let time = timeHm.trimmingCharacters(in: .whitespacesAndNewlines)
    if time.isEmpty { return nil }
    guard let ymd = normalizeReturnDate(eventDate) else { return nil }
    let date = dayOffset == 0 ? ymd : addCalendarDays(ymd: ymd, days: dayOffset)
    let normalized = time.count == 5 ? "\(time):00" : time
    return "\(date)T\(normalized)"
}

public func toTimeInput(_ value: String?) -> String {
    formatTime(value) ?? ""
}

/// Lead `total_km` is never stored for a responder with no active vehicle.
public func leadKmForSave(hasVehicle: Bool, totalKm: String) -> Double? {
    if !hasVehicle { return nil }
    let trimmed = totalKm.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return nil }
    return Double(trimmed)
}

public struct FillReadyPreviousRow: Equatable, Sendable {
    public var id: String
    public var totalKm: Double?

    public init(id: String, totalKm: Double? = nil) {
        self.id = id
        self.totalKm = totalKm
    }
}

public struct FillReadyNextRow: Equatable, Sendable {
    public var assignmentId: String
    public var totalKm: Double?

    public init(assignmentId: String, totalKm: Double? = nil) {
        self.assignmentId = assignmentId
        self.totalKm = totalKm
    }
}

public func assignmentIdsNewlyAssigned(
    previous: [FillReadyPreviousRow],
    next: [FillReadyNextRow]
) -> [String] {
    let prevIds = Set(previous.map(\.id))
    return next.filter { !prevIds.contains($0.assignmentId) }.map(\.assignmentId)
}

public func assignmentIdsNewlySetKm(
    previous: [FillReadyPreviousRow],
    next: [FillReadyNextRow]
) -> [String] {
    return next.compactMap { row in
        guard row.totalKm != nil else { return nil }
        let prev = previous.first(where: { $0.id == row.assignmentId })?.totalKm
        return prev == nil ? row.assignmentId : nil
    }
}

/// Notify on first assignment, and still on first km for rows that were already assigned.
public func fillReadyNotifyIds(
    previous: [FillReadyPreviousRow],
    next: [FillReadyNextRow]
) -> [String] {
    var seen = Set<String>()
    var ids: [String] = []
    for id in assignmentIdsNewlyAssigned(previous: previous, next: next)
        + assignmentIdsNewlySetKm(previous: previous, next: next)
    {
        if seen.insert(id).inserted { ids.append(id) }
    }
    return ids
}

public func deriveEventStatusFromDraft(_ responders: [EventResponderDraft]) -> EventStatus {
    if responders.isEmpty { return .draft }
    if responders.allSatisfy({ $0.status == .done }) { return .done }
    if responders.contains(where: { $0.status == .done }) { return .partial }
    return .inProgress
}

/// A new event with no responders is a draft; adding pending crew opens it for documentation.
public func eventDraftStatus(responderCount: Int) -> EventStatus {
    responderCount == 0 ? .draft : .inProgress
}

public func eventDraftSummary(responderCount: Int) -> String {
    switch responderCount {
    case 0: return "טרם הוקצו מתנדבים · אירוע בהזנה"
    case 1: return "מתנדב אחד משובץ"
    default: return "\(responderCount) מתנדבים משובצים"
    }
}

/// When entering the system שלוחה the web defaults כביש to the road containing 101.
public func defaultRoadIdForSystemDistrict(_ roads: [LookupOption]) -> String? {
    roads.first(where: { $0.name.contains("101") })?.id
}

/// Entering the system שלוחה preselects the 101 road; any other change leaves כביש alone.
public func applyDistrictRoadDefault(
    previousDistrictId: String,
    nextDistrictId: String,
    districts: [LookupOption],
    roads: [LookupOption],
    currentRoadId: String
) -> String {
    let entering = !districtNeedsLocation(districts, districtId: previousDistrictId)
        && districtNeedsLocation(districts, districtId: nextDistrictId)
    if !entering { return currentRoadId }
    return defaultRoadIdForSystemDistrict(roads) ?? currentRoadId
}

/// Event crew has no ceiling, unlike a shift.
public func toggleEventResponder(
    _ selected: [EventResponderDraft],
    responderId: String,
    hasVehicle: Bool = true
) -> [EventResponderDraft] {
    if selected.contains(where: { $0.responderId == responderId }) {
        return selected.filter { $0.responderId != responderId }
    }
    return selected + [
        EventResponderDraft(
            responderId: responderId,
            emergencyMeans: NEW_RESPONDER_EMERGENCY_MEANS,
            hasVehicle: hasVehicle
        )
    ]
}

public func updateEventResponder(
    _ responders: [EventResponderDraft],
    responderId: String,
    transform: (EventResponderDraft) -> EventResponderDraft
) -> [EventResponderDraft] {
    responders.map { $0.responderId == responderId ? transform($0) : $0 }
}

public func bumpTreatedVehicle(
    _ responders: [EventResponderDraft],
    responderId: String,
    vehicleKindId: String,
    delta: Int
) -> [EventResponderDraft] {
    updateEventResponder(responders, responderId: responderId) { row in
        let current = row.treated.first(where: { $0.vehicleKindId == vehicleKindId })?.quantity ?? 0
        let next = max(current + delta, 0)
        var treated: [TreatedVehicleDraft]
        if next == 0 {
            treated = row.treated.filter { $0.vehicleKindId != vehicleKindId }
        } else {
            treated = row.treated.filter { $0.vehicleKindId != vehicleKindId }
            treated.append(TreatedVehicleDraft(vehicleKindId: vehicleKindId, quantity: next))
        }
        var copy = row
        copy.treated = treated
        return copy
    }
}

public func treatedQuantity(_ responder: EventResponderDraft, vehicleKindId: String) -> Int {
    responder.treated.first(where: { $0.vehicleKindId == vehicleKindId })?.quantity ?? 0
}

public func createIncludesSelfAssign(shiftLeadId: String, responders: [EventResponderDraft]) -> Bool {
    responders.contains { $0.responderId == shiftLeadId }
}

public func isSelfAssignDisabledOnCreate(isCreate: Bool, currentUserId: String?, profileId: String) -> Bool {
    isCreate && !(currentUserId ?? "").isEmpty && profileId == currentUserId
}

public let EVENT_CANCEL_ADMIN_ONLY = "רק מנהל או אחמ״ש יכולים לבטל סימון בוטל."
public let EVENT_CANCELLED_LABEL = "בוטל"

public func eventCancelToggleLabel(isCancelled: Bool) -> String {
    _ = isCancelled
    return EVENT_CANCELLED_LABEL
}

public func eventCancelToast(isCancelled: Bool) -> String {
    isCancelled ? "האירוע סומן כבוטל." : "סימון הביטול הוסר."
}

/// Clearing `is_cancelled` is allowed for admin, super_admin, and shift_lead.
public func canToggleEventCancelled(next: Bool, canClearCancelled: Bool) -> String? {
    if !next && !canClearCancelled { return EVENT_CANCEL_ADMIN_ONLY }
    return nil
}

public struct SameDayPoliceEventRow: Equatable, Sendable {
    public var id: String
    public var shiftLeadId: String?
    public var isCancelled: Bool

    public init(id: String, shiftLeadId: String? = nil, isCancelled: Bool = false) {
        self.id = id
        self.shiftLeadId = shiftLeadId
        self.isCancelled = isCancelled
    }
}

/// Own same-day מספר אירוע after a create whose response never came back.
public func ownResumableEventId(
    currentEventId: String?,
    viewerLeadId: String,
    existing: [SameDayPoliceEventRow]
) -> String? {
    if let current = currentEventId, !current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return nil
    }
    let mine = existing.filter { !$0.isCancelled && $0.shiftLeadId == viewerLeadId }
    return mine.count == 1 ? mine[0].id : nil
}
