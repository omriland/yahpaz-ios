import Foundation

/// אירועים עם פערי דיווח ק״מ. Mirrors the web `kmDiscrepancyReport.ts`: a completed
/// participation where the lead's `total_km` disagrees with the odometer the responder
/// entered. Admin can replace the lead figure with the odometer difference.
public struct KmDiscrepancyResponderInput: Equatable, Sendable {
    public var assignmentId: String
    public var status: ParticipationStatus
    public var totalKm: Double?
    public var odometerStart: Double?
    public var odometerEnd: Double?
    public var name: String?
    public var callsign: String?

    public init(
        assignmentId: String,
        status: ParticipationStatus,
        totalKm: Double? = nil,
        odometerStart: Double? = nil,
        odometerEnd: Double? = nil,
        name: String? = nil,
        callsign: String? = nil
    ) {
        self.assignmentId = assignmentId
        self.status = status
        self.totalKm = totalKm
        self.odometerStart = odometerStart
        self.odometerEnd = odometerEnd
        self.name = name
        self.callsign = callsign
    }
}

public struct KmDiscrepancyEventInput: Equatable, Sendable {
    public var id: String
    public var eventDate: String
    public var isCancelled: Bool
    public var policeEventId: String?
    public var location: String?
    public var roadName: String?
    public var leadName: String?
    public var leadCallsign: String?
    public var responders: [KmDiscrepancyResponderInput]

    public init(
        id: String,
        eventDate: String,
        isCancelled: Bool = false,
        policeEventId: String? = nil,
        location: String? = nil,
        roadName: String? = nil,
        leadName: String? = nil,
        leadCallsign: String? = nil,
        responders: [KmDiscrepancyResponderInput] = []
    ) {
        self.id = id
        self.eventDate = eventDate
        self.isCancelled = isCancelled
        self.policeEventId = policeEventId
        self.location = location
        self.roadName = roadName
        self.leadName = leadName
        self.leadCallsign = leadCallsign
        self.responders = responders
    }
}

public struct KmDiscrepancyRow: Equatable, Sendable {
    public var assignmentId: String
    public var eventId: String
    public var eventDate: String
    public var isCancelled: Bool
    public var policeEventId: String?
    public var location: String?
    public var roadName: String?
    public var responderName: String?
    public var responderCallsign: String?
    public var leadName: String?
    public var leadCallsign: String?
    public var leadKm: Double
    public var responderKm: Double

    public var diff: Double { responderKm - leadKm }
    public var responderDisplay: String {
        personDisplay(responderName, callsign: responderCallsign, fallback: "מתנדב")
    }
    public var placeDisplay: String { YahpazDomain.placeDisplay(roadName, location) }
}

/// Result of asking to overwrite the lead km with the responder's odometer difference.
public enum LeadKmReplacement: Equatable, Sendable {
    case replace(totalKm: Double)
    case alreadyAligned
    case invalid
}

public func responderOdometerKm(start: Double?, end: Double?) -> Double? {
    guard let start, let end else { return nil }
    return end - start
}

public func resolveLeadKmReplacement(
    totalKm: Double?,
    odometerStart: Double?,
    odometerEnd: Double?
) -> LeadKmReplacement {
    guard let next = responderOdometerKm(start: odometerStart, end: odometerEnd), let totalKm else {
        return .invalid
    }
    if next == totalKm { return .alreadyAligned }
    return .replace(totalKm: next)
}

/// Date desc, then the biggest absolute gap, then responder name.
public func buildKmDiscrepancyRows(
    _ events: [KmDiscrepancyEventInput],
    from: String? = nil,
    to: String? = nil
) -> [KmDiscrepancyRow] {
    var rows: [KmDiscrepancyRow] = []
    for event in events {
        if let from, event.eventDate < from { continue }
        if let to, event.eventDate > to { continue }
        for responder in event.responders {
            if responder.status != .done { continue }
            guard let leadKm = responder.totalKm else { continue }
            guard let responderKm = responderOdometerKm(
                start: responder.odometerStart,
                end: responder.odometerEnd
            ) else { continue }
            if responderKm == leadKm { continue }
            rows.append(KmDiscrepancyRow(
                assignmentId: responder.assignmentId,
                eventId: event.id,
                eventDate: event.eventDate,
                isCancelled: event.isCancelled,
                policeEventId: event.policeEventId,
                location: event.location,
                roadName: event.roadName,
                responderName: responder.name,
                responderCallsign: responder.callsign,
                leadName: event.leadName,
                leadCallsign: event.leadCallsign,
                leadKm: leadKm,
                responderKm: responderKm
            ))
        }
    }
    return rows.sorted {
        if $0.eventDate != $1.eventDate { return $0.eventDate > $1.eventDate }
        let left = abs($0.diff)
        let right = abs($1.diff)
        if left != right { return left > right }
        return $0.responderDisplay < $1.responderDisplay
    }
}

public func kmDiscrepancyApplyTitle(_ responderKm: Double) -> String {
    "החלפה ל־\(formatNumber(responderKm)) ק״מ"
}

public func kmDiscrepancyApplyConfirm(_ responderKm: Double) -> String {
    "הקילומטרים שהזין האחמ״ש יוחלפו ב־\(formatNumber(responderKm)) ק״מ לפי מד האוץ של המתנדב."
}

public let KM_DISCREPANCY_APPLIED = "הקילומטרים עודכנו לפי מד האוץ."
public let KM_DISCREPANCY_ALIGNED = "הדיווחים כבר תואמים."
public let KM_DISCREPANCY_APPLY_FAILED = "עדכון הקילומטרים נכשל. נסו שוב."

public func kmDiscrepancyReportRows(_ rows: [KmDiscrepancyRow]) -> [ReportRow] {
    rows.map { row in
        let lead = personDisplay(row.leadName, callsign: row.leadCallsign, fallback: "")
        return ReportRow(
            id: "\(row.eventId):\(row.assignmentId)",
            title: row.responderDisplay,
            subtitle: [
                formatDate(row.eventDate),
                policeEventLabel(row.policeEventId, isCancelled: row.isCancelled) == "—"
                    ? nil
                    : policeEventLabel(row.policeEventId, isCancelled: row.isCancelled),
                row.placeDisplay.isEmpty ? nil : row.placeDisplay,
            ].compactMap { $0 }.joined(separator: " · "),
            detail: lead.isEmpty ? nil : "אחמ״ש: \(lead)",
            trailing: [
                "אחמ״ש \(formatNumber(row.leadKm))",
                "מתנדב \(formatNumber(row.responderKm))",
                "פער \(formatNumber(row.diff))",
            ].joined(separator: " · "),
            eventId: row.eventId,
            actionId: row.assignmentId,
            actionTitle: kmDiscrepancyApplyTitle(row.responderKm),
            actionConfirm: kmDiscrepancyApplyConfirm(row.responderKm),
            searchText: [
                row.responderDisplay,
                row.policeEventId ?? "",
                row.placeDisplay,
            ].joined(separator: " ")
        )
    }
}
