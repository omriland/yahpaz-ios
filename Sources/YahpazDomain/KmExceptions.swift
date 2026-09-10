import Foundation

public let KM_EXCEPTION_THRESHOLD = 60.0

public struct KmExceptionResponderInput: Equatable, Sendable {
    public var totalKm: Double?
    public var name: String?
    public var callsign: String?

    public init(totalKm: Double? = nil, name: String? = nil, callsign: String? = nil) {
        self.totalKm = totalKm
        self.name = name
        self.callsign = callsign
    }
}

public struct KmExceptionEventInput: Equatable, Sendable {
    public var id: String
    public var eventDate: String
    public var isCancelled: Bool
    public var policeEventId: String?
    public var location: String?
    public var eventTypeName: String?
    public var roadName: String?
    public var leadName: String?
    public var leadCallsign: String?
    public var responders: [KmExceptionResponderInput]

    public init(
        id: String,
        eventDate: String,
        isCancelled: Bool = false,
        policeEventId: String? = nil,
        location: String? = nil,
        eventTypeName: String? = nil,
        roadName: String? = nil,
        leadName: String? = nil,
        leadCallsign: String? = nil,
        responders: [KmExceptionResponderInput] = []
    ) {
        self.id = id
        self.eventDate = eventDate
        self.isCancelled = isCancelled
        self.policeEventId = policeEventId
        self.location = location
        self.eventTypeName = eventTypeName
        self.roadName = roadName
        self.leadName = leadName
        self.leadCallsign = leadCallsign
        self.responders = responders
    }
}

public struct KmExceptionRow: Equatable, Sendable {
    public var eventId: String
    public var eventDate: String
    public var isCancelled: Bool
    public var policeEventId: String?
    public var location: String?
    public var eventTypeName: String?
    public var roadName: String?
    public var leadName: String?
    public var leadCallsign: String?
    public var responderName: String?
    public var responderCallsign: String?
    public var totalKm: Double

    public var responderDisplay: String { personDisplay(responderName, callsign: responderCallsign) }
    public var placeDisplay: String { YahpazDomain.placeDisplay(roadName, location) }
}

/// Flatten events → exceptional responder rows; sort date desc, then km desc.
/// Only lead-entered `total_km` counts — participation status is irrelevant.
public func buildKmExceptionRows(
    _ events: [KmExceptionEventInput],
    from: String? = nil,
    to: String? = nil
) -> [KmExceptionRow] {
    var rows: [KmExceptionRow] = []
    for event in events {
        if let from, event.eventDate < from { continue }
        if let to, event.eventDate > to { continue }
        for responder in event.responders {
            guard let km = responder.totalKm, km >= KM_EXCEPTION_THRESHOLD else { continue }
            rows.append(KmExceptionRow(
                eventId: event.id,
                eventDate: event.eventDate,
                isCancelled: event.isCancelled,
                policeEventId: event.policeEventId,
                location: event.location,
                eventTypeName: event.eventTypeName,
                roadName: event.roadName,
                leadName: event.leadName,
                leadCallsign: event.leadCallsign,
                responderName: responder.name,
                responderCallsign: responder.callsign,
                totalKm: km
            ))
        }
    }
    return rows.sorted {
        if $0.eventDate != $1.eventDate { return $0.eventDate > $1.eventDate }
        return $0.totalKm > $1.totalKm
    }
}

public func kmExceptionReportRows(_ rows: [KmExceptionRow]) -> [ReportRow] {
    rows.enumerated().map { index, row in
        let typeName = row.eventTypeName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let lead = personDisplay(row.leadName, callsign: row.leadCallsign, fallback: "")
        return ReportRow(
            id: "\(row.eventId):\(row.responderCallsign ?? ""):\(index)",
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
                lead.isEmpty ? nil : "אחמ״ש: \(lead)",
            ].compactMap { $0 }.joined(separator: " · ").nilIfEmpty,
            trailing: "\(formatNumber(row.totalKm)) ק״מ",
            eventId: row.eventId,
            searchText: [
                row.responderDisplay,
                row.policeEventId ?? "",
                row.placeDisplay,
            ].joined(separator: " ")
        )
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
