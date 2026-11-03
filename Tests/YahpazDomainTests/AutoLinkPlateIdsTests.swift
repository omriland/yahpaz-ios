import XCTest
@testable import YahpazDomain

final class AutoLinkPlateIdsTests: XCTestCase {
    private func plate(_ id: String, _ number: String) -> EventMediaPlateOption {
        EventMediaPlateOption(id: id, plateNumber: number, model: nil, color: nil, logoSlug: nil)
    }

    func testMatchesByDigitsRegardlessOfFormatting() {
        let plates = [plate("p1", "12-345-67"), plate("p2", "7654321")]
        XCTAssertEqual(autoLinkPlateIds(scannedDigits: ["1234567"], plates: plates, linkedIds: []), ["p1"])
        XCTAssertEqual(autoLinkPlateIds(scannedDigits: ["76-543-21"], plates: plates, linkedIds: []), ["p2"])
    }

    func testSkipsAlreadyLinked() {
        let plates = [plate("p1", "1234567"), plate("p2", "7654321")]
        XCTAssertEqual(
            autoLinkPlateIds(scannedDigits: ["1234567", "7654321"], plates: plates, linkedIds: ["p1"]),
            ["p2"]
        )
    }

    func testNoDuplicatesAndPlatesOrder() {
        let plates = [plate("p1", "1234567"), plate("p2", "7654321"), plate("p3", "1234567")]
        XCTAssertEqual(
            autoLinkPlateIds(scannedDigits: ["7654321", "1234567", "1234567"], plates: plates, linkedIds: []),
            ["p1", "p2", "p3"]
        )
    }

    func testEmptyWhenNothingMatches() {
        XCTAssertEqual(autoLinkPlateIds(scannedDigits: ["1111111"], plates: [plate("p1", "1234567")], linkedIds: []), [])
        XCTAssertEqual(autoLinkPlateIds(scannedDigits: [], plates: [plate("p1", "1234567")], linkedIds: []), [])
    }

    func testEmptyPlates() {
        XCTAssertEqual(autoLinkPlateIds(scannedDigits: ["1234567"], plates: [], linkedIds: []), [])
    }

    func testBlankPlateNumberNeverMatchesBlankScan() {
        XCTAssertEqual(autoLinkPlateIds(scannedDigits: [""], plates: [plate("p1", "")], linkedIds: []), [])
    }
}
