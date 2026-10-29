import XCTest
@testable import YahpazDomain

final class AppUpdateTests: XCTestCase {
    func testForceWhenCurrentIsBelowMin() {
        XCTAssertTrue(needsForceUpdate(currentBuild: 1, minBuild: 2))
        XCTAssertTrue(needsForceUpdate(currentBuild: 2, minBuild: 10))
    }

    func testAllowWhenCurrentMeetsOrExceedsMin() {
        XCTAssertFalse(needsForceUpdate(currentBuild: 2, minBuild: 2))
        XCTAssertFalse(needsForceUpdate(currentBuild: 3, minBuild: 2))
    }
}
