import Foundation

public enum ShiftStatus: String, Codable, Hashable, Sendable {
    case draft
    case inProgress = "in_progress"
    case closed
}

public func shiftStamp(_ status: ShiftStatus) -> StampDescriptor {
    switch status {
    case .draft: return StampDescriptor(label: "טיוטה", tone: .draft)
    case .inProgress: return StampDescriptor(label: "פתוחה", tone: .pending)
    case .closed: return StampDescriptor(label: "נסגרה", tone: .done)
    }
}

public func isShiftFuture(_ shiftDate: String, today: String) -> Bool {
    shiftDate > today
}

public func isShiftPendingLog(
    _ shiftDate: String,
    odometerStart: Double?,
    odometerEnd: Double?,
    today: String
) -> Bool {
    !isShiftFuture(shiftDate, today: today) && (odometerStart == nil || odometerEnd == nil)
}

public struct MineShiftItem: Equatable, Identifiable, Sendable {
    public var id: String
    public var date: String
    public var odometerStart: Double?
    public var odometerEnd: Double?

    public init(id: String, date: String, odometerStart: Double?, odometerEnd: Double?) {
        self.id = id
        self.date = date
        self.odometerStart = odometerStart
        self.odometerEnd = odometerEnd
    }
}

public struct MineShiftSections<Item: Sendable>: Sendable {
    public var pending: [Item]
    public var future: [Item]
    public var logged: [Item]
    public var hasMoreLogged: Bool

    public init(pending: [Item], future: [Item], logged: [Item], hasMoreLogged: Bool) {
        self.pending = pending
        self.future = future
        self.logged = logged
        self.hasMoreLogged = hasMoreLogged
    }
}

public func partitionMineShifts(
    _ items: [MineShiftItem],
    today: String,
    windowsLoaded: Int
) -> MineShiftSections<MineShiftItem> {
    let start = loggedWindowStart(today: today, windowsLoaded: windowsLoaded)
    var pending: [MineShiftItem] = []
    var future: [MineShiftItem] = []
    var logged: [MineShiftItem] = []
    var hasMoreLogged = false

    for item in items {
        if isShiftFuture(item.date, today: today) {
            future.append(item)
            continue
        }
        if isShiftPendingLog(item.date, odometerStart: item.odometerStart, odometerEnd: item.odometerEnd, today: today) {
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
    future.sort { $0.date < $1.date }
    logged.sort { $0.date > $1.date }
    return MineShiftSections(pending: pending, future: future, logged: logged, hasMoreLogged: hasMoreLogged)
}

public let MINE_SHIFTS_PENDING_EMPTY = "מברוק! אין לך עוד משמרות לתעד כרגע"
public let MINE_SHIFTS_LOGGED_EMPTY = "אין משמרות שתועדו בתקופה זו"
public let MINE_SHIFTS_NONE = "אין משמרות עדיין"
