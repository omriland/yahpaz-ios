import Foundation
import YahpazDomain

struct ImpersonationStash: Equatable, Sendable {
    var actorAccessToken: String
    var actorRefreshToken: String
    var actorUserId: String
    var targetUserId: String
    var targetFullName: String
    var targetCallsign: String
}

enum ViewAsStore {
    private static let suiteName = "yahpaz_view_as"
    private static let roleKey = "role"
    private static let actorAccessKey = "actor_access"
    private static let actorRefreshKey = "actor_refresh"
    private static let actorIdKey = "actor_id"
    private static let targetIdKey = "target_id"
    private static let targetNameKey = "target_name"
    private static let targetCallsignKey = "target_callsign"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    static func rolePreviewRaw() -> String? {
        defaults.string(forKey: roleKey)
    }

    static func writeRolePreview(_ role: String) {
        defaults.set(role, forKey: roleKey)
    }

    static func clearRolePreview() {
        defaults.removeObject(forKey: roleKey)
    }

    static func readImpersonation() -> ImpersonationStash? {
        let access = defaults.string(forKey: actorAccessKey) ?? ""
        let refresh = defaults.string(forKey: actorRefreshKey) ?? ""
        let actorId = defaults.string(forKey: actorIdKey) ?? ""
        let targetId = defaults.string(forKey: targetIdKey) ?? ""
        let name = defaults.string(forKey: targetNameKey) ?? ""
        let callsign = defaults.string(forKey: targetCallsignKey) ?? ""
        if access.isEmpty || refresh.isEmpty || actorId.isEmpty || targetId.isEmpty { return nil }
        return ImpersonationStash(
            actorAccessToken: access,
            actorRefreshToken: refresh,
            actorUserId: actorId,
            targetUserId: targetId,
            targetFullName: name,
            targetCallsign: callsign
        )
    }

    static func writeImpersonation(_ stash: ImpersonationStash) {
        defaults.set(stash.actorAccessToken, forKey: actorAccessKey)
        defaults.set(stash.actorRefreshToken, forKey: actorRefreshKey)
        defaults.set(stash.actorUserId, forKey: actorIdKey)
        defaults.set(stash.targetUserId, forKey: targetIdKey)
        defaults.set(stash.targetFullName, forKey: targetNameKey)
        defaults.set(stash.targetCallsign, forKey: targetCallsignKey)
    }

    static func clearImpersonation() {
        defaults.removeObject(forKey: actorAccessKey)
        defaults.removeObject(forKey: actorRefreshKey)
        defaults.removeObject(forKey: actorIdKey)
        defaults.removeObject(forKey: targetIdKey)
        defaults.removeObject(forKey: targetNameKey)
        defaults.removeObject(forKey: targetCallsignKey)
    }

    static func isImpersonating() -> Bool { readImpersonation() != nil }

    static func isRolePreviewing() -> Bool { parseRolePreviewRole(rolePreviewRaw()) != nil }

    static func clearAll() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults.removeObject(forKey: roleKey)
        clearImpersonation()
    }
}
