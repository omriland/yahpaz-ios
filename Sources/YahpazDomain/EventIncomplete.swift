import Foundation

/**
 Incomplete-event detection for the unit (אחמ״ש) event list.

 An event is incomplete when one or more required documentation fields are
 missing. Incomplete events pin to the top of the list regardless of status
 (including ממתין לתיעוד).
 */
public enum IncompleteField: String, CaseIterable, Sendable {
    case policeEventId
    case patrolCallsign
    case district
    case eventType
    case road
    case location
    case responderKm
    case eventTimes
}

public let INCOMPLETE_FIELD_LABELS: [IncompleteField: String] = [
    .policeEventId: "מספר אירוע",
    .patrolCallsign: "אוק - מס",
    .district: "שלוחה",
    .eventType: "סוג אירוע",
    .road: "כביש",
    .location: "מיקום",
    .responderKm: "ק״מ",
    .eventTimes: "שעות",
]

public let INCOMPLETE_EVENTS_HEADING = "דורשים השלמת פרטים"
public let INCOMPLETE_NOTICE_MARK = "פרטים חסרים:"
public let HELD_FROM_RESPONDERS_LABEL = "לא נשלח למתנדבים"
public let RESPONDERS_HELD_FOR_POLICE_ID_NOTE =
    "האירוע לא יוצג למתנדב עד שאו״ק, כביש ומספר אירוע מלאים."

public struct IncompleteResponderSnapshot: Equatable, Sendable {
    public var totalKm: Double?
    public var startedAt: String?
    public var endedAt: String?

    public init(totalKm: Double? = nil, startedAt: String? = nil, endedAt: String? = nil) {
        self.totalKm = totalKm
        self.startedAt = startedAt
        self.endedAt = endedAt
    }
}

public struct IncompleteEventSnapshot: Equatable, Sendable {
    public var origin: String?
    public var policeEventId: String?
    public var patrolCallsign: String?
    public var patrolCallsignNumber: String?
    public var startedAt: String?
    public var endedAt: String?
    public var hasDistrict: Bool
    public var hasEventType: Bool
    public var hasRoad: Bool
    public var location: String?
    public var responders: [IncompleteResponderSnapshot]

    public init(
        origin: String? = nil,
        policeEventId: String? = nil,
        patrolCallsign: String? = nil,
        patrolCallsignNumber: String? = nil,
        startedAt: String? = nil,
        endedAt: String? = nil,
        hasDistrict: Bool = false,
        hasEventType: Bool = false,
        hasRoad: Bool = false,
        location: String? = nil,
        responders: [IncompleteResponderSnapshot] = []
    ) {
        self.origin = origin
        self.policeEventId = policeEventId
        self.patrolCallsign = patrolCallsign
        self.patrolCallsignNumber = patrolCallsignNumber
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.hasDistrict = hasDistrict
        self.hasEventType = hasEventType
        self.hasRoad = hasRoad
        self.location = location
        self.responders = responders
    }
}

private func isMissing(_ value: String?) -> Bool {
    value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
}

public func missingEventFields(_ event: IncompleteEventSnapshot) -> Set<IncompleteField> {
    var missing = Set<IncompleteField>()
    if isMissing(event.policeEventId) { missing.insert(.policeEventId) }
    let callsign = resolvePatrolCallsign(number: event.patrolCallsignNumber, legacy: event.patrolCallsign)
    if isMissing(callsign.number) { missing.insert(.patrolCallsign) }
    if !event.hasDistrict { missing.insert(.district) }
    if !event.hasEventType { missing.insert(.eventType) }
    if !event.hasRoad { missing.insert(.road) }
    if isMissing(event.location) { missing.insert(.location) }

    if event.startedAt != nil || event.endedAt != nil {
        if isMissing(event.startedAt) || isMissing(event.endedAt) {
            missing.insert(.eventTimes)
        }
    } else if event.responders.contains(where: { isMissing($0.startedAt) || isMissing($0.endedAt) }) {
        missing.insert(.eventTimes)
    }

    if event.responders.contains(where: { $0.totalKm == nil }) {
        missing.insert(.responderKm)
    }
    return missing
}

public func incompleteFieldLabels(_ fields: Set<IncompleteField>) -> [String] {
    IncompleteField.allCases.filter { fields.contains($0) }.compactMap { INCOMPLETE_FIELD_LABELS[$0] }
}

public func incompleteNoticeLabel(_ fields: Set<IncompleteField>) -> String {
    "חסרים: \(incompleteFieldLabels(fields).joined(separator: " · "))"
}

/// Lead-facing chips: the missing fields, plus `לא נשלח למתנדבים` while assigned crew cannot see it yet.
public func incompleteLeadNoticeLabels(_ event: IncompleteEventSnapshot) -> [String] {
    let labels = incompleteFieldLabels(missingEventFields(event))
    let held = !event.responders.isEmpty && !eventReleasedToResponders(
        origin: event.origin,
        policeEventId: event.policeEventId,
        patrolCallsignNumber: event.patrolCallsignNumber,
        hasRoad: event.hasRoad,
        patrolCallsignLegacy: event.patrolCallsign
    )
    return held ? labels + [HELD_FROM_RESPONDERS_LABEL] : labels
}

public func isEventIncomplete(_ event: IncompleteEventSnapshot) -> Bool {
    !missingEventFields(event).isEmpty
}

public func eventHasMissingResponderKm(_ event: IncompleteEventSnapshot) -> Bool {
    missingEventFields(event).contains(.responderKm)
}

public func partitionIncompleteEvents<T>(
    _ events: [T],
    snapshot: (T) -> IncompleteEventSnapshot
) -> (incomplete: [T], rest: [T]) {
    var incomplete: [T] = []
    var rest: [T] = []
    for event in events {
        if isEventIncomplete(snapshot(event)) {
            incomplete.append(event)
        } else {
            rest.append(event)
        }
    }
    return (incomplete, rest)
}
