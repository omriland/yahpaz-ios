import XCTest
@testable import YahpazDomain

final class AdminUserDraftTests: XCTestCase {
    private let valid = InviteDraft(
        fullName: "דנה כהן",
        email: "dana@yahpz.com",
        callsign: "112",
        phone: "0501234567",
        roles: ["responder"]
    )

    func testWebCopyIsUsedForTitlesSaveOverflowAndOtp() {
        XCTAssertEqual(USERS_TITLE, "משתמשים")
        XCTAssertEqual(INVITE_TITLE, "משתמש חדש")
        XCTAssertEqual(USER_EDIT_TITLE, "עריכת משתמש")
        XCTAssertEqual(USER_SAVE_LABEL, "שמירת משתמש")
        XCTAssertEqual(OVERFLOW_EDIT, "עריכה")
        XCTAssertEqual(OVERFLOW_DEACTIVATE, "השבתת משתמש")
        XCTAssertEqual(OVERFLOW_REACTIVATE, "הפעלה מחדש")
        XCTAssertEqual(OVERFLOW_DELETE, "מחיקת משתמש")
        XCTAssertEqual(OVERFLOW_RESEND_INVITE, "שליחת הזמנה מחדש")
        XCTAssertEqual(OVERFLOW_COPY_INVITE_LINK, "העתקת קישור הזמנה")
        XCTAssertEqual(otpLoginActionLabel(enabled: true), "כבה OTP בכניסה")
        XCTAssertEqual(otpLoginActionLabel(enabled: false), "הפעל OTP בכניסה")
        XCTAssertEqual(otpUsersPageActionLabel(enabled: true), "כבה OTP לניהול משתמשים")
        XCTAssertEqual(otpUsersPageActionLabel(enabled: false), "הפעל OTP לניהול משתמשים")
        XCTAssertEqual(roleLabel(.admin), "מנהל")
        XCTAssertEqual(roleLabel(.shiftLead), "אחמ״ש")
        XCTAssertEqual(roleLabel(.responder), "מתנדב")
        XCTAssertEqual(FIELD_FULL_NAME, "שם מלא")
        XCTAssertEqual(FIELD_EMAIL, "דוא״ל")
        XCTAssertEqual(FIELD_CALLSIGN, "או״ק")
        XCTAssertEqual(FIELD_PHONE, "טלפון")
        XCTAssertEqual(FIELD_VOLUNTEER_STATUS, "סטטוס מתנדב")
        XCTAssertEqual(FIELD_ROLES, "תפקידים")
        XCTAssertEqual(FIELD_VEHICLES, "רכבים")
    }

    func testACompleteDraftPasses() {
        XCTAssertTrue(validateInviteDraft(valid).isEmpty)
        XCTAssertNil(validateInviteDraft(valid).formMessage)
        XCTAssertTrue(canSubmitCreateUser(valid))
    }

    func testNameEmailCallsignAndA10DigitPhoneAreAllRequired() {
        var draft = valid
        draft.fullName = "  "
        XCTAssertEqual(validateInviteDraft(draft).formMessage, FORM_NAME_CALLSIGN_ERROR)
        draft = valid
        draft.email = ""
        XCTAssertEqual(validateInviteDraft(draft).formMessage, FORM_EMAIL_REQUIRED)
        draft = valid
        draft.callsign = ""
        XCTAssertEqual(validateInviteDraft(draft).formMessage, FORM_NAME_CALLSIGN_ERROR)
        draft = valid
        draft.phone = ""
        XCTAssertEqual(validateInviteDraft(draft).formMessage, FORM_PHONE_ERROR)
        draft = valid
        draft.phone = "050-123"
        XCTAssertFalse(canSubmitCreateUser(draft))
    }

