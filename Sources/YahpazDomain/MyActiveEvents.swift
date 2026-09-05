import Foundation

public let MY_ACTIVE_EVENTS_EMPTY = "אין אירועים פעילים באחמו\"ש שלך"

public struct ActivePref: Equatable, Sendable {
    public var eventId: String
    public var kind: String

    public init(eventId: String, kind: String) {
        self.eventId = eventId
        self.kind = kind
    }
}

public func prefsAfterAddToMyActive(
    prefs: [ActivePref],
    eventId: String,
    alreadyAuto: Bool
) -> [ActivePref] {
    let others = prefs.filter { $0.eventId != eventId }
    return alreadyAuto ? others : others + [ActivePref(eventId: eventId, kind: "pin")]
}

public func prefsRestoringEvent(
    prefs: [ActivePref],
    eventId: String,
    previous: [ActivePref]
) -> [ActivePref] {
    prefs.filter { $0.eventId != eventId } + previous
}

public let MY_ACTIVE_EVENT_PINNED = "נוסף לאירועים הפעילים."
public let MY_ACTIVE_ADD = "הוספה לפעילים"
public let MY_ACTIVE_REMOVE = "הסרה"
public let MY_ACTIVE_REMOVE_LOCKED = "אירוע בהזנה — לא ניתן להסיר"
public let MY_ACTIVE_PREF_FAILED = "עדכון האירועים הפעילים נכשל. בדקו את החיבור ונסו שוב."
public let MY_ACTIVE_DRAG_TO_ACTIVE = "הוספה לפעילים, או לחיצה ארוכה וגרירה"
public let MY_ACTIVE_DROP_TO_ADD = "שחררו כאן להוספה לפעילים"
public let MY_ACTIVE_DRAG_TO_ADD = "גררו לכאן להוספה לפעילים"
public let MY_ACTIVE_REMOVE_HINT = "הסרה מהפעילים, או לחיצה ארוכה וגרירה לרשימה"
public let MY_ACTIVE_DROP_TO_REMOVE = "שחררו כאן להסרה מהפעילים"
public let MY_ACTIVE_DRAG_TO_REMOVE = "גררו לכאן להסרה מהפעילים"

/// Lead-owned events that stay on האירועים הפעילים שלי until done, cancelled, or הסרה.
public let AUTO_MY_ACTIVE_STATUSES: Set<EventStatus> = [.draft, .inProgress, .partial]

public func isAutoOnMyActive(isCancelled: Bool, status: EventStatus) -> Bool {
    !isCancelled && AUTO_MY_ACTIVE_STATUSES.contains(status)
}

public let EVENT_DELETE_TITLE = "מחיקת אירוע"
public let EVENT_DELETE_CONFIRM = "למחוק את האירוע? אין מתנדבים משובצים."
public let EVENT_DELETE_ACTION = "מחיקה"
public let EVENT_DELETED = "האירוע נמחק."
public let EVENT_DELETE_FAILED = "מחיקת האירוע נכשלה. בדקו את החיבור ונסו שוב."
public let EVENT_DELETE_OTHER_LEAD = "אין הרשאה למחוק אירוע שנוצר על ידי אחמ״ש אחר."

public func canAddEventToMyActive(isCancelled: Bool, status: EventStatus) -> Bool {
    _ = isCancelled
    _ = status
    return true
}

public func canRemoveFromMyActive(
    viewerId: String,
    shiftLeadId: String?,
    status: EventStatus,
    isCancelled: Bool
) -> Bool {
    !isLockedOnMyActive(viewerId: viewerId, shiftLeadId: shiftLeadId, status: status, isCancelled: isCancelled)
}

public func isLockedOnMyActive(
    viewerId: String,
    shiftLeadId: String?,
    status: EventStatus,
    isCancelled: Bool
) -> Bool {
    !isCancelled && status == .draft && shiftLeadId == viewerId
}

public func visibleMyActiveIds(
    lockedIds: [String],
    autoIds: [String],
    pinnedIds: Set<String>,
    hiddenIds: Set<String>
) -> [String] {
    var seen: [String] = []
    var seenSet = Set<String>()
    for id in lockedIds where seenSet.insert(id).inserted {
        seen.append(id)
    }
    for id in autoIds where !hiddenIds.contains(id) && seenSet.insert(id).inserted {
        seen.append(id)
    }
    for id in pinnedIds where seenSet.insert(id).inserted {
        seen.append(id)
    }
    return seen
}

public func canDeleteUnassignedEvent(
    canManageUnit: Bool,
    responderCount: Int,
    viewerIsAdmin: Bool,
    viewerId: String?,
    shiftLeadId: String?
) -> Bool {
    if !canManageUnit || responderCount != 0 { return false }
    if viewerIsAdmin { return true }
    return viewerId != nil && viewerId == shiftLeadId
}
