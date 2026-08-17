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
        XCTAssertEqual(message, "בחרו תאריך מהמחר או השאירו ריק.")
    }

    func testEffectiveAvailabilityReturnsWhenDateArrives() {
        XCTAssertEqual(
            effectiveAvailability(.unavailable, availableFrom: "2026-08-17", today: "2026-08-17"),
            .available
        )
    }

    func testFormatPlateSevenAndEightDigits() {
        XCTAssertEqual(formatPlate("1234567"), "12-345-67")
        XCTAssertEqual(formatPlate("12345678"), "123-45-678")
        XCTAssertEqual(plateDigits("12-345-67"), "1234567")
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
