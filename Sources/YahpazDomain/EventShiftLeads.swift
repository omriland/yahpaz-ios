import Foundation

public let MAIN_LEAD_LABEL = "אחמ״ש ראשי"
public let MAIN_LEAD_LABEL_SHORT = "אחמ״ש"
public let SECONDARY_LEAD_LABEL = "אחמ״ש משני"
public let SECONDARY_LEAD_ADD = "הוספת אחמ״ש משני"
public let SECONDARY_LEAD_REMOVE = "הסרת אחמ״ש משני"
public let SECONDARY_LEAD_LOCKED_HINT = "נוסף אוטומטית בעריכה — לא ניתן להסיר"
public let SECONDARY_LEAD_PICKER_EMPTY = "אין אחמ״שים פעילים להוספה."
public let SECONDARY_LEAD_PICKER_NONE = "לא נמצאו אחמ״שים"
public let MAIN_LEAD_LOCKED_HINT = "רק מנהל יכול להחליף אחמ״ש ראשי לאחר יצירת האירוע."

public struct SecondaryLead: Equatable, Sendable, Identifiable {
    public var userId: String
    public var locked: Bool
    public var fullName: String
    public var callsign: String
    public var addedAt: String?

    public var id: String { userId }

    public init(
        userId: String,
        locked: Bool = false,
        fullName: String = "",
        callsign: String = "",
        addedAt: String? = nil
    ) {
        self.userId = userId
        self.locked = locked
        self.fullName = fullName
        self.callsign = callsign
        self.addedAt = addedAt
    }

    public var display: String { formatLeadPerson(fullName, callsign: callsign) }

    public var namePair: (String?, String?) { (fullName, callsign) }
}

public func canManageSecondaryLeads(_ roles: [String]) -> Bool {
    let s = roleSet(roles)
    return s.contains(.shiftLead) || s.contains(.admin) || s.contains(.superAdmin)
}

public func canChangeEventMainLead(
    roles: [String],
    eventExists: Bool,
    viewerIsCurrentMain: Bool,
    hasSecondaries: Bool
) -> Bool {
    if isAdmin(roles) { return true }
    if !roleSet(roles).contains(.shiftLead) { return false }
    if !eventExists { return true }
    return viewerIsCurrentMain && !hasSecondaries
}

public func canRemoveSecondaryLead(roles: [String], locked: Bool) -> Bool {
    !locked && canManageSecondaryLeads(roles)
}

public func shouldAutoLockSecondary(
    viewerId: String?,
    mainLeadId: String?,
    persistedFieldChange: Bool,
    viewerHasShiftLead: Bool
) -> Bool {
    if !persistedFieldChange || !viewerHasShiftLead { return false }
    let viewer = viewerId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let main = mainLeadId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return !viewer.isEmpty && !main.isEmpty && viewer != main
}

public func createTimeCreatorSecondary(creatorId: String, mainLeadId: String) -> SecondaryLead? {
    let creator = creatorId.trimmingCharacters(in: .whitespacesAndNewlines)
    let main = mainLeadId.trimmingCharacters(in: .whitespacesAndNewlines)
    if creator.isEmpty || main.isEmpty || creator == main { return nil }
    return SecondaryLead(userId: creator, locked: false)
}

public struct MainLeadReassignment: Equatable, Sendable {
    public var mainId: String
    public var secondaries: [SecondaryLead]

    public init(mainId: String, secondaries: [SecondaryLead]) {
        self.mainId = mainId
        self.secondaries = secondaries
    }
}

public func reassignMainLeads(
    previousMainId: String,
    nextMainId: String,
    previousMainName: String,
    previousMainCallsign: String,
    secondaries: [SecondaryLead],
    previousMainLocked: Bool = false
) -> MainLeadReassignment {
    let previous = previousMainId.trimmingCharacters(in: .whitespacesAndNewlines)
    let next = nextMainId.trimmingCharacters(in: .whitespacesAndNewlines)
    if next.isEmpty || next == previous {
        return MainLeadReassignment(mainId: previous, secondaries: secondaries)
    }
    let kept = secondaries.filter { $0.userId != next && $0.userId != previous }
    let already = secondaries.first(where: { $0.userId == previous })
    let demoted: SecondaryLead
    if var found = already {
        found.locked = found.locked || previousMainLocked
        demoted = found
    } else {
        demoted = SecondaryLead(
            userId: previous,
            locked: previousMainLocked,
            fullName: previousMainName,
            callsign: previousMainCallsign
        )
    }
    return MainLeadReassignment(mainId: next, secondaries: kept + [demoted])
}

public func filterShiftLeadPicker(
    people: [AssignableProfile],
    excludeIds: [String],
    query: String
) -> [AssignableProfile] {
    let excluded = Set(excludeIds)
    return filterAssignableProfiles(people.filter { !excluded.contains($0.id) }, query: query)
}

public func eventLeadFieldLabel(hasSecondaries: Bool) -> String {
    hasSecondaries ? MAIN_LEAD_LABEL : MAIN_LEAD_LABEL_SHORT
}

public func formatLeadPerson(_ fullName: String?, callsign: String?) -> String {
    [fullName, callsign].compactMap { value -> String? in
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }.joined(separator: " · ")
}

public func formatLeadsCaption(
    mainFullName: String?,
    mainCallsign: String?,
    secondaries: [(String?, String?)] = []
) -> String {
    var parts: [String] = []
    let main = formatLeadPerson(mainFullName, callsign: mainCallsign)
    if !main.isEmpty { parts.append(main) }
    for pair in secondaries {
        let text = formatLeadPerson(pair.0, callsign: pair.1)
        if !text.isEmpty { parts.append(text) }
    }
    return parts.joined(separator: " · ")
}

/// Unit lists: main `שם · או״ק` only, plus ` +N` when secondaries exist.
public func formatListLeadCaption(
    mainFullName: String?,
    mainCallsign: String?,
    secondaries: [(String?, String?)] = []
) -> String {
    let main = formatLeadPerson(mainFullName, callsign: mainCallsign)
    if main.isEmpty { return "" }
    let count = secondaries.count
    return count > 0 ? "\(main) +\(count)" : main
}

public func eventLeadsCaption(
    origin: String?,
    mainFullName: String?,
    mainCallsign: String?,
    secondaries: [(String?, String?)] = []
) -> String {
    if origin == "shift" { return "" }
    return formatListLeadCaption(
        mainFullName: mainFullName,
        mainCallsign: mainCallsign,
        secondaries: secondaries
    )
}