    func testMalformedEmailIsCalledOutBeforeTheIdentityMessage() {
        var draft = valid
        draft.fullName = ""
        draft.email = "dana@yahpz"
        let errors = validateInviteDraft(draft)
        XCTAssertEqual(errors.formMessage, FORM_EMAIL_INVALID)
        XCTAssertEqual(errors.fullName, FORM_NAME_CALLSIGN_ERROR)
        XCTAssertEqual(createUserEmailError("dana@yahpz"), FORM_EMAIL_INVALID)
        XCTAssertNil(createUserEmailError(""))
        XCTAssertNil(createUserEmailError("dana@yahpz.com"))
    }

    func testEmailShapeCheckAcceptsRealAddressesAndRejectsTypos() {
        XCTAssertTrue(looksLikeEmail("dana@yahpz.com"))
        XCTAssertTrue(looksLikeEmail(" dana.cohen@sub.yahpz.co.il "))
        XCTAssertFalse(looksLikeEmail("dana@yahpz"))
        XCTAssertFalse(looksLikeEmail("dana.yahpz.com"))
        XCTAssertFalse(looksLikeEmail("@yahpz.com"))
        XCTAssertFalse(looksLikeEmail("dana@@yahpz.com"))
        XCTAssertFalse(looksLikeEmail("dana@yahpz.com."))
        XCTAssertFalse(looksLikeEmail("dana cohen@yahpz.com"))
    }

    func testPhoneMustBeTenDigitsMatchingTheWebForm() {
        var draft = valid
        draft.phone = "031234567"
        XCTAssertEqual(validateInviteDraft(draft).phone, FORM_PHONE_ERROR)
        draft.phone = "052-111-1111"
        XCTAssertNil(validateInviteDraft(draft).phone)
        XCTAssertTrue(isValidPhone("050-1234567"))
        XCTAssertFalse(isValidPhone("050-123"))
    }

    func testAtLeastOneRoleIsRequiredMatchingTheEdgeFunction() {
        var draft = valid
        draft.roles = []
        let errors = validateInviteDraft(draft)
        XCTAssertEqual(errors.roles, INVITE_ROLE_ERROR)
        XCTAssertEqual(errors.formMessage, INVITE_ROLE_ERROR)
    }

    func testDuplicatePlatesOnTheSameDraftAreRejected() {
        var draft = valid
        draft.vehicles = [
            AdminVehicleDraft(key: "a", plateNumber: "12-345-67", model: "טויוטה"),
            AdminVehicleDraft(key: "b", plateNumber: "1234567", model: "קיה"),
        ]
        XCTAssertEqual(validateInviteDraft(draft).formMessage, DUPLICATE_PLATE_ERROR)
        XCTAssertEqual(findDuplicatePlate(draft.vehicles.map(\.plateNumber)), "1234567")
        XCTAssertNil(findDuplicatePlate(["1111111", "2222222", ""]))
    }

    func testAnAdminCannotRemoveTheirOwnAdminRole() {
        var draft = valid
        draft.id = "me"
        draft.roles = ["responder"]
        XCTAssertEqual(
            validateAdminUserDraft(draft, actorUserId: "me", isSuperAdmin: true).formMessage,
            CANNOT_REMOVE_OWN_ADMIN
        )
        draft.roles = ["admin", "shift_lead", "responder"]
        XCTAssertNil(
            validateAdminUserDraft(draft, actorUserId: "me", isSuperAdmin: true).formMessage
        )
    }

    func testARegularAdminCannotMutateASuperAdmin() {
        var draft = valid
        draft.id = "other"
        draft.roles = ["admin", "super_admin"]
        XCTAssertEqual(
            validateAdminUserDraft(draft, actorUserId: "me", isSuperAdmin: false).formMessage,
            SUPER_ADMIN_LOCK_ERROR
        )
        XCTAssertNil(
            validateAdminUserDraft(draft, actorUserId: "me", isSuperAdmin: true).formMessage
        )
    }

    func testRoleToggleAddsAndRemoves() {
        let once = toggleInviteRole(["responder"], role: "shift_lead")
        XCTAssertEqual(once, ["responder", "shift_lead"])
        XCTAssertEqual(toggleInviteRole(once, role: "shift_lead"), ["responder"])
    }

