import XCTest
@testable import YahpazDomain

final class AssignedVolunteerEventEditTests: XCTestCase {
    func testBlocksWhenTheViewerIsAResponder() {
        XCTAssertTrue(isAssignedVolunteerEventEditBlocked(viewerId: "me", responderIds: ["a", "me"], secondaryLeadIds: []))
    }

    func testBlocksWhenTheViewerIsASecondaryLeadWithoutAResponderRow() {
        XCTAssertTrue(isAssignedVolunteerEventEditBlocked(viewerId: "me", responderIds: ["a"], secondaryLeadIds: ["me"]))
    }

    func testDoesNotBlockAMainOnlyLead() {
        XCTAssertFalse(
            isAssignedVolunteerEventEditBlocked(viewerId: "lead", responderIds: ["a", "b"], secondaryLeadIds: ["other"])
        )
    }

    func testDoesNotBlockWhenTheViewerIdIsMissing() {
        XCTAssertFalse(isAssignedVolunteerEventEditBlocked(viewerId: nil, responderIds: ["me"], secondaryLeadIds: ["me"]))
        XCTAssertFalse(isAssignedVolunteerEventEditBlocked(viewerId: "  ", responderIds: ["me"], secondaryLeadIds: []))
    }

    func testDraftHelperUsesResponderAndSecondaryIds() {
        let draft = EventDraft(
            eventDate: "2026-09-04",
            responders: [EventResponderDraft(responderId: "me")],
            secondaryLeads: [SecondaryLead(userId: "other")]
        )
        XCTAssertTrue(draft.blocksAssignedVolunteerEdit(viewerId: "me"))
        XCTAssertFalse(draft.blocksAssignedVolunteerEdit(viewerId: "lead"))
        XCTAssertTrue(
            EventDraft(
                eventDate: "2026-09-04",
                secondaryLeads: [SecondaryLead(userId: "sec")]
            ).blocksAssignedVolunteerEdit(viewerId: "sec")
        )
    }

    func testKeepsTheExactHebrewRejectCopy() {
        XCTAssertEqual(
            ASSIGNED_VOLUNTEER_EVENT_EDIT_ERROR,
            "לא ניתן לערוך אירוע עליו אתה מוצב כמתנדב. לעדכון פרטים יש לפנות לאחמ\"ש המזין או למנהל מערכת"
        )
    }
}
