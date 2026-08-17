import Foundation

public let MINE_PENDING_TAB_LABEL = "ממתינים לתיעוד"
public let MINE_LOGGED_TAB_LABEL = "תועדו"
public let MINE_PENDING_EMPTY_TITLE = "אין אירועים שממתינים לתיעוד."
public let MINE_PENDING_EMPTY_CAPTION = "אירוע חדש יופיע כאן כשישויך אליך."
public let MINE_PENDING_EMPTY_VIEW_LOGGED = "לצפייה באירועים שתועדו"
public let MINE_LOGGED_EMPTY_TITLE = "אין אירועים שתועדו בתקופה זו"
public let MINE_LOGGED_WINDOW_DAYS = 30

public func openMineSummary(count: Int, ready: Bool) -> String {
    if !ready { return "טוען את הדיווחים שלך…" }
    if count == 0 { return "אין אירועים שממתינים לתיעוד." }
    if count == 1 { return "יש לך אירוע אחד לתעד." }
    if count == 2 { return "יש לך שני אירועים לתעד." }
    return "יש לך \(count) אירועים לתעד."
}

public func minePendingTabLabel(count: Int) -> String {
    count > 0 ? "\(MINE_PENDING_TAB_LABEL) \(count)" : MINE_PENDING_TAB_LABEL
}

public func mineLoggedNoResultsTitle(query: String) -> String {
    "אין אירועים שתועדו התואמים ל־“\(query)”"
}

public struct MineSearchFields: Equatable, Sendable {
    public var policeEventId: String?
    public var roadName: String?
    public var location: String?

    public init(policeEventId: String? = nil, roadName: String? = nil, location: String? = nil) {
        self.policeEventId = policeEventId
        self.roadName = roadName
        self.location = location
    }
}

public func mineEventMatchesQuery(_ event: MineSearchFields, query: String) -> Bool {
    fieldsMatchQuery([event.policeEventId, event.roadName, event.location], query: query)
}

public struct MineListEvent: Equatable, Identifiable, Sendable {
    public var id: String
    public var date: String
    public var participation: ParticipationStatus

    public init(id: String, date: String, participation: ParticipationStatus) {
        self.id = id
        self.date = date
        self.participation = participation
    }
}

public struct MineListSections<Item: Sendable>: Sendable {
    public var pending: [Item]
    public var logged: [Item]
    public var hasMoreLogged: Bool

    public init(pending: [Item], logged: [Item], hasMoreLogged: Bool) {
        self.pending = pending
        self.logged = logged
        self.hasMoreLogged = hasMoreLogged
    }
}

public func partitionMineList(
    _ items: [MineListEvent],
    today: String,
    windowsLoaded: Int
) -> MineListSections<MineListEvent> {
    let start = loggedWindowStart(today: today, windowsLoaded: windowsLoaded)
    var pending: [MineListEvent] = []
    var logged: [MineListEvent] = []
    var hasMoreLogged = false

    for item in items {
        if item.participation != .done {
            pending.append(item)
            continue
        }
        if item.date >= start && item.date <= today {
            logged.append(item)
        } else if item.date < start {
            hasMoreLogged = true
        }
    }

    pending.sort { $0.date > $1.date }
    logged.sort { $0.date > $1.date }
    return MineListSections(pending: pending, logged: logged, hasMoreLogged: hasMoreLogged)
}

public func addCalendarDays(ymd: String, days: Int) -> String {
    let parts = ymd.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else { return ymd }
    var components = DateComponents()
    components.year = parts[0]
    components.month = parts[1]
    components.day = parts[2] + days
    let calendar = Calendar(identifier: .gregorian)
    guard let date = calendar.date(from: DateComponents(
        calendar: Calendar(identifier: .gregorian),
        timeZone: TimeZone(secondsFromGMT: 0),
        year: parts[0],
        month: parts[1],
        day: parts[2]
    ))?.addingTimeInterval(TimeInterval(days * 86_400)) else {
        return ymd
    }
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
}

public func loggedWindowStart(today: String, windowsLoaded: Int) -> String {
    let windows = max(1, windowsLoaded)
    return addCalendarDays(ymd: today, days: -(windows * MINE_LOGGED_WINDOW_DAYS))
}

public func shiftGroupPendingCaption(count: Int) -> String {
    count == 1 ? "אירוע אחד לתעד" : "\(count) לתעד"
}

public func shiftGroupShouldStartOpen(pendingCount: Int) -> Bool {
    pendingCount > 0
}

public func fuelNoteNeeded(openCount: Int) -> Bool {
    openCount >= 3
}

public let FUEL_NOTE = "שימו לב! אירועים שלא תועדו במלואם לא נכללים בהחזר הדלק הרבעוני"

private let enToHe: [Character: Character] = [
    "q": "/", "w": "'", "e": "ק", "r": "ר", "t": "א", "y": "ט", "u": "ו",
    "i": "ן", "o": "ם", "p": "פ", "a": "ש", "s": "ד", "d": "ג", "f": "כ",
    "g": "ע", "h": "י", "j": "ח", "k": "ל", "l": "ך", "z": "ז", "x": "ס",
    "c": "ב", "v": "ה", "b": "נ", "n": "מ", "m": "צ",
]

func searchQueryVariants(_ query: String) -> [String] {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return [] }
    let mapped = String(trimmed.map { ch in
        enToHe[Character(ch.lowercased())] ?? ch
    })
    return mapped == trimmed ? [trimmed] : [trimmed, mapped]
}

func fieldsMatchQuery(_ fields: [String?], query: String) -> Bool {
    fields.contains { field in
        guard let field else { return false }
        return textIncludesQuery(field, query: query)
    }
}

func textIncludesQuery(_ haystack: String, query: String) -> Bool {
    let variants = searchQueryVariants(query)
    if variants.isEmpty { return true }
    let hay = haystack.lowercased()
    return variants.contains { hay.contains($0.lowercased()) }
}
