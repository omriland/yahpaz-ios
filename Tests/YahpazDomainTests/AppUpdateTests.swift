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

    func testOptionalWhenCurrentMeetsMinButIsBehindLatest() {
        XCTAssertTrue(needsOptionalUpdate(currentBuild: 24, minBuild: 24, latestBuild: 26))
        XCTAssertTrue(needsOptionalUpdate(currentBuild: 25, minBuild: 24, latestBuild: 26))
    }

    func testNotOptionalWhenCurrentIsAtLatestOrBelowMin() {
        XCTAssertFalse(needsOptionalUpdate(currentBuild: 26, minBuild: 24, latestBuild: 26))
        XCTAssertFalse(needsOptionalUpdate(currentBuild: 27, minBuild: 24, latestBuild: 26))
        XCTAssertFalse(needsOptionalUpdate(currentBuild: 23, minBuild: 24, latestBuild: 26))
    }

    func testItmsInstallHrefWrapsYahpzManifest() {
        XCTAssertEqual(
            itmsInstallHref("https://yahpz.com/ios/manifest.plist"),
            "itms-services://?action=download-manifest&url=https%3A%2F%2Fyahpz.com%2Fios%2Fmanifest.plist"
        )
    }

    func testItmsInstallHrefAcceptsWwwHost() {
        XCTAssertEqual(
            itmsInstallHref("https://www.yahpz.com/ios/manifest.plist"),
            "itms-services://?action=download-manifest&url=https%3A%2F%2Fwww.yahpz.com%2Fios%2Fmanifest.plist"
        )
    }

    func testItmsInstallHrefRejectsUnsafeManifests() {
        XCTAssertNil(itmsInstallHref("http://yahpz.com/ios/manifest.plist"))
        XCTAssertNil(itmsInstallHref("https://evil.example/ios/manifest.plist"))
        XCTAssertNil(itmsInstallHref("https://yahpz.com/ios/Yahpaz.ipa"))
        XCTAssertNil(itmsInstallHref(""))
        XCTAssertNil(itmsInstallHref("   "))
    }
}
