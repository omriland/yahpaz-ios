import XCTest
@testable import YahpazDomain

final class AvailabilityAndFormatTests: XCTestCase {
    func testAvailableWriteClearsReturnDate() {
        let write = buildAvailabilityWrite(status: .available, availableFrom: "2026-09-01", today: "2026-08-17")
        guard case let .ok(availability, from) = write else {
            return XCTFail("expected ok")
        }
        XCTAssertEqual(availability, .available)
        XCTAssertNil(from)
    }

    func testUnavailableWithFutureDate() {
        let write = buildAvailabilityWrite(status: .unavailable, availableFrom: "2026-08-18", today: "2026-08-17")
        guard case let .ok(availability, from) = write else {
            return XCTFail("expected ok")
        }
        XCTAssertEqual(availability, .unavailable)
        XCTAssertEqual(from, "2026-08-18")
    }

    func testUnavailableWithTodayOrPastIsRejected() {
        let write = buildAvailabilityWrite(status: .unavailable, availableFrom: "2026-08-17", today: "2026-08-17")
        guard case let .error(message) = write else {
            return XCTFail("expected error")
        }
        XCTAssertEqual(message, "יש לבחור תאריך עתידי")
    }

    func testReturnDateTypingFillsDayThenMonthThenYear() {
        XCTAssertEqual(formatReturnDateInput("30"), "30")
        XCTAssertEqual(formatReturnDateInput("3012"), "30/12")
        XCTAssertEqual(formatReturnDateInput("30122026"), "30/12/2026")
        XCTAssertEqual(formatReturnDateInput("30/12/2026"), "30/12/2026")
    }

    func testStoredIsoReturnDateShowsAsDayMonthYear() {
        XCTAssertEqual(returnDateToInput("2026-08-18"), "18/08/2026")
        XCTAssertEqual(returnDateToInput(""), "")
    }

    func testTypedReturnDateParsesToIso() {
        XCTAssertEqual(parseReturnDateInput("30122026"), "2026-12-30")
        XCTAssertEqual(parseReturnDateInput("30/12/2026"), "2026-12-30")
        XCTAssertNil(parseReturnDateInput("32/13/2026"))
        XCTAssertNil(parseReturnDateInput("3012"))
    }

    func testUnavailableWriteAcceptsTypedDayMonthYear() {
        let write = buildAvailabilityWrite(status: .unavailable, availableFrom: "30/12/2026", today: "2026-08-17")
        guard case let .ok(_, from) = write else {
            return XCTFail("expected ok")
        }
        XCTAssertEqual(from, "2026-12-30")
    }

    func testReturnDateKeystrokeTypesAndDeletesDigitsInOrder() {
        var value = ""
        for digit in "30122026" {
            value = applyReturnDateKeystroke(previous: value, incoming: value + String(digit))
        }
        XCTAssertEqual(value, "30/12/2026")
        value = applyReturnDateKeystroke(previous: value, incoming: "30/12/202")
        XCTAssertEqual(value, "30/12/202")
        XCTAssertEqual(applyReturnDateKeystroke(previous: "30/12", incoming: "3012"), "30/1")
    }

    func testEffectiveAvailabilityReturnsWhenDateArrives() {
        XCTAssertEqual(
            effectiveAvailability(.unavailable, availableFrom: "2026-08-17", today: "2026-08-17"),
            .available
        )
    }

    func testAvailabilitySearchLabelFollowsEffectiveStatus() {
        XCTAssertEqual(availabilitySearchLabel(.available, availableFrom: nil, today: "2026-08-17"), "זמין")
        XCTAssertEqual(availabilitySearchLabel(.unavailable, availableFrom: nil, today: "2026-08-17"), "לא זמין")
        XCTAssertEqual(
            availabilitySearchLabel(.unavailable, availableFrom: "2026-08-20", today: "2026-08-17"),
            "לא זמין"
        )
        XCTAssertEqual(
            availabilitySearchLabel(.unavailable, availableFrom: "2026-08-17", today: "2026-08-17"),
            "זמין"
        )
    }

    func testAvailabilityReturnCaptionFormatsHebrewDate() {
        XCTAssertEqual(availabilityReturnCaption("2026-08-18"), "חזרה ב־18.08.2026")
        XCTAssertNil(availabilityReturnCaption(nil))
        XCTAssertNil(availabilityReturnCaption(""))
    }

    func testFormatPlateSevenAndEightDigits() {
        XCTAssertEqual(formatPlate("1234567"), "12-345-67")
        XCTAssertEqual(formatPlate("12345678"), "123-45-678")
        XCTAssertEqual(plateDigits("12-345-67"), "1234567")
    }

    func testFindDuplicatePlateReturnsTheRepeatedDigits() {
        XCTAssertEqual(findDuplicatePlate(["12-345-67", "1234567"]), "1234567")
        XCTAssertNil(findDuplicatePlate(["1111111", "2222222"]))
        XCTAssertNil(findDuplicatePlate(["", "abc"]))
    }

    func testPasswordStrengthRequiresLengthUppercaseAndSymbol() {
        XCTAssertNotNil(passwordStrengthError("short"))
        XCTAssertNotNil(passwordStrengthError("longenough1"))
        XCTAssertNil(passwordStrengthError("Longenough!"))
    }

    func testShouldEmitPingOnFirstFixOrMoveOrInterval() {
        XCTAssertTrue(shouldEmitPing(last: nil, next: LatLngAt(lat: 32.0, lng: 34.8, atMs: 1_000)))
        let last = LatLngAt(lat: 32.0, lng: 34.8, atMs: 1_000)
        XCTAssertFalse(
            shouldEmitPing(last: last, next: LatLngAt(lat: 32.00001, lng: 34.8, atMs: 2_000))
        )
        XCTAssertTrue(
            shouldEmitPing(last: last, next: LatLngAt(lat: 32.0, lng: 34.8, atMs: 12_000))
        )
    }

    func testParseTrackTokenFromYahpazURL() {
        XCTAssertEqual(
            parseTrackToken(from: "https://yahpz.com/?track_token=abc"),
            "abc"
        )
        XCTAssertEqual(parseTrackToken(from: "yahpaz://track?token=xyz"), "xyz")
        XCTAssertNil(parseTrackToken(from: "https://yahpz.com/events"))
    }
}
