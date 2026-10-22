import XCTest
@testable import YahpazDomain

final class EventResponderReleaseTests: XCTestCase {
    func testHoldsManualEventUntilCallsignRoadAndPoliceId() {
        XCTAssertFalse(eventReleasedToResponders(origin: "manual", policeEventId: nil, patrolCallsignNumber: "411", hasRoad: true))
        XCTAssertFalse(eventReleasedToResponders(origin: "manual", policeEventId: "   ", patrolCallsignNumber: "411", hasRoad: true))
        XCTAssertFalse(eventReleasedToResponders(origin: nil, policeEventId: "", patrolCallsignNumber: "411", hasRoad: true))
        XCTAssertFalse(eventReleasedToResponders(origin: "manual", policeEventId: "12345", patrolCallsignNumber: nil, hasRoad: true))
        XCTAssertFalse(eventReleasedToResponders(origin: "manual", policeEventId: "12345", patrolCallsignNumber: "411", hasRoad: false))
        XCTAssertFalse(eventReleasedToResponders(
            origin: "manual",
            policeEventId: "12345",
            patrolCallsignNumber: "   ",
            hasRoad: true,
            patrolCallsignLegacy: "אביב"
        ))
        XCTAssertTrue(eventReleasedToResponders(
            origin: "manual",
            policeEventId: "12345",
            patrolCallsignNumber: nil,
            hasRoad: true,
            patrolCallsignLegacy: "ניידת 1"
        ))
        XCTAssertTrue(eventReleasedToResponders(origin: "manual", policeEventId: "12345", patrolCallsignNumber: "411", hasRoad: true))
    }

    func testNeverHoldsShiftBorn() {
        XCTAssertTrue(eventReleasedToResponders(origin: "shift", policeEventId: nil, patrolCallsignNumber: nil, hasRoad: false))
        XCTAssertTrue(eventReleasedToResponders(origin: "shift", policeEventId: "", hasRoad: false))
    }
}
