import XCTest
@testable import YahpazDomain

final class PlateLookupTests: XCTestCase {
    func testMisparStripsDashesAndLeadingZeros() {
        XCTAssertEqual(plateLookupMispar("713-86-301"), 71386301)
        XCTAssertEqual(plateLookupMispar("01234567"), 1234567)
    }

    func testParseReadsModelAndColorFromHit() throws {
        let body = """
        {"success":true,"result":{"records":[{"tzeva_rechev":"שחור","kinuy_mishari":"REXTON"}]}}
        """
        let hit = try XCTUnwrap(parsePlateLookupBody(body))
        XCTAssertEqual(hit.model, "REXTON")
        XCTAssertEqual(hit.color, "שחור")
    }

    func testParseReturnsNilOnEmptyRecords() {
        let body = #"{"success":true,"result":{"records":[]}}"#
        XCTAssertNil(parsePlateLookupBody(body))
    }

    func testParseReturnsNilOnWafHtml() {
        XCTAssertNil(parsePlateLookupBody("<html>blocked</html>"))
    }

    func testUrlEncodesResourceAndNumericFilter() {
        let url = plateLookupUrl(plate: "713-86-301")
        XCTAssertTrue(url.contains("resource_id=053cea08-09bc-40ec-8f7a-156f0677aff3"))
        XCTAssertTrue(url.contains("%7B%22mispar_rechev%22%3A71386301%7D"))
    }
}
