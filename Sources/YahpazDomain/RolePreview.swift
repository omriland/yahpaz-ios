import Foundation

/// Roles a Super Admin can preview. Matches web `rolePreview.ts`.
public let PREVIEWABLE_ROLES: [AppRole] = [.responder, .shiftLead, .admin]

public let VIEW_AS_USER_LABEL = "צפייה כמשתמש"
public let VIEW_AS_ROLE_LABEL = "צפייה בתפקיד אחר"
public let STOP_ROLE_PREVIEW_LABEL = "חזרה לתפקיד שלי"
public let STOP_IMPERSONATION_LABEL = "חזרה לחשבון שלי"
public let ROLE_PREVIEW_STARTED = "נכנסתם למצב צפייה בתפקיד אחר."
public let ROLE_PREVIEW_STOPPED = "חזרת בהצלחה לתפקיד שלך."
public let IMPERSONATION_STARTED = "נכנסתם למצב צפייה כמשתמש."
public let IMPERSONATION_STOPPED = "חזרתם לחשבון שלכם."
public let IMPERSONATION_ALREADY = "כבר במצב צפייה כמשתמש אחר."
public let IMPERSONATION_OPEN_FAILED = "פתיחת הצפייה נכשלה. נסו שוב."
public let IMPERSONATION_NONE = "אין צפייה פעילה לשחזור."
public let IMPERSONATION_RESTORE_FAILED = "השחזור נכשל — התחברו מחדש."
public let IMPERSONATION_LOAD_FAILED = "טעינת המשתמשים נכשלה."
public let IMPERSONATION_EMPTY = "לא נמצאו משתמשים תואמים."
public let IMPERSONATION_AVAILABILITY_LOCKED = "צפייה כמשתמש — לא ניתן לשנות זמינות."
public let ROLE_PREVIEW_HINT = "תראו את הניווט כפי שמופיע בתפקיד שנבחר."
public let IMPERSONATION_HINT = "תראו את המערכת בדיוק כמו המשתמש שנבחר — כולל שמירות."

public func parseRolePreviewRole(_ raw: String?) -> AppRole? {
    PREVIEWABLE_ROLES.first { $0.rawValue == raw }
}

public func canStartRolePreview(
    actualRoles: [String],
    impersonating: Bool,
    previewing: Bool
) -> Bool {
    hasSuperAdminRole(actualRoles) && !impersonating && !previewing
}

public func canStartImpersonation(actualRoles: [String], impersonating: Bool) -> Bool {
    hasSuperAdminRole(actualRoles) && !impersonating
}

public func effectiveRoles(_ actualRoles: [String], previewRole: AppRole?) -> [String] {
    guard let previewRole else { return actualRoles }
    return [previewRole.rawValue]
}

public func rolePreviewLabel(_ role: AppRole) -> String {
    roleLabel(role)
}

public func rolePreviewBannerText(_ role: AppRole) -> String {
    "צופה כתפקיד \(rolePreviewLabel(role))"
}

public func impersonationBannerText(fullName: String, callsign: String) -> String {
    "צופה כ־\(fullName) · או״ק \(callsign)"
}
