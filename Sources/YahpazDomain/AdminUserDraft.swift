import Foundation

/// Admin users on the phone. Mirrors Android `AdminUserDraft.kt` (and web minus
/// impersonation / Places addresses).
public let USERS_TITLE = "משתמשים"
public let INVITE_TITLE = "משתמש חדש"
public let USER_EDIT_TITLE = "עריכת משתמש"
public let USER_SAVE_LABEL = "שמירת משתמש"
public let USERS_SEARCH_PLACEHOLDER = "שם, או״ק, דוא״ל או סטטוס"

public let FIELD_FULL_NAME = "שם מלא"
public let FIELD_EMAIL = "דוא״ל"
public let FIELD_CALLSIGN = "או״ק"
public let FIELD_PHONE = "טלפון"
public let FIELD_VOLUNTEER_STATUS = "סטטוס מתנדב"
public let FIELD_ROLES = "תפקידים"
public let FIELD_VEHICLES = "רכבים"

public let OVERFLOW_EDIT = "עריכה"
public let OVERFLOW_DEACTIVATE = "השבתת משתמש"
public let OVERFLOW_REACTIVATE = "הפעלה מחדש"
public let OVERFLOW_DELETE = "מחיקת משתמש"
public let OVERFLOW_RESEND_INVITE = "שליחת הזמנה מחדש"
public let OVERFLOW_COPY_INVITE_LINK = "העתקת קישור הזמנה"

public let INVITE_IDENTITY_ERROR = "יש למלא שם מלא, דוא״ל ואו״ק."
public let INVITE_ROLE_ERROR = "יש לבחור לפחות תפקיד אחד."
public let INVITE_EMAIL_ERROR = "כתובת הדוא״ל אינה תקינה."
public let INVITE_PHONE_ERROR = "מספר הטלפון אינו תקין."
public let INVITE_SAVE_FAILED = "יצירת ההזמנה נכשלה. בדקו את החיבור ונסו שוב."
public let INVITE_SAVED = "ההזמנה נשלחה."
public let USER_CREATED = "משתמש נוצר בהצלחה"
public let USER_CREATED_COPIED = "משתמש נוצר בהצלחה וקישור ההזמנה הועתק."
public let USER_SAVED = "המשתמש נשמר"
public let USER_DELETED = "המשתמש נמחק"
public let SAVE_USER_FAILED = "שמירת המשתמש נכשלה. בדקו את החיבור ונסו שוב."
public let SAVE_ROLES_FAILED = "שמירת התפקידים נכשלה."
public let SET_ACTIVE_FAILED = "עדכון החשבון נכשל. נסו שוב."
public let DELETE_USER_FAILED = "מחיקת המשתמש נכשלה. בדקו את החיבור ונסו שוב."
public let RESEND_INVITE_FAILED = "שליחת ההזמנה מחדש נכשלה. נסו שוב."
public let COPY_INVITE_FAILED = "יצירת קישור ההזמנה נכשלה. נסו שוב."
public let INVITE_RESENT_COPIED = "ההזמנה נשלחה מחדש וקישור ההזמנה הועתק."
public let INVITE_LINK_COPIED = "קישור ההזמנה הועתק."
public let INVITE_LINK_COPY_FAILED = "נוצר קישור הזמנה, אך ההעתקה נכשלה. נסו שוב."

public let FORM_NAME_CALLSIGN_ERROR = "יש למלא שם מלא ואו״ק."
public let FORM_EMAIL_REQUIRED = "יש למלא דוא״ל."
public let FORM_EMAIL_INVALID = "יש להזין כתובת דוא״ל תקינה."
public let FORM_PHONE_ERROR = "יש להזין מספר טלפון בן 10 ספרות."
public let CANNOT_REMOVE_OWN_ADMIN = "לא ניתן להסיר מעצמך את תפקיד המנהל."
public let SUPER_ADMIN_LOCK_ERROR = "לא ניתן לערוך מנהל־על."
public let SUPER_ADMIN_CAPTION = "מנהל־על"
public let SELF_DELETE_ERROR = "לא ניתן למחוק את המשתמש המחובר כעת."
public let DELETE_USER_TITLE = "מחיקת משתמש"
public let DELETE_USER_BODY =
    "המשתמש יימחק לצמיתות מאימות וממערכת המשתמשים. לא ניתן לשחזר — רק להזמין מחדש. אם הוא אחמ״ש על אירועים או משמרות, המחיקה תיחסם."
public let DELETE_USER_ACTION = "מחיקה"
public let DEACTIVATE_USER_ACTION = "השבתה"
public let DEACTIVATE_USER_BODY = "הוא לא יוכל להתחבר, והנתונים ההיסטוריים יישמרו."

