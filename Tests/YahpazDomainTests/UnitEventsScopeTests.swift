import XCTest
@testable import YahpazDomain

final class UnitEventsScopeTests: XCTestCase {
    func testLeadOnlyDefaultsToOwnCreatedEvents() {
        XCTAssertTrue(shouldFilterUnitEventsToOwnCreated(["shift_lead"]))
        XCTAssertTrue(shouldFilterUnitEventsToOwnCreated(["shift_lead", "responder"]))
        XCTAssertEqual(
            unitEventsCreatedByFilter(roles: ["shift_lead"], showOthersCreated: false, userId: "lead-a"),
            "lead-a"
        )
    }

    func testLeadOnlyToggleOnReturnsTheFullUnitList() {
        XCTAssertNil(
            unitEventsCreatedByFilter(
                roles: ["shift_lead", "responder"],
                showOthersCreated: true,
                userId: "lead-a"
            )
        )
    }

    func testAdminPlusLeadNeverGetsTheOwnCreatedDefault() {
        XCTAssertFalse(shouldFilterUnitEventsToOwnCreated(["admin"]))
        XCTAssertFalse(shouldFilterUnitEventsToOwnCreated(["admin", "shift_lead"]))
        XCTAssertNil(
            unitEventsCreatedByFilter(
                roles: ["admin", "shift_lead"],
                showOthersCreated: false,
                userId: "admin-1"
            )
        )
    }

    func testSuperAdminNeverGetsTheOwnCreatedDefault() {
        XCTAssertFalse(shouldFilterUnitEventsToOwnCreated(["super_admin"]))
        XCTAssertFalse(shouldFilterUnitEventsToOwnCreated(["super_admin", "shift_lead"]))
        XCTAssertFalse(shouldFilterUnitEventsToOwnCreated(["admin", "super_admin", "shift_lead"]))
        XCTAssertNil(
            unitEventsCreatedByFilter(roles: ["super_admin"], showOthersCreated: false, userId: "sa-1")
        )
    }

    func testUsesTheLockedHebrewLabel() {
        XCTAssertEqual(SHOW_OTHERS_CREATED_EVENTS_LABEL, "הצג אירועים שנוצרו על ידי אחרים")
    }
}
