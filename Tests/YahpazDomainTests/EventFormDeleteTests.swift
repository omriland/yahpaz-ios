import XCTest
@testable import YahpazDomain

final class EventFormDeleteTests: XCTestCase {
    private let lead = CockpitDeleteViewer(userId: "lead-a", isAdmin: false)
    private let otherLead = CockpitDeleteViewer(userId: "lead-a", isAdmin: false)

    func testDeleteBlockedWhileRespondersRemain() {
        XCTAssertEqual(cockpitDeleteBlock(responderCount: 1, shiftLeadId: "lead-a", viewer: lead), .responders)
        XCTAssertNil(cockpitDeleteBlock(responderCount: 0, shiftLeadId: "lead-a", viewer: lead))
        XCTAssertEqual(cockpitDeleteHint(.responders), COCKPIT_DELETE_RESPONDERS)
        XCTAssertEqual(cockpitDeleteHint(nil), COCKPIT_DELETE_CONFIRM_AGAIN)
        XCTAssertEqual(
            cockpitDeleteClick(armed: false, responderCount: 0, shiftLeadId: "lead-a", viewer: lead),
            .arm
        )
        XCTAssertEqual(
            cockpitDeleteClick(armed: true, responderCount: 0, shiftLeadId: "lead-a", viewer: lead),
            .delete
        )
        XCTAssertEqual(
            cockpitDeleteClick(armed: false, responderCount: 1, shiftLeadId: "lead-a", viewer: lead),
            .blocked(.responders)
        )
    }

    func testOtherLeadCannotSeeDelete() {
        XCTAssertEqual(
            cockpitDeleteBlock(responderCount: 0, shiftLeadId: "lead-b", viewer: otherLead),
            .otherLead
        )
        XCTAssertFalse(shouldShowCockpitDelete(.otherLead))
        XCTAssertTrue(shouldShowCockpitDelete(.responders))
        XCTAssertTrue(shouldShowCockpitDelete(nil))
        XCTAssertEqual(cockpitDeleteHint(.otherLead), EVENT_DELETE_OTHER_LEAD)
    }
}