public let OTP_PHONE_REQUIRED = "יש להזין מספר נייד ישראלי תקין לפני הפעלת OTP."
public let OTP_LOGIN_ENABLED_TOAST = "OTP בכניסה הופעל"
public let OTP_LOGIN_DISABLED_TOAST = "OTP בכניסה כובה"
public let OTP_USERS_PAGE_ENABLED_TOAST = "OTP לניהול משתמשים הופעל"
public let OTP_USERS_PAGE_DISABLED_TOAST = "OTP לניהול משתמשים כובה"
public let OTP_ENABLE_LOGIN_TITLE = "להפעיל אימות SMS בכניסה למשתמש זה?"
public let OTP_ENABLE_USERS_PAGE_TITLE = "להפעיל אימות SMS לניהול משתמשים למשתמש זה?"
public let OTP_ENABLE_ACTION = "הפעלה"
public let OTP_SET_FAILED = "עדכון OTP נכשל. נסו שוב."

public let EMAIL_LOCKED_HINT = "לא ניתן לשנות דוא״ל לאחר יצירה."
public let EMAIL_INVITE_HINT = "נשלחת הזמנה לכתובת זו."
public let PHONE_HINT = "10 ספרות, למשל: 050-1234567"
public let ROLES_HINT = "בחירת תפקיד כוללת את התפקידים שמתחתיו."
public let INVITE_PENDING_LABEL = "ממתין להרשמה"
public let INACTIVE_ACCOUNT_LABEL = "מושבת"

public let ADMIN_SEGMENT_REPORTS_LABEL = "דוחות וסטטיסטיקות"

/// Roles an admin may hand out from the phone; מנהל־על stays a web-only grant.
public let INVITABLE_ROLES: [AppRole] = [.responder, .shiftLead, .admin]

public struct AdminVehicleDraft: Equatable, Sendable {
    public var key: String
    public var id: String?
    public var plateNumber: String
    public var model: String
    public var archived: Bool

    public init(
        key: String,
        id: String? = nil,
        plateNumber: String = "",
        model: String = "",
        archived: Bool = false
    ) {
        self.key = key
        self.id = id
        self.plateNumber = plateNumber
        self.model = model
        self.archived = archived
    }
}

public struct InviteDraft: Equatable, Sendable {
    public var id: String?
    public var fullName: String
    public var email: String
    public var callsign: String
    public var phone: String
    public var volunteerStatus: VolunteerStatus
    public var roles: [String]
    public var vehicles: [AdminVehicleDraft]

    public init(
        id: String? = nil,
        fullName: String = "",
        email: String = "",
        callsign: String = "",
        phone: String = "",
        volunteerStatus: VolunteerStatus = .default,
        roles: [String] = [AppRole.responder.rawValue],
        vehicles: [AdminVehicleDraft] = []
    ) {
        self.id = id
        self.fullName = fullName
        self.email = email
        self.callsign = callsign
        self.phone = phone
        self.volunteerStatus = volunteerStatus
        self.roles = roles
        self.vehicles = vehicles
    }
}

public struct InviteDraftErrors: Equatable, Sendable {
    public var fullName: String?
    public var email: String?
    public var callsign: String?
    public var phone: String?
    public var roles: String?
    public var form: String?

    public init(
        fullName: String? = nil,
        email: String? = nil,
        callsign: String? = nil,
        phone: String? = nil,
        roles: String? = nil,
        form: String? = nil
    ) {
        self.fullName = fullName
        self.email = email
        self.callsign = callsign
        self.phone = phone
        self.roles = roles
        self.form = form
    }

    public var isEmpty: Bool {
        fullName == nil && email == nil && callsign == nil && phone == nil && roles == nil && form == nil
    }

    public var formMessage: String? {
        if isEmpty { return nil }
        if let form { return form }
        if let email { return email }
        if let phone { return phone }
        if let roles { return roles }
        return FORM_NAME_CALLSIGN_ERROR
    }
}

public struct RoleSyncDiff: Equatable, Sendable {
    public var toAdd: [String]
    public var toRemove: [String]

    public init(toAdd: [String], toRemove: [String]) {
        self.toAdd = toAdd
        self.toRemove = toRemove
    }
}

public struct AdminUserSortKey: Equatable, Sendable {
    public var fullName: String
    public var active: Bool
    public var invitePending: Bool

    public init(fullName: String, active: Bool, invitePending: Bool) {
        self.fullName = fullName
        self.active = active
        self.invitePending = invitePending
    }
}

public struct AdminUserSearchInput: Equatable, Sendable {
    public var fullName: String
    public var callsign: String
    public var email: String
    public var volunteerStatus: String?
    public var availability: AvailabilityStatus
    public var availableFrom: String?
    public var active: Bool
    public var invitePending: Bool