    func testThePhoneCannotHandOutSuperAdmin() {
        XCTAssertEqual(INVITABLE_ROLES, [.responder, .shiftLead, .admin])
        XCTAssertFalse(INVITABLE_ROLES.contains(.superAdmin))
    }

    func testActiveToggleCopySpeaksAboutTheStateBeingMovedTo() {
        XCTAssertEqual(setActiveActionLabel(next: false), "השבתת משתמש")
        XCTAssertEqual(setActiveActionLabel(next: true), "הפעלה מחדש")
        XCTAssertTrue(deactivateConfirmTitle("דנה כהן").contains("דנה כהן"))
        XCTAssertTrue(setActiveConfirm(next: false, name: "דנה כהן").contains("דנה כהן"))
        XCTAssertTrue(setActiveConfirm(next: false, name: "  ").contains("המשתמש"))
        XCTAssertEqual(setActiveToast(next: true), "החשבון הופעל.")
        XCTAssertEqual(setActiveToast(next: false), "החשבון הושבת.")
    }

    func testDefaultDraftInvitesAResponderWhoIsAnActiveVolunteer() {
        let draft = InviteDraft()
        XCTAssertEqual(draft.roles, ["responder"])
        XCTAssertEqual(draft.volunteerStatus, VolunteerStatus.activeVolunteer)
        XCTAssertTrue(draft.vehicles.isEmpty)
    }

    func testInvitePendingIsOnlyActiveUsersWhoHaveNotRegistered() {
        XCTAssertTrue(isInvitePending(active: true, invitePending: true))
        XCTAssertFalse(isInvitePending(active: true, invitePending: false))
        XCTAssertFalse(isInvitePending(active: false, invitePending: true))
    }

    func testPendingRegistrationHasNoAvailability() {
        XCTAssertFalse(hasAvailability(active: true, invitePending: true))
        XCTAssertTrue(hasAvailability(active: true, invitePending: false))
        XCTAssertTrue(hasAvailability(active: false, invitePending: false))
    }

    func testAdminUsersSortActiveThenInactiveThenInvitePendingByName() {
        let rows = [
            AdminUserSortKey(fullName: "דני", active: false, invitePending: false),
            AdminUserSortKey(fullName: "בני", active: true, invitePending: false),
            AdminUserSortKey(fullName: "אלי", active: true, invitePending: true),
            AdminUserSortKey(fullName: "אבי", active: true, invitePending: true),
        ]
        XCTAssertEqual(
            rows.sorted { compareAdminUsers($0, $1) < 0 }.map(\.fullName),
            ["בני", "דני", "אבי", "אלי"]
        )
    }

    func testSearchMatchesNameCallsignEmailVolunteerStatusAndAvailability() {
        let row = AdminUserSearchInput(
            fullName: "דנה כהן",
            callsign: "112",
            email: "dana@yahpz.com",
            volunteerStatus: VolunteerStatus.activeVolunteer.rawValue,
            availability: .unavailable,
            availableFrom: "2099-01-01",
            active: true,
            invitePending: false
        )
        XCTAssertTrue(adminUserMatchesQuery(row, query: "דנה", today: "2026-08-18"))
        XCTAssertTrue(adminUserMatchesQuery(row, query: "112", today: "2026-08-18"))
        XCTAssertTrue(adminUserMatchesQuery(row, query: "dana@", today: "2026-08-18"))
        XCTAssertTrue(adminUserMatchesQuery(row, query: "מתנדב", today: "2026-08-18"))
        XCTAssertTrue(adminUserMatchesQuery(row, query: "לא זמין", today: "2026-08-18"))
        XCTAssertFalse(adminUserMatchesQuery(row, query: "מנהלה", today: "2026-08-18"))
        XCTAssertEqual(USERS_SEARCH_PLACEHOLDER, "שם, או״ק, דוא״ל או סטטוס")
    }

