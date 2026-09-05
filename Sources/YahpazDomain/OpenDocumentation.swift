import Foundation

public let OPEN_DOC_TITLE = "אירועים שהוזנו ע״י אחמ״ש ולא נסגרו ע״י מתנדב"
public let OPEN_DOC_EMPTY_TITLE = "אין דיווחים פתוחים בתקופה זו"
public let OPEN_DOC_FAILED_TITLE = "טעינת הדוח נכשלה. בדקו את החיבור ונסו שוב."
public let OPEN_DOC_RANGE_ERROR = "יש להזין תאריך התחלה וסיום תקינים"
public let OPEN_DOC_DEFAULT_RANGE_DAYS = 30

public enum OpenDocFillStatus: Sendable, Equatable {
    case pending
    case inProgress
}

public func openDocFillLabel(_ status: OpenDocFillStatus) -> String {
    status == .inProgress ? "נשמרה טיוטה" : "טרם הוזן"
}

/// Only events still awaiting documentation appear in the report.
private let OPEN_EVENT_STATUSES: Set<EventStatus> = [.inProgress, .partial]
private let OPEN_PARTICIPATION_STATUSES: Set<ParticipationStatus> = [.pending, .inProgress]

public struct OpenDocResponderInput: Equatable, Sendable {
    public var responderId: String
    public var status: ParticipationStatus
    public var name: String?
    public var callsign: String?

    public init(
        responderId: String,
        status: ParticipationStatus,
        name: String? = nil,
        callsign: String? = nil
    ) {
        self.responderId = responderId
        self.status = status
        self.name = name
        self.callsign = callsign
    }
}

public struct OpenDocEventInput: Equatable, Sendable {
    public var id: String
    public var eventDate: String
    public var status: EventStatus
    public var isCancelled: Bool
    public var policeEventId: String?
    public var location: String?
    public var roadName: String?
    public var shiftLeadId: String?
    public var leadName: String?
    public var leadCallsign: String?
    public var responders: [OpenDocResponderInput]

    public init(
        id: String,
        eventDate: String,
        status: EventStatus,
        isCancelled: Bool = false,
        policeEventId: String? = nil,
        location: String? = nil,
        roadName: String? = nil,
        shiftLeadId: String? = nil,
        leadName: String? = nil,
        leadCallsign: String? = nil,
        responders: [OpenDocResponderInput] = []
    ) {
        self.id = id
        self.eventDate = eventDate
        self.status = status
        self.isCancelled = isCancelled
        self.policeEventId = policeEventId
        self.location = location
        self.roadName = roadName
        self.shiftLeadId = shiftLeadId
        self.leadName = leadName
        self.leadCallsign = leadCallsign
        self.responders = responders
    }
}

public struct OpenDocRow: Equatable, Sendable {
    public var id: String
    public var eventId: String
    public var eventDate: String
    public var policeEventId: String?
    public var location: String?
    public var roadName: String?
    public var responderName: String?
    public var responderCallsign: String?
    public var leadName: String?
    public var leadCallsign: String?
    public var fillStatus: OpenDocFillStatus

    public var fillStatusLabel: String { openDocFillLabel(fillStatus) }

    public var responderDisplay: String {
        [responderName, responderCallsign].compactMap { value -> String? in
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? nil : trimmed
        }.joined(separator: " · ").ifEmpty("מתנדב")
    }

    public var leadDisplay: String {
        [leadName, leadCallsign].compactMap { value -> String? in
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? nil : trimmed
        }.joined(separator: " · ")
    }
}

public func buildOpenDocRows(
    events: [OpenDocEventInput],
    from: String,
    to: String,
    viewerId: String?,
    viewerIsAdmin: Bool
) -> [OpenDocRow] {
    var rows: [OpenDocRow] = []
    for event in events {
        if !OPEN_EVENT_STATUSES.contains(event.status) { continue }
        if event.isCancelled { continue }
        if event.eventDate < from || event.eventDate > to { continue }
        if !viewerIsAdmin && event.shiftLeadId != viewerId { continue }
        for responder in event.responders {
            if !OPEN_PARTICIPATION_STATUSES.contains(responder.status) { continue }
            rows.append(OpenDocRow(
                id: "\(event.id):\(responder.responderId)",
                eventId: event.id,
                eventDate: event.eventDate,
                policeEventId: event.policeEventId,
                location: event.location,
                roadName: event.roadName,
                responderName: responder.name,
                responderCallsign: responder.callsign,
                leadName: event.leadName,
                leadCallsign: event.leadCallsign,
                fillStatus: responder.status == .inProgress ? .inProgress : .pending
            ))
        }
    }
    return rows.sorted {
        if $0.eventDate != $1.eventDate { return $0.eventDate > $1.eventDate }
        let left = "\($0.responderName ?? "") \($0.responderCallsign ?? "")"
        let right = "\($1.responderName ?? "") \($1.responderCallsign ?? "")"
        return left < right
    }
}

public func openDocReportRows(_ rows: [OpenDocRow]) -> [ReportRow] {
    rows.map { row in
        ReportRow(
            id: row.id,
            title: row.responderDisplay,
            subtitle: [
                formatDate(row.eventDate),
                row.policeEventId?.isEmpty == false ? row.policeEventId : nil,
                placeDisplay(row.roadName, row.location).nilIfEmpty,
            ].compactMap { $0 }.joined(separator: " · "),
            detail: row.leadDisplay.isEmpty ? nil : "אחמ״ש: \(row.leadDisplay)",
            eventId: row.eventId,
            stampLabel: row.fillStatusLabel,
            stampTone: row.fillStatus == .inProgress ? .draft : .pending,
            searchText: [
                row.responderDisplay,
                row.policeEventId ?? "",
                placeDisplay(row.roadName, row.location),
            ].joined(separator: " ")
        )
    }
}

public func openDocSummary(_ count: Int) -> String {
    switch count {
    case 0: return OPEN_DOC_EMPTY_TITLE
    case 1: return "דיווח אחד ממתין לתיעוד"
    default: return "\(count) דיווחים ממתינים לתיעוד"
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }

    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
