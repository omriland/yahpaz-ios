import Foundation

public struct ImpersonationTarget: Equatable, Sendable {
    public var id: String
    public var active: Bool
    public var roles: [String]

    public init(id: String, active: Bool, roles: [String]) {
        self.id = id
        self.active = active
        self.roles = roles
    }
}

/// Client rules for who a Super Admin may become. Matches web `impersonationEligibility.ts`.
public func canImpersonateTarget(actorUserId: String?, target: ImpersonationTarget) -> Bool {
    guard let actorUserId, !actorUserId.isEmpty else { return false }
    if !target.active { return false }
    if target.id == actorUserId { return false }
    if hasSuperAdminRole(target.roles) { return false }
    return true
}
