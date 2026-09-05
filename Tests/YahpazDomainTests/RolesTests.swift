import XCTest
@testable import YahpazDomain

final class RolesTests: XCTestCase {
    func testUnknownRolesAreDropped() {
        XCTAssertEqual(roleSet(["responder", "kitchen_staff"]), Set([AppRole.responder]))
        XCTAssertNil(AppRole.fromRaw("kitchen_staff"))
        XCTAssertEqual(AppRole.fromRaw("shift_lead"), .shiftLead)
    }

    func testManagesUnitCoversLeadAdminAndSuperAdmin() {
        XCTAssertTrue(managesUnit(["shift_lead"]))
        XCTAssertTrue(managesUnit(["admin"]))
        XCTAssertTrue(managesUnit(["super_admin"]))
        XCTAssertTrue(managesUnit(["responder", "shift_lead"]))
        XCTAssertFalse(managesUnit(["responder"]))
        XCTAssertFalse(managesUnit([]))
    }

    func testIsAdminExcludesShiftLead() {
        XCTAssertTrue(isAdmin(["admin"]))
        XCTAssertTrue(isAdmin(["super_admin"]))
        XCTAssertFalse(isAdmin(["shift_lead"]))
        XCTAssertFalse(isAdmin(["responder"]))
        XCTAssertFalse(isAdmin([]))
    }

    func testIsResponderIncludesAnyoneWhoManagesTheUnit() {
        XCTAssertTrue(isResponder(["responder"]))
        XCTAssertTrue(isResponder(["shift_lead"]))
        XCTAssertTrue(isResponder(["admin"]))
        XCTAssertFalse(isResponder([]))
    }

    func testRoleLabelsFollowTheWebWording() {
        XCTAssertEqual(highestRoleLabel(["responder", "shift_lead"]), "אחמ״ש")
        XCTAssertEqual(highestRoleLabel(["responder", "admin"]), "מנהל")
        XCTAssertEqual(highestRoleLabel(["admin", "super_admin"]), "מנהל־על")
        XCTAssertNil(highestRoleLabel([]))
        XCTAssertEqual(roleLabels(["responder", "shift_lead"]), ["אחמ״ש", "מתנדב"])
    }

    func testToolsTabLabelDependsOnAdminRights() {
        XCTAssertEqual(toolsTabLabel(["shift_lead"]), TOOLS_TAB_LEAD_LABEL)
        XCTAssertEqual(toolsTabLabel(["admin"]), TOOLS_TAB_ADMIN_LABEL)
    }

    func testImpliedAssignableRolesIncludeEveryRoleBelowTheSelectedOne() {
        XCTAssertEqual(impliedAssignableRoles(.admin), ["admin", "shift_lead", "responder"])
        XCTAssertEqual(impliedAssignableRoles(.shiftLead), ["shift_lead", "responder"])
        XCTAssertEqual(impliedAssignableRoles(.responder), ["responder"])
    }

    func testLowerAssignableRolesLockWhenAHigherOneIsSelected() {
        XCTAssertTrue(isAssignableRoleLocked(["admin"], role: .shiftLead))
        XCTAssertTrue(isAssignableRoleLocked(["admin"], role: .responder))
        XCTAssertFalse(isAssignableRoleLocked(["admin", "shift_lead", "responder"], role: .admin))
        XCTAssertFalse(isAssignableRoleLocked(["responder"], role: .responder))
    }

    func testToggleAssignableRoleImpliesTheRolesBeneathIt() {
        XCTAssertEqual(
            toggleAssignableRole(["responder"], role: .shiftLead, checked: true),
            ["shift_lead", "responder"]
        )
        XCTAssertEqual(
            toggleAssignableRole(["responder"], role: .admin, checked: true),
            ["admin", "shift_lead", "responder"]
        )
        XCTAssertEqual(
            toggleAssignableRole(["admin", "shift_lead", "responder"], role: .admin, checked: false),
            ["shift_lead", "responder"]
        )
        XCTAssertEqual(
            toggleAssignableRole(["shift_lead", "responder"], role: .shiftLead, checked: false),
            ["responder"]
        )
    }

    func testWithImpliedAssignableRolesFillsFromTheHighestAssignedRole() {
        XCTAssertEqual(withImpliedAssignableRoles(["admin"]), ["admin", "shift_lead", "responder"])
        XCTAssertEqual(withImpliedAssignableRoles(["super_admin"]), [])
    }
}
