import XCTest
@testable import YahpazDomain

final class ForeignEventEditTests: XCTestCase {
    func testIsTrueOnlyWhenAnotherLeadCreatedTheEvent() {
        XCTAssertTrue(isForeignShiftLeadEvent(viewerId: "me", shiftLeadId: "them"))
        XCTAssertFalse(isForeignShiftLeadEvent(viewerId: "me", shiftLeadId: "me"))
    }

    func testIsFalseWhenEitherIdIsMissing() {
        XCTAssertFalse(isForeignShiftLeadEvent(viewerId: "me", shiftLeadId: nil))
        XCTAssertFalse(isForeignShiftLeadEvent(viewerId: nil, shiftLeadId: "them"))
        XCTAssertFalse(isForeignShiftLeadEvent(viewerId: "  ", shiftLeadId: "them"))
    }

    func testTitleUsesTheLeadName() {
        XCTAssertEqual(
            foreignEventEditTitle("דנה כהן"),
            "האם אתה בטוח שברצונך לערוך אירוע שהוזן על ידי דנה כהן?"
        )
        XCTAssertEqual(FOREIGN_EVENT_EDIT_BODY, "כל שינוי שתבצע יתועד ויישמר במערכת")
    }

    func testLeadNameFallsBackFromEmptyNameToCallsign() {
        XCTAssertEqual(foreignEventEditLeadName(fullName: "  ", callsign: "A12"), "A12")
        XCTAssertEqual(foreignEventEditLeadName(fullName: "", callsign: ""), FOREIGN_EVENT_EDIT_LEAD_FALLBACK)
    }
}
