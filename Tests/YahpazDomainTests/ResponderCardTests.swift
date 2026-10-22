import XCTest
@testable import YahpazDomain

final class ResponderCardTests: XCTestCase {
    func testShowsLeadKmToAnyLeadOrAdminRole() {
        XCTAssertTrue(responderCardShowsLeadKm(hasLeadRole: true))
        XCTAssertFalse(responderCardShowsLeadKm(hasLeadRole: false))
    }

    func testLabelsViewOnlyLeadKmForShiftLead() {
        XCTAssertEqual(LEAD_KM_VIEW_LABEL, "ק״מ (אחמ״ש)")
    }
}
