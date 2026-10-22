import Foundation

public let EVENT_EDIT_LOCK_MS: Int64 = 7 * 24 * 60 * 60 * 1000
public let EVENT_EDIT_LOCKED_TOOLTIP = "לא ניתן לערוך אירוע שנוצר לפני מעל ל-7 ימים"

public func isEventEditAgeLocked(
    createdAt: String?,
    roles: [String],
    nowMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
) -> Bool {
    if roles.contains("admin") || roles.contains("super_admin") { return false }
    guard let createdMs = parseInstantMs(createdAt) else { return false }
    return nowMs - createdMs > EVENT_EDIT_LOCK_MS
}
