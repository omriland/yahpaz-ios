import Foundation

public let PATROL_CALLSIGN_PREFIX_MAX_LENGTH = 16
public let PATROL_CALLSIGN_NUMBER_MAX_LENGTH = 5
public let PATROL_CALLSIGN_PREFIX_LABEL = "אוק - כינוי"
public let PATROL_CALLSIGN_NUMBER_LABEL = "אוק - מס"
public let PATROL_CALLSIGN_PREFIX_PLACEHOLDER = "אביב"
public let PATROL_CALLSIGN_NUMBER_PLACEHOLDER = "411"

public struct SplitPatrolCallsign: Equatable, Sendable {
    public var prefix: String
    public var number: String

    public init(prefix: String = "", number: String = "") {
        self.prefix = prefix
        self.number = number
    }
}

/// Split a legacy `או״ק ניידת` value into prefix + number (last digit run).
public func splitPatrolCallsign(_ raw: String?) -> SplitPatrolCallsign {
    let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if trimmed.isEmpty { return SplitPatrolCallsign() }
    let chars = Array(trimmed)
    var digitEnd: Int?
    var digitStart: Int?
    for index in stride(from: chars.count - 1, through: 0, by: -1) {
        if chars[index].isNumber {
            if digitEnd == nil { digitEnd = index }
            digitStart = index
        } else if digitEnd != nil {
            break
        }
    }
    guard let start = digitStart, let end = digitEnd else {
        return SplitPatrolCallsign(prefix: trimmed)
    }
    let number = String(chars[start...end].prefix(PATROL_CALLSIGN_NUMBER_MAX_LENGTH))
    let before = String(chars[..<start])
    let after = end + 1 < chars.count ? String(chars[(end + 1)...]) : ""
    let prefix = "\(before)\(after)"
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    return SplitPatrolCallsign(prefix: prefix, number: number)
}

public func formatPatrolCallsign(_ prefix: String?, _ number: String?) -> String {
    [prefix, number]
        .compactMap { value -> String? in
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? nil : trimmed
        }
        .joined(separator: " ")
}

public func patrolCallsignPrefixForInput(_ raw: String) -> String {
    String(raw.prefix(PATROL_CALLSIGN_PREFIX_MAX_LENGTH))
}

public func patrolCallsignNumberForInput(_ raw: String) -> String {
    String(digitsOnly(raw).prefix(PATROL_CALLSIGN_NUMBER_MAX_LENGTH))
}

public func resolvePatrolCallsign(prefix: String? = nil, number: String? = nil, legacy: String? = nil) -> SplitPatrolCallsign {
    let resolvedPrefix = prefix ?? ""
    let resolvedNumber = number ?? ""
    if !resolvedPrefix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || !resolvedNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    {
        return SplitPatrolCallsign(
            prefix: resolvedPrefix.trimmingCharacters(in: .whitespacesAndNewlines),
            number: digitsOnly(resolvedNumber)
        )
    }
    return splitPatrolCallsign(legacy)
}

public func applyEventTimesToResponders(
    _ responders: [EventResponderDraft],
    startTime: String,
    endTime: String
) -> [EventResponderDraft] {
    responders.map { row in
        var copy = row
        copy.startTime = startTime
        copy.endTime = endTime
        return copy
    }
}

public func eventFormTimes(
    eventStart: String?,
    eventEnd: String?,
    responders: [EventResponderDraft],
    fallbackStart: String
) -> (start: String, end: String) {
    let start = toTimeInput(eventStart)
    let end = toTimeInput(eventEnd)
    let responderStarts = responders.map(\.startTime).filter { !$0.isEmpty }.sorted()
    let responderEnds = responders.map(\.endTime).filter { !$0.isEmpty }.sorted()
    return (
        start.isEmpty ? (responderStarts.first ?? fallbackStart) : start,
        end.isEmpty ? (responderEnds.last ?? "") : end
    )
}

public func eventFormPrimaryTitle(editing: Bool) -> String {
    editing ? EVENT_SAVE_TITLE : EVENT_CREATE_TITLE
}

public func eventFormDraftTitle(editing: Bool) -> String {
    editing ? EVENT_SAVE_DRAFT_TITLE : EVENT_CREATE_DRAFT_TITLE
}

public struct EventSaveOutcome: Equatable, Sendable {
    public var error: String?
    public var eventId: String?

    public init(error: String? = nil, eventId: String? = nil) {
        self.error = error
        self.eventId = eventId
    }

    public static func failed(_ error: String) -> EventSaveOutcome {
        EventSaveOutcome(error: error)
    }

    public static func saved(_ eventId: String) -> EventSaveOutcome {
        EventSaveOutcome(eventId: eventId)
    }
}
