import XCTest
@testable import YahpazDomain

final class SessionReportTests: XCTestCase {
    func testRpcParamsUseVersionCodeAndTrimmedName() {
        let params = sessionRpcParams(versionCode: 17, versionName: " 0.3.6 ")
        XCTAssertEqual(params.versionCode, 17)
        XCTAssertEqual(params.versionName, "0.3.6")
    }

    func testReportsImmediatelyWhenNeverSucceeded() {
        XCTAssertTrue(shouldReportSession(lastSuccessAtMs: nil, nowMs: 1_000))
    }

    func testThrottlesInsideFifteenMinutes() {
        let first: Int64 = 0
        let fourteenMin: Int64 = 14 * 60 * 1000
        XCTAssertFalse(shouldReportSession(lastSuccessAtMs: first, nowMs: fourteenMin))
        XCTAssertTrue(shouldReportSession(lastSuccessAtMs: first, nowMs: 15 * 60 * 1000))
    }

    func testUsesExistingAndroidHeartbeatRpc() {
        XCTAssertEqual(SESSION_REPORT_RPC, "report_android_session")
        XCTAssertEqual(SESSION_REPORT_THROTTLE_MS, 15 * 60 * 1000)
    }
}
