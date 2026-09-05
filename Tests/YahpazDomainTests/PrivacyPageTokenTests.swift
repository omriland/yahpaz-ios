import XCTest
@testable import YahpazDomain

final class PrivacyPageTokenTests: XCTestCase {
    private let testSecret = "test-privacy-secret"
    private let testNow: Int64 = 1_700_000_000
    private let testVector =
        "1700000900.1b55aad767119a9b8b62ab8bd7ea29c13774c7f37a979ab966f7375a4abafa02"

    func testMatchesTheLockedWebTestVector() {
        let token = createPrivacyPageToken(secret: testSecret, nowSec: testNow)
        XCTAssertEqual(token, testVector)
        XCTAssertTrue(verifyPrivacyPageToken(secret: testSecret, token: token, nowSec: testNow))
    }

    func testRejectsExpiredFutureOrTamperedTokens() {
        let token = createPrivacyPageToken(secret: testSecret, nowSec: testNow)
        XCTAssertFalse(
            verifyPrivacyPageToken(
                secret: testSecret,
                token: token,
                nowSec: testNow + Int64(PRIVACY_TOKEN_TTL_SEC) + 61
            )
        )
        XCTAssertFalse(
            verifyPrivacyPageToken(
                secret: testSecret,
                token: token,
                nowSec: testNow - Int64(PRIVACY_TOKEN_TTL_SEC) - 61
            )
        )
        XCTAssertFalse(
            verifyPrivacyPageToken(
                secret: testSecret,
                token: String(token.dropLast()) + "0",
                nowSec: testNow
            )
        )
        XCTAssertFalse(verifyPrivacyPageToken(secret: "other-secret", token: token, nowSec: testNow))
        XCTAssertFalse(verifyPrivacyPageToken(secret: testSecret, token: "", nowSec: testNow))
    }

    func testBuildsTheInAppPrivacyUrlWithT() {
        XCTAssertEqual(
            buildPrivacyPolicyUrl(origin: "https://yahpz.com", token: testVector),
            "https://yahpz.com/privacy?t=\(testVector)"
        )
    }
}