    public init(
        fullName: String,
        callsign: String,
        email: String,
        volunteerStatus: String?,
        availability: AvailabilityStatus,
        availableFrom: String?,
        active: Bool = true,
        invitePending: Bool = false
    ) {
        self.fullName = fullName
        self.callsign = callsign
        self.email = email
        self.volunteerStatus = volunteerStatus
        self.availability = availability
        self.availableFrom = availableFrom
        self.active = active
        self.invitePending = invitePending
    }
}

/// Deliberately loose: the invite email is the real check, this only catches typos.
public func looksLikeEmail(_ value: String) -> Bool {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.contains(" ") { return false }
    guard let at = trimmed.firstIndex(of: "@") else { return false }
    let atOffset = trimmed.distance(from: trimmed.startIndex, to: at)
    if atOffset <= 0 || at != trimmed.lastIndex(of: "@") { return false }
    let domain = String(trimmed[trimmed.index(after: at)...])
    return domain.contains(".") && !domain.hasPrefix(".") && !domain.hasSuffix(".")
}

public func isValidPhone(_ raw: String?) -> Bool {
    phoneDigits(raw).count == 10
}

public func createUserEmailError(_ raw: String) -> String? {
    if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return nil }
    return looksLikeEmail(raw) ? nil : FORM_EMAIL_INVALID
}

public func canSubmitCreateUser(_ draft: InviteDraft) -> Bool {
    !draft.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && looksLikeEmail(draft.email)
        && !draft.callsign.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && isValidPhone(draft.phone)
}

public func validateInviteDraft(_ draft: InviteDraft) -> InviteDraftErrors {
    let email = draft.email.trimmingCharacters(in: .whitespacesAndNewlines)
    return InviteDraftErrors(
        fullName: draft.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? FORM_NAME_CALLSIGN_ERROR : nil,
        email: {
            if email.isEmpty { return FORM_EMAIL_REQUIRED }
            if !looksLikeEmail(email) { return FORM_EMAIL_INVALID }
            return nil
        }(),
        callsign: draft.callsign.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? FORM_NAME_CALLSIGN_ERROR : nil,
        phone: isValidPhone(draft.phone) ? nil : FORM_PHONE_ERROR,
        roles: draft.roles.isEmpty ? INVITE_ROLE_ERROR : nil,
        form: findDuplicatePlate(draft.vehicles.map(\.plateNumber)) != nil ? DUPLICATE_PLATE_ERROR : nil
    )
}

public func validateAdminUserDraft(
    _ draft: InviteDraft,
    actorUserId: String?,
    isSuperAdmin: Bool,
    existingRoles: [String]? = nil
) -> InviteDraftErrors {
    let rolesForLock = existingRoles ?? draft.roles
    let base: InviteDraftErrors
    if draft.id == nil {
        base = validateInviteDraft(draft)
    } else {
        base = InviteDraftErrors(
            fullName: draft.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? FORM_NAME_CALLSIGN_ERROR : nil,
            callsign: draft.callsign.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? FORM_NAME_CALLSIGN_ERROR : nil,
            phone: isValidPhone(draft.phone) ? nil : FORM_PHONE_ERROR,
            roles: draft.roles.isEmpty ? INVITE_ROLE_ERROR : nil,
            form: findDuplicatePlate(draft.vehicles.map(\.plateNumber)) != nil ? DUPLICATE_PLATE_ERROR : nil
        )
    }
    if !base.isEmpty { return base }
    if let draftId = draft.id, draftId == actorUserId, !draft.roles.contains(AppRole.admin.rawValue) {
        return InviteDraftErrors(
            fullName: base.fullName,
            email: base.email,
            callsign: base.callsign,
            phone: base.phone,
            roles: CANNOT_REMOVE_OWN_ADMIN,
            form: base.form
        )
    }
    if draft.id != nil, !canMutateAdminUser(actorIsSuperAdmin: isSuperAdmin, targetRoles: rolesForLock) {
        return InviteDraftErrors(
            fullName: base.fullName,
            email: base.email,
            callsign: base.callsign,
            phone: base.phone,
            roles: base.roles,
            form: SUPER_ADMIN_LOCK_ERROR
        )
    }
    return base
}

public func toggleInviteRole(_ roles: [String], role: String) -> [String] {
    roles.contains(role) ? roles.filter { $0 != role } : roles + [role]
}

public func setActiveActionLabel(next: Bool) -> String {
    next ? OVERFLOW_REACTIVATE : OVERFLOW_DEACTIVATE
}

