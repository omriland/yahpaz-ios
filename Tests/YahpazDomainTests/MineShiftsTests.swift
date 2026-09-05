import XCTest
@testable import YahpazDomain

final class MineShiftsTests: XCTestCase {
    func testFutureShiftIsNotPendingLog() {
        XCTAssertTrue(isShiftFuture("2026-08-18", today: "2026-08-17"))
        XCTAssertFalse(isShiftPendingLog("2026-08-18", odometerStart: nil, odometerEnd: nil, today: "2026-08-17"))
    }

    func testPastShiftWithoutOdometersIsPending() {
        XCTAssertTrue(isShiftPendingLog("2026-08-16", odometerStart: nil, odometerEnd: 10.0, today: "2026-08-17"))
    }

    func testPastShiftWithBothOdometersIsLogged() {
        XCTAssertFalse(isShiftPendingLog("2026-08-16", odometerStart: 1.0, odometerEnd: 20.0, today: "2026-08-17"))
    }

    func testPartitionSplitsPendingFutureAndLogged() {
        let sections = partitionMineShifts(
            [
                MineShiftItem(id: "future", date: "2026-08-20", odometerStart: nil, odometerEnd: nil),
                MineShiftItem(id: "pending", date: "2026-08-16", odometerStart: nil, odometerEnd: nil),
                MineShiftItem(id: "logged", date: "2026-08-15", odometerStart: 1.0, odometerEnd: 8.0),
            ],
            today: "2026-08-17",
            windowsLoaded: 1
        )
        XCTAssertEqual(sections.pending.map(\.id), ["pending"])
        XCTAssertEqual(sections.future.map(\.id), ["future"])
        XCTAssertEqual(sections.logged.map(\.id), ["logged"])
        XCTAssertFalse(sections.hasMoreLogged)
    }

    func testShiftStamps() {
        XCTAssertEqual(shiftStamp(.draft).label, "טיוטה")
        XCTAssertEqual(shiftStamp(.inProgress).label, "פתוחה")
        XCTAssertEqual(shiftStamp(.closed).label, "נסגרה")
    }

    func testHebrewWeekdayLetter() {
        XCTAssertEqual(hebrewWeekdayLetter("2026-08-16"), "א")
        XCTAssertEqual(hebrewWeekdayLetter("2026-08-17"), "ב")
        XCTAssertEqual(hebrewWeekdayLetter("2026-08-22"), "ש")
    }
}
