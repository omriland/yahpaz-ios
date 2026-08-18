import XCTest
@testable import YahpazDomain

final class TreatedPlatesTests: XCTestCase {
    func testCommitFormats7DigitsWithHyphensAndAppends() {
        let result = commitTreatedPlate(pending: "1234567", plates: [])
        guard case let .ok(plate, plates) = result else {
            return XCTFail("expected ok")
        }
        XCTAssertEqual(plate.plateNumber, "12-345-67")
        XCTAssertNil(plate.model)
        XCTAssertNil(plate.color)
        XCTAssertEqual(plates, [TreatedPlate(plateNumber: "12-345-67", model: nil, color: nil)])
    }

    func testCommitFormats8DigitsWithHyphens() {
        let result = commitTreatedPlate(pending: "71386301", plates: [])
        guard case let .ok(plate, _) = result else {
            return XCTFail("expected ok")
        }
        XCTAssertEqual(plate.plateNumber, "713-86-301")
    }

    func testCommitRejects6Digits() {
        let result = commitTreatedPlate(pending: "123456", plates: [])
        guard case let .error(message) = result else {
            return XCTFail("expected error")
        }
        XCTAssertEqual(message, TREATED_PLATE_LENGTH_ERROR)
    }

    func testCommitRejectsDuplicateByDigits() {
        let existing = [TreatedPlate(plateNumber: "12-345-67", model: nil, color: nil)]
        let result = commitTreatedPlate(pending: "1234567", plates: existing)
        guard case let .error(message) = result else {
            return XCTFail("expected error")
        }
        XCTAssertEqual(message, TREATED_PLATE_DUPLICATE_ERROR)
    }

    func testLeftoverIgnoredOnDraft() {
        XCTAssertNil(leftoverTreatedPlateError(pending: "123", mode: .draft))
    }

    func testLeftoverErrorsDigitsOnComplete() {
        XCTAssertEqual(
            leftoverTreatedPlateError(pending: "123", mode: .complete),
            TREATED_PLATE_LEFTOVER_ERROR
        )
    }

    func testLeftoverAllowsEmptyPendingOnComplete() {
        XCTAssertNil(leftoverTreatedPlateError(pending: "", mode: .complete))
    }

    func testCaptionJoinsModelAndColor() {
        XCTAssertEqual(treatedPlateCaption(model: "REXTON", color: "שחור"), "REXTON · שחור")
    }

    func testCaptionShowsSingleSideWhenOtherMissing() {
        XCTAssertEqual(treatedPlateCaption(model: "REXTON", color: nil), "REXTON")
        XCTAssertEqual(treatedPlateCaption(model: nil, color: "שחור"), "שחור")
        XCTAssertNil(treatedPlateCaption(model: nil, color: nil))
    }

    func testRemoveDropsByDigitMatch() {
        let plates = [
            TreatedPlate(plateNumber: "12-345-67", model: nil, color: nil),
            TreatedPlate(plateNumber: "713-86-301", model: "REXTON", color: "שחור"),
        ]
        XCTAssertEqual(removeTreatedPlate(plates, plateDigitsKey: "1234567"), [plates[1]])
    }
}