public func setActiveConfirm(next: Bool, name: String) -> String {
    let who = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let display = who.isEmpty ? "המשתמש" : who
    if next {
        return "\(display) יוכל להתחבר לאפליקציה מחדש. להפעיל?"
    }
    return "להשבית את המשתמש \(display)?"
}

public func setActiveToast(next: Bool) -> String {
    next ? "החשבון הופעל." : "החשבון הושבת."
}

public func deactivateConfirmTitle(_ name: String) -> String {
    let who = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let display = who.isEmpty ? "המשתמש" : who
    return "להשבית את המשתמש \(display)?"
}

public func deleteUserConfirm(_ name: String) -> String {
    let who = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let display = who.isEmpty ? "המשתמש" : who
    return "למחוק את המשתמש \(display)?"
}

public func otpLoginActionLabel(enabled: Bool) -> String {
    enabled ? "כבה OTP בכניסה" : "הפעל OTP בכניסה"
}

public func otpUsersPageActionLabel(enabled: Bool) -> String {
    enabled ? "כבה OTP לניהול משתמשים" : "הפעל OTP לניהול משתמשים"
}

public func otpUserLabel(otpLoginEnabled: Bool, otpUsersPageEnabled: Bool) -> String? {
    if otpLoginEnabled && otpUsersPageEnabled { return "שניהם" }
    if otpLoginEnabled { return "כניסה" }
    if otpUsersPageEnabled { return "משתמשים" }
    return nil
}

public func otpFlagToast(kind: String, enabled: Bool) -> String {
    if kind == "users_page" {
        return enabled ? OTP_USERS_PAGE_ENABLED_TOAST : OTP_USERS_PAGE_DISABLED_TOAST
    }
    return enabled ? OTP_LOGIN_ENABLED_TOAST : OTP_LOGIN_DISABLED_TOAST
}

public func canToggleUsersPageOtp(_ roles: [String]) -> Bool {
    roles.contains(AppRole.admin.rawValue)
}

public func hasSuperAdminRole(_ roles: [String]) -> Bool {
    roles.contains(AppRole.superAdmin.rawValue)
}

public func canMutateAdminUser(actorIsSuperAdmin: Bool, targetRoles: [String]) -> Bool {
    actorIsSuperAdmin || !hasSuperAdminRole(targetRoles)
}

public func isInvitePending(active: Bool, invitePending: Bool) -> Bool {
    active && invitePending
}

public func hasAvailability(active: Bool, invitePending: Bool) -> Bool {
    !isInvitePending(active: active, invitePending: invitePending)
}

public func compareAdminUsers(_ a: AdminUserSortKey, _ b: AdminUserSortKey) -> Int {
    func rank(_ user: AdminUserSortKey) -> Int {
        if isInvitePending(active: user.active, invitePending: user.invitePending) { return 2 }
        if !user.active { return 1 }
        return 0
    }
    let byRank = rank(a) - rank(b)
    if byRank != 0 { return byRank }
    if a.fullName == b.fullName { return 0 }
    return a.fullName < b.fullName ? -1 : 1
}

public func adminUserMatchesQuery(_ row: AdminUserSearchInput, query: String, today: String) -> Bool {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return true }
    var fields: [String?] = [
        row.fullName,
        row.callsign,
        row.email,
        volunteerStatusLabel(row.volunteerStatus),
    ]
    if hasAvailability(active: row.active, invitePending: row.invitePending) {
        fields.append(availabilitySearchLabel(row.availability, availableFrom: row.availableFrom, today: today))
    }
    return fieldsMatchQuery(fields, query: trimmed)
}

public func addressKindLabel(_ kind: String?, customLabel: String? = nil) -> String {
    switch kind {
    case "home":
        return "בית"
    case "work":
        return "עבודה"
    case "other":
        let custom = customLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return custom.isEmpty ? "אחר" : custom
    default:
        let custom = customLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return custom.isEmpty ? "כתובת" : custom
    }
}

private let PROTECTED_ROLES: Set<String> = [AppRole.superAdmin.rawValue]

public func syncUserRolesDiff(current: [String], next: [String]) -> RoleSyncDiff {
    let currentSet = Set(current)
    let nextAssignable = next.filter { !PROTECTED_ROLES.contains($0) }
    let nextSet = Set(nextAssignable)
    return RoleSyncDiff(
        toAdd: nextAssignable.filter { !currentSet.contains($0) },
        toRemove: current.filter { !PROTECTED_ROLES.contains($0) && !nextSet.contains($0) }
    )
}

public func otpEnableConfirmBody(phone: String?) -> String {
    "יישלח קוד SMS ל־\(formatPhone(phone)) כאשר יידרש אימות."
}

public func adminUsersCountLabel(_ count: Int) -> String {
    "\(count) משתמשים"
}
