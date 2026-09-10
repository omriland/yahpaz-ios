import Foundation

public enum AppRole: String, Sendable, Hashable, CaseIterable {
    case responder
    case shiftLead = "shift_lead"
    case admin
    case superAdmin = "super_admin"

    public static func fromRaw(_ raw: String?) -> AppRole? {
        guard let raw else { return nil }
        return AppRole(rawValue: raw)
    }
}

public func roleSet(_ roles: [String]) -> Set<AppRole> {
    Set(roles.compactMap { AppRole.fromRaw($0) })
}

public func managesUnit(_ roles: [String]) -> Bool {
    let s = roleSet(roles)
    return s.contains(.admin) || s.contains(.shiftLead) || s.contains(.superAdmin)
}

public func isAdmin(_ roles: [String]) -> Bool {
    let s = roleSet(roles)
    return s.contains(.admin) || s.contains(.superAdmin)
}

public func isResponder(_ roles: [String]) -> Bool {
    let s = roleSet(roles)
    return s.contains(.responder) || managesUnit(roles)
}

private let ROLE_LABELS: [AppRole: String] = [
    .superAdmin: "מנהל־על",
    .admin: "מנהל",
    .shiftLead: "אחמ״ש",
    .responder: "מתנדב",
]

/// Rank order matches the web: later entries win.
private let ROLE_RANK: [AppRole] = [.responder, .shiftLead, .admin, .superAdmin]

public func roleLabel(_ role: AppRole) -> String {
    ROLE_LABELS[role] ?? role.rawValue
}

public func highestRole(_ roles: [String]) -> AppRole? {
    let s = roleSet(roles)
    return ROLE_RANK.last { s.contains($0) }
}

public func highestRoleLabel(_ roles: [String]) -> String? {
    guard let role = highestRole(roles) else { return nil }
    return roleLabel(role)
}

public func roleLabels(_ roles: [String]) -> [String] {
    let s = roleSet(roles)
    return ROLE_RANK.reversed().filter { s.contains($0) }.map { roleLabel($0) }
}

public let TOOLS_TAB_LEAD_LABEL = "כלים"
public let TOOLS_TAB_ADMIN_LABEL = "ניהול"

public func toolsTabLabel(_ roles: [String]) -> String {
    isAdmin(roles) ? TOOLS_TAB_ADMIN_LABEL : TOOLS_TAB_LEAD_LABEL
}

private let ASSIGNABLE_RANK: [AppRole] = [.responder, .shiftLead, .admin]

public func impliedAssignableRoles(_ role: AppRole) -> [String] {
    guard let index = ASSIGNABLE_RANK.firstIndex(of: role) else { return [] }
    return ASSIGNABLE_RANK.enumerated()
        .filter { $0.offset <= index }
        .reversed()
        .map { $0.element.rawValue }
}

public func withImpliedAssignableRoles(_ roles: [String]) -> [String] {
    guard let highest = ASSIGNABLE_RANK.last(where: { roles.contains($0.rawValue) }) else {
        return []
    }
    return impliedAssignableRoles(highest)
}

public func isAssignableRoleLocked(_ roles: [String], role: AppRole) -> Bool {
    guard let roleIndex = ASSIGNABLE_RANK.firstIndex(of: role) else { return false }
    return ASSIGNABLE_RANK.enumerated().contains { index, candidate in
        index > roleIndex && roles.contains(candidate.rawValue)
    }
}

public func toggleAssignableRole(_ current: [String], role: AppRole, checked: Bool) -> [String] {
    if checked {
        let next = Set(withImpliedAssignableRoles(current) + impliedAssignableRoles(role))
        let highest = ASSIGNABLE_RANK.last { next.contains($0.rawValue) } ?? role
        return impliedAssignableRoles(highest)
    }
    return withImpliedAssignableRoles(current).filter { $0 != role.rawValue }
}
