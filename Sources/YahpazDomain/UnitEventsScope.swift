import Foundation

public let SHOW_OTHERS_CREATED_EVENTS_LABEL = "הצג אירועים שנוצרו על ידי אחרים"

/// אחמ״ש only — not admin, not SuperAdmin. Those roles keep the full unit list.
public func shouldFilterUnitEventsToOwnCreated(_ roles: [String]) -> Bool {
    let s = roleSet(roles)
    return s.contains(.shiftLead) && !s.contains(.admin) && !s.contains(.superAdmin)
}

/// `shift_lead_id` to push into the unit-list query, or null for everyone.
public func unitEventsCreatedByFilter(
    roles: [String],
    showOthersCreated: Bool,
    userId: String?
) -> String? {
    if !shouldFilterUnitEventsToOwnCreated(roles) { return nil }
    if showOthersCreated { return nil }
    return userId
}
