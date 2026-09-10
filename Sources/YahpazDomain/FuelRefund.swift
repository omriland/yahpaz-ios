import Foundation

public struct FuelRefundProfileInput: Equatable, Sendable {
    public var id: String
    public var fullName: String
    public var callsign: String

    public init(id: String, fullName: String, callsign: String) {
        self.id = id
        self.fullName = fullName
        self.callsign = callsign
    }
}

/// Participation km for refunds — only lead-entered `total_km` counts.
public struct FuelRefundParticipationInput: Equatable, Sendable {
    public var responderId: String
    public var eventId: String
    public var totalKm: Double?

    public init(responderId: String, eventId: String, totalKm: Double? = nil) {
        self.responderId = responderId
        self.eventId = eventId
        self.totalKm = totalKm
    }
}

/// Extra km that is not an event participation (private-vehicle shift).
public struct FuelRefundCreditInput: Equatable, Sendable {
    public var responderId: String
    public var totalKm: Double

    public init(responderId: String, totalKm: Double) {
        self.responderId = responderId
        self.totalKm = totalKm
    }
}

public struct FuelRefundRow: Equatable, Sendable {
    public var id: String
    public var fullName: String
    public var callsign: String
    public var totalKm: Double
    public var eventCount: Int
}

public func buildFuelRefundRows(
    profiles: [FuelRefundProfileInput],
    participations: [FuelRefundParticipationInput],
    credits: [FuelRefundCreditInput] = []
) -> [FuelRefundRow] {
    let withKm = participations.filter { $0.totalKm != nil }
    let byUser = Dictionary(grouping: withKm, by: \.responderId)
    let extraByUser = Dictionary(grouping: credits, by: \.responderId)
        .mapValues { $0.reduce(0) { $0 + $1.totalKm } }

    return profiles.map { profile in
        let parts = byUser[profile.id] ?? []
        return FuelRefundRow(
            id: profile.id,
            fullName: profile.fullName,
            callsign: profile.callsign,
            totalKm: parts.reduce(0) { $0 + ($1.totalKm ?? 0) } + (extraByUser[profile.id] ?? 0),
            eventCount: parts.count
        )
    }.sorted { $0.fullName < $1.fullName }
}

public func fuelRefundReportRows(_ rows: [FuelRefundRow]) -> [ReportRow] {
    rows.map { row in
        ReportRow(
            id: row.id,
            title: personDisplay(row.fullName, callsign: row.callsign),
            subtitle: row.eventCount == 1 ? "אירוע אחד" : "\(row.eventCount) אירועים",
            trailing: "\(formatNumber(row.totalKm)) ק״מ",
            searchText: "\(row.fullName) \(row.callsign)"
        )
    }
}