    func testSearchIgnoresAvailabilityForPendingRegistration() {
        let row = AdminUserSearchInput(
            fullName: "אבי כהן",
            callsign: "200",
            email: "avi@yahpz.com",
            volunteerStatus: VolunteerStatus.activeVolunteer.rawValue,
            availability: .available,
            availableFrom: nil,
            active: true,
            invitePending: true
        )
        XCTAssertTrue(adminUserMatchesQuery(row, query: "אבי", today: "2026-08-18"))
        XCTAssertFalse(adminUserMatchesQuery(row, query: "זמין", today: "2026-08-18"))
    }

    func testOtpCompactLabelsMatchTheWebColumn() {
        XCTAssertEqual(otpUserLabel(otpLoginEnabled: true, otpUsersPageEnabled: true), "שניהם")
        XCTAssertEqual(otpUserLabel(otpLoginEnabled: true, otpUsersPageEnabled: false), "כניסה")
        XCTAssertEqual(otpUserLabel(otpLoginEnabled: false, otpUsersPageEnabled: true), "משתמשים")
        XCTAssertNil(otpUserLabel(otpLoginEnabled: false, otpUsersPageEnabled: false))
    }

    func testUsersPageOtpIsOnlyForAdmins() {
        XCTAssertTrue(canToggleUsersPageOtp(["admin"]))
        XCTAssertTrue(canToggleUsersPageOtp(["admin", "responder"]))
        XCTAssertFalse(canToggleUsersPageOtp(["responder"]))
        XCTAssertFalse(canToggleUsersPageOtp(["shift_lead"]))
    }

    func testRegularAdminsCannotMutateASuperAdminRow() {
        XCTAssertTrue(canMutateAdminUser(actorIsSuperAdmin: true, targetRoles: ["super_admin"]))
        XCTAssertFalse(canMutateAdminUser(actorIsSuperAdmin: false, targetRoles: ["super_admin"]))
        XCTAssertTrue(canMutateAdminUser(actorIsSuperAdmin: false, targetRoles: ["admin"]))
    }

    func testRoleSyncIgnoresSuperAdminSoTheUICannotGrantOrStripIt() {
        let diff = syncUserRolesDiff(current: ["admin", "super_admin"], next: ["responder"])
        XCTAssertEqual(diff.toAdd, ["responder"])
        XCTAssertEqual(diff.toRemove, ["admin"])
        XCTAssertFalse(diff.toAdd.contains("super_admin"))
        XCTAssertFalse(diff.toRemove.contains("super_admin"))
    }

    func testAddressKindLabelsMatchTheWebWithCustomOtherNames() {
        XCTAssertEqual(addressKindLabel("home"), "בית")
        XCTAssertEqual(addressKindLabel("work"), "עבודה")
        XCTAssertEqual(addressKindLabel("other", customLabel: "הורים"), "הורים")
        XCTAssertEqual(addressKindLabel("other", customLabel: "  "), "אחר")
        XCTAssertEqual(addressKindLabel("other"), "אחר")
    }

    func testDeleteConfirmCopyMatchesTheWeb() {
        XCTAssertEqual(DELETE_USER_TITLE, "מחיקת משתמש")
        XCTAssertTrue(deleteUserConfirm("דנה כהן").contains("דנה כהן"))
        XCTAssertEqual(SELF_DELETE_ERROR, "לא ניתן למחוק את המשתמש המחובר כעת.")
    }

    func testVolunteerStatusLabelsMatchAndroid() {
        XCTAssertEqual(volunteerStatusLabel("administration"), "מנהלה")
        XCTAssertEqual(volunteerStatusLabel("basic_training"), "חניכה בסיסית")
        XCTAssertEqual(volunteerStatusLabel("phone_training"), "חניכה טלפונית")
        XCTAssertEqual(volunteerStatusLabel("personal_vehicle_training"), "חניכה ברכב פרטי")
        XCTAssertEqual(volunteerStatusLabel("shifts_only"), "משמרות בלבד")
        XCTAssertEqual(volunteerStatusLabel("active_volunteer"), "מתנדב פעיל")
        XCTAssertEqual(volunteerStatusLabel(nil), "מתנדב פעיל")
        XCTAssertEqual(VolunteerStatus.fromRaw("unknown"), .activeVolunteer)
    }
}
