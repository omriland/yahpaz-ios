import XCTest
@testable import YahpazDomain

final class RolePreviewTests: XCTestCase {
    func testAllowsSuperAdminWhenNotImpersonatingOrPreviewing() {
        XCTAssertTrue(
            canStartRolePreview(
                actualRoles: ["admin", "super_admin"],
                impersonating: false,
                previewing: false
            )
        )
        XCTAssertTrue(
            canStartImpersonation(
                actualRoles: ["admin", "super_admin"],
                impersonating: false
            )
        )
    }

    func testRejectsRegularAdminImpersonationAndActivePreview() {
        XCTAssertFalse(
            canStartRolePreview(
                actualRoles: ["admin"],
                impersonating: false,
                previewing: false
            )
        )
        XCTAssertFalse(
            canStartRolePreview(
                actualRoles: ["admin", "super_admin"],
                impersonating: true,
                previewing: false
            )
        )
        XCTAssertFalse(
            canStartRolePreview(
                actualRoles: ["admin", "super_admin"],
                impersonating: false,
                previewing: true
            )
        )
        XCTAssertFalse(
            canStartImpersonation(
                actualRoles: ["admin", "super_admin"],
                impersonating: true
            )
        )
    }

    func testEffectiveRolesMasksToSelectedRole() {
        XCTAssertEqual(
            ["admin", "shift_lead", "super_admin"],
            effectiveRoles(["admin", "shift_lead", "super_admin"], previewRole: nil)
        )
        XCTAssertEqual(["responder"], effectiveRoles(["admin", "super_admin"], previewRole: .responder))
        XCTAssertEqual(["shift_lead"], effectiveRoles(["admin", "super_admin"], previewRole: .shiftLead))
        XCTAssertEqual(["admin"], effectiveRoles(["admin", "super_admin"], previewRole: .admin))
    }

    func testParseRolePreviewAcceptsAssignableOnly() {
        XCTAssertEqual(AppRole.responder, parseRolePreviewRole("responder"))
        XCTAssertEqual(AppRole.shiftLead, parseRolePreviewRole("shift_lead"))
        XCTAssertEqual(AppRole.admin, parseRolePreviewRole("admin"))
        XCTAssertNil(parseRolePreviewRole("super_admin"))
        XCTAssertNil(parseRolePreviewRole("nope"))
        XCTAssertNil(parseRolePreviewRole(nil))
    }

    func testPreviewLabelsMatchTheRestOfTheApp() {
        XCTAssertEqual("מתנדב", rolePreviewLabel(.responder))
        XCTAssertEqual("אחמ״ש", rolePreviewLabel(.shiftLead))
        XCTAssertEqual("מנהל", rolePreviewLabel(.admin))
        XCTAssertEqual("צופה כתפקיד מתנדב", rolePreviewBannerText(.responder))
        XCTAssertEqual("צופה כ־דנה · או״ק 112", impersonationBannerText(fullName: "דנה", callsign: "112"))
    }
}
