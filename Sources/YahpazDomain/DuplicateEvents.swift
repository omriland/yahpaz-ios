import Foundation

/// אירועים כפולים. Mirrors the web `duplicateEventsReport.ts`: the same responder logged
/// on two different events, same day, same location, started within half an hour.
/// Matches are transitive, so a triple collapses into one cluster.
public let DUPLICATE_TIME_WINDOW_MINUTES = 30

private let WINDOW_MS = Int64(DUPLICATE_TIME_WINDOW_MINUTES * 60 * 1000)

public struct DuplicateParticipation: Equatable, Sendable {
    public var eventId: String
    public var responderId: String
    public var eventDate: String
    public var location: String?
    public var startedAt: String?
    public var isCancelled: Bool
    public var policeEventId: String?
    public var eventTypeName: String?
    public var roadName: String?
    public var name: String?
    public var callsign: String?

    public init(
        eventId: String,
        responderId: String,
        eventDate: String,
        location: String? = nil,
        startedAt: String? = nil,
        isCancelled: Bool = false,
        policeEventId: String? = nil,
        eventTypeName: String? = nil,
        roadName: String? = nil,
        name: String? = nil,
        callsign: String? = nil
    ) {
        self.eventId = eventId
        self.responderId = responderId
        self.eventDate = eventDate
        self.location = location
        self.startedAt = startedAt
        self.isCancelled = isCancelled
        self.policeEventId = policeEventId
        self.eventTypeName = eventTypeName
        self.roadName = roadName
        self.name = name
        self.callsign = callsign
    }
}

public struct DuplicateCluster: Equatable, Sendable {
    public var id: String
    public var sizeLabel: String
    public var eventDate: String
    public var members: [DuplicateParticipation]
}

private func normalizedLocation(_ location: String?) -> String? {
    let trimmed = location?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return trimmed.isEmpty ? nil : trimmed
}

/// Epoch millis off a wall `timestamp`, read as-is because both sides share the zone.
private func startedMillis(_ value: String?) -> Int64? {
    let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if raw.isEmpty { return nil }
    let date = raw.prefix(10).split(separator: "-").compactMap { Int($0) }
    if date.count != 3 { return nil }
    guard let timeRaw = formatTime(raw) else { return nil }
    let time = timeRaw.split(separator: ":").compactMap { Int($0) }
    if time.count != 2 { return nil }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    guard let day = calendar.date(from: DateComponents(
        calendar: calendar,
        timeZone: calendar.timeZone,
        year: date[0],
        month: date[1],
        day: date[2]
    )) else { return nil }
    let days = Int64(day.timeIntervalSince1970 / 86_400)
    return ((days * 24 + Int64(time[0])) * 60 + Int64(time[1])) * 60_000
}

private func matches(_ left: DuplicateParticipation, _ right: DuplicateParticipation) -> Bool {
    if left.eventId == right.eventId { return false }
    if left.responderId != right.responderId { return false }
    if left.eventDate != right.eventDate { return false }
    guard let leftPlace = normalizedLocation(left.location),
          let rightPlace = normalizedLocation(right.location),
          leftPlace == rightPlace else { return false }
    guard let leftStart = startedMillis(left.startedAt),
          let rightStart = startedMillis(right.startedAt) else { return false }
    return abs(leftStart - rightStart) <= WINDOW_MS
}

public func buildDuplicateClusters(_ sources: [DuplicateParticipation]) -> [DuplicateCluster] {
    var parent = Array(sources.indices)

    func find(_ index: Int) -> Int {
        var root = index
        while parent[root] != root { root = parent[root] }
        var walk = index
        while parent[walk] != root {
            let next = parent[walk]
            parent[walk] = root
            walk = next
        }
        return root
    }

    for i in sources.indices {
        if i + 1 >= sources.count { continue }
        for j in (i + 1)..<sources.count {
            if !matches(sources[i], sources[j]) { continue }
            let left = find(i)
            let right = find(j)
            if left != right { parent[left] = right }
        }
    }

    var groups: [Int: [Int]] = [:]
    for index in sources.indices {
        groups[find(index), default: []].append(index)
    }
    return groups.values
        .filter { $0.count >= 2 }
        .map { indices in
            let members = indices.map { sources[$0] }.sorted { ($0.startedAt ?? "") < ($1.startedAt ?? "") }
            return DuplicateCluster(
                id: members.map(\.eventId).sorted().joined(separator: ":"),
                sizeLabel: members.count >= 3 ? "משולש" : "כפול",
                eventDate: members.first?.eventDate ?? "",
                members: members
            )
        }
        .sorted {
            if $0.eventDate != $1.eventDate { return $0.eventDate > $1.eventDate }
            return $0.members.count > $1.members.count
        }
}

public func duplicateEventsReportRows(_ clusters: [DuplicateCluster]) -> [ReportRow] {
    clusters.flatMap { cluster in
        cluster.members.map { member in
            let place = placeDisplay(member.roadName, member.location)
            let responder = personDisplay(member.name, callsign: member.callsign)
            let typeName = member.eventTypeName?.trimmingCharacters(in: .whitespacesAndNewlines)
            return ReportRow(
                id: "\(cluster.id):\(member.eventId):\(member.responderId)",
                title: responder,
                subtitle: [
                    formatDate(member.eventDate),
                    formatTime(member.startedAt),
                    (typeName?.isEmpty == false) ? typeName : nil,
                ].compactMap { $0 }.joined(separator: " · "),
                detail: [
                    place.isEmpty ? nil : place,
                    policeEventLabel(member.policeEventId, isCancelled: member.isCancelled) == "—"
                        ? nil
                        : policeEventLabel(member.policeEventId, isCancelled: member.isCancelled),
                ].compactMap { $0 }.joined(separator: " · ").nilIfEmpty,
                eventId: member.eventId,
                stampLabel: cluster.sizeLabel,
                stampTone: .pending,
                searchText: [responder, member.policeEventId ?? "", place].joined(separator: " ")
            )
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
