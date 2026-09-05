import Foundation

public struct EventsByResponderResponderInput: Equatable, Sendable {
    public var responderId: String
    public var totalKm: Double?
    public var name: String?
    public var callsign: String?

    public init(
        responderId: String,
        totalKm: Double? = nil,
        name: String? = nil,
        callsign: String? = nil
    ) {
        self.responderId = responderId
        self.totalKm = totalKm
        self.name = name
        self.callsign = callsign
    }
}

public struct EventsByResponderEventInput: Equatable, Sendable {
    public var id: String
    public var eventDate: String
    public var isCancelled: Bool
    public var policeEventId: String?
    public var location: String?
    public var eventTypeName: String?
    public var districtName: String?
    public var roadName: String?
    public var leadName: String?
    public var leadCallsign: String?
    public var responders: [EventsByResponderResponderInput]

    public init(
        id: String,
        eventDate: String,
        isCancelled: Bool = false,
        policeEventId: String? = nil,
        location: String? = nil,
        eventTypeName: String? = nil,
        districtName: String? = nil,
        roadName: String? = nil,
        leadName: String? = nil,
        leadCallsign: String? = nil,
        responders: [EventsByResponderResponderInput] = []
    ) {
        self.id = id
        self.eventDate = eventDate
        self.isCancelled = isCancelled
        self.policeEventId = policeEventId
        self.location = location
        self.eventTypeName = eventTypeName
        self.districtName = districtName
        self.roadName = roadName
        self.leadName = leadName
        self.leadCallsign = leadCallsign
        self.responders = responders
    }
}

public struct EventsByResponderRow: Equatable, Sendable {
    public var id: String
    public var eventId: String
    public var eventDate: String
    public var isCancelled: Bool
    public var policeEventId: String?
    public var eventTypeName: String?
    public var districtName: String?
    public var roadName: String?
    public var location: String?
    public var leadName: String?
    public var leadCallsign: String?
    public var totalKm: Double?
    public var responderId: String
    public var responderName: String?
    public var responderCallsign: String?

    public var responderDisplay: String { personDisplay(responderName, callsign: responderCallsign) }
    /// Android ports callsign first on this report (`personDisplay(leadCallsign, leadName)`).
    public var leadDisplay: String { personDisplay(leadCallsign, callsign: leadName, fallback: "") }
    public var placeDisplay: String { YahpazDomain.placeDisplay(roadName, location) }
}

private func responderSortKey(_ row: EventsByResponderRow) -> String {
    [row.responderName ?? "", row.responderCallsign ?? "", row.responderId].joined(separator: " ")
}

/// Flatten events → one row per volunteer; sort name asc, then date desc.
public func buildEventsByResponderRows(
    _ events: [EventsByResponderEventInput],
    from: String,
    to: String
) -> [EventsByResponderRow] {
    var rows: [EventsByResponderRow] = []
    for event in events {
        if event.eventDate < from || event.eventDate > to { continue }
        for responder in event.responders {
            rows.append(EventsByResponderRow(
                id: "\(event.id):\(responder.responderId)",
                eventId: event.id,
                eventDate: event.eventDate,
                isCancelled: event.isCancelled,
                policeEventId: event.policeEventId,
                eventTypeName: event.eventTypeName,
                districtName: event.districtName,
                roadName: event.roadName,
                location: event.location,
                leadName: event.leadName,
                leadCallsign: event.leadCallsign,
                totalKm: responder.totalKm,
                responderId: responder.responderId,
                responderName: responder.name,
                responderCallsign: responder.callsign
            ))
        }
    }
    return rows.sorted {
        let left = responderSortKey($0)
        let right = responderSortKey($1)
        if left != right { return left < right }
        return $0.eventDate > $1.eventDate
    }
}

public func eventsByResponderReportRows(_ rows: [EventsByResponderRow]) -> [ReportRow] {
    rows.map { row in
        let typeName = row.eventTypeName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let district = row.districtName?.trimmingCharacters(in: .whitespacesAndNewlines)
        return ReportRow(
            id: row.id,
            title: row.responderDisplay,
            subtitle: [
                formatDate(row.eventDate),
                policeEventLabel(row.policeEventId, isCancelled: row.isCancelled) == "—"
                    ? nil
                    : policeEventLabel(row.policeEventId, isCancelled: row.isCancelled),
                (typeName?.isEmpty == false) ? typeName : nil,
            ].compactMap { $0 }.joined(separator: " · "),
            detail: [
                row.placeDisplay.isEmpty ? nil : row.placeDisplay,
                (district?.isEmpty == false) ? district : nil,
                row.leadDisplay.isEmpty ? nil : "אחמ״ש: \(row.leadDisplay)",
            ].compactMap { $0 }.joined(separator: " · ").nilIfEmpty,
            trailing: row.totalKm.map { "\(formatNumber($0)) ק״מ" },
            eventId: row.eventId,
            stampLabel: row.isCancelled ? "בוטל" : nil,
            stampTone: .draft,
            searchText: [
                row.responderDisplay,
                row.policeEventId ?? "",
                row.placeDisplay,
                row.districtName ?? "",
            ].joined(separator: " ")
        )
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
