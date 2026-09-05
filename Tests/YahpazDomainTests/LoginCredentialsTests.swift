import XCTest
@testable import YahpazDomain

final class LoginCredentialsTests: XCTestCase {
    func testTrimsAndLowercasesEmail() {
        XCTAssertEqual(normalizeLoginEmail("  Ron.Gal72@Gmail.com  "), "ron.gal72@gmail.com")
    }

    func testStripsBidiMarksThatRTLFieldsInjectAroundADottedGmailAddress() {
        let typed = "\u{200F}ron.gal72@gmail.com\u{200E}" + "\u{202A}" + "\u{202C}" + "\u{2066}" + "\u{2069}"
        XCTAssertEqual(normalizeLoginEmail(typed), "ron.gal72@gmail.com")
    }

    func testKeepsTheGmailLocalPartDot() {
        XCTAssertEqual(normalizeLoginEmail("ron.gal72@gmail.com"), "ron.gal72@gmail.com")
        XCTAssertEqual(normalizeLoginEmail("rongal72@gmail.com"), "rongal72@gmail.com")
    }

    func testStripsBidiMarksFromThePasswordWithoutTrimmingSecrets() {
        XCTAssertEqual(normalizeLoginSecret("\u{200F} AbC!12 \u{200E}"), " AbC!12 ")
    }
}
