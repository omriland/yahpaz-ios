import XCTest
@testable import YahpazDomain

final class PlateScanTests: XCTestCase {
    func testExtractsSevenDigitPlateWithDashes() {
        XCTAssertEqual(extractIsraeliPlateCandidates("12-345-67"), ["1234567"])
    }

    func testExtractsEightDigitPlateWithDashes() {
        XCTAssertEqual(extractIsraeliPlateCandidates("713-86-301"), ["71386301"])
    }

    func testMapsCommonOcrGlyphsToDigits() {
        XCTAssertEqual(extractIsraeliPlateCandidates("I2-34S-67"), ["1234567"])
    }

    func testIgnoresShortOrLongDigitRuns() {
        XCTAssertTrue(extractIsraeliPlateCandidates("123456").isEmpty)
        XCTAssertTrue(extractIsraeliPlateCandidates("123456789").allSatisfy { $0.count == 7 || $0.count == 8 })
    }

    func testPrefersEightDigitWhenOverlapping() {
        let hits = extractIsraeliPlateCandidates("71386301")
        XCTAssertEqual(hits.first, "71386301")
    }

    func testConfirmRequiresStreak() {
        var state = PlateScanConfirmState()
        let step1 = advancePlateScanConfirm(state, topCandidate: "1234567", requiredStreak: 3)
        state = step1.state
        XCTAssertNil(step1.confirmed)
        XCTAssertEqual(state.streak, 1)

        let step2 = advancePlateScanConfirm(state, topCandidate: "1234567", requiredStreak: 3)
        state = step2.state
        XCTAssertNil(step2.confirmed)

        let step3 = advancePlateScanConfirm(state, topCandidate: "1234567", requiredStreak: 3)
        XCTAssertEqual(step3.confirmed, "1234567")
    }

    func testConfirmResetsOnDifferentCandidate() {
        let state = PlateScanConfirmState(digits: "1234567", streak: 2)
        let next = advancePlateScanConfirm(state, topCandidate: "7654321", requiredStreak: 3)
        XCTAssertNil(next.confirmed)
        XCTAssertEqual(next.state.digits, "7654321")
        XCTAssertEqual(next.state.streak, 1)
    }

    func testConfirmClearsOnEmpty() {
        let next = advancePlateScanConfirm(
            PlateScanConfirmState(digits: "1234567", streak: 2),
            topCandidate: nil,
            requiredStreak: 3
        )
        XCTAssertNil(next.confirmed)
        XCTAssertNil(next.state.digits)
        XCTAssertEqual(next.state.streak, 0)
    }
}
