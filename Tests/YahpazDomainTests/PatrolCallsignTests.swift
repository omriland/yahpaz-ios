import XCTest
@testable import YahpazDomain

final class PatrolCallsignTests: XCTestCase {
    func testSplitTakesTheLastDigitRun() {
        XCTAssertEqual(splitPatrolCallsign("411"), SplitPatrolCallsign(number: "411"))
        XCTAssertEqual(splitPatrolCallsign("אביב"), SplitPatrolCallsign(prefix: "אביב"))
        XCTAssertEqual(splitPatrolCallsign("אביב 411"), SplitPatrolCallsign(prefix: "אביב", number: "411"))
        XCTAssertEqual(splitPatrolCallsign("אביב411"), SplitPatrolCallsign(prefix: "אביב", number: "411"))
        XCTAssertEqual(splitPatrolCallsign("אביב 411 ב"), SplitPatrolCallsign(prefix: "אביב ב", number: "411"))
        XCTAssertEqual(splitPatrolCallsign(""), SplitPatrolCallsign())
    }

    func testFormatJoinsPrefixAndNumber() {
        XCTAssertEqual(formatPatrolCallsign("אביב", "411"), "אביב 411")
        XCTAssertEqual(formatPatrolCallsign("אביב", ""), "אביב")
        XCTAssertEqual(formatPatrolCallsign("", "411"), "411")
        XCTAssertEqual(formatPatrolCallsign("  ", "  "), "")
    }

    func testInputLimits() {
        XCTAssertEqual(patrolCallsignPrefixForInput(String(repeating: "א", count: 20)).count, 16)
        XCTAssertEqual(patrolCallsignNumberForInput("12a34567"), "12345")
        XCTAssertEqual(PATROL_CALLSIGN_PREFIX_LABEL, "אוק - כינוי")
        XCTAssertEqual(PATROL_CALLSIGN_NUMBER_LABEL, "אוק - מס")
    }

    func testResolvePrefersSplitColumns() {
        XCTAssertEqual(
            resolvePatrolCallsign(prefix: "חוף", number: "12", legacy: "אביב 411"),
            SplitPatrolCallsign(prefix: "חוף", number: "12")
        )
        XCTAssertEqual(
            resolvePatrolCallsign(legacy: "אביב 411"),
            SplitPatrolCallsign(prefix: "אביב", number: "411")
        )
    }

    func testEventFormTimesPreferEventThenResponders() {
        let starts = ["2026-02-02T08:00:00", "2026-02-02T07:30:00", nil]
        let ends = ["2026-02-02T09:00:00", "2026-02-02T12:00:00", nil]
        let fromEvent = eventFormTimes(
            eventStart: "2026-02-02T10:00:00",
            eventEnd: "2026-02-02T11:00:00",
            responderStarts: starts,
            responderEnds: ends,
            fallbackStart: "06:00"
        )
        XCTAssertEqual(fromEvent.start, "10:00")
        XCTAssertEqual(fromEvent.end, "11:00")
        let fromCrew = eventFormTimes(
            eventStart: nil,
            eventEnd: nil,
            responderStarts: starts,
            responderEnds: ends,
            fallbackStart: "06:00"
        )
        XCTAssertEqual(fromCrew.start, "07:30")
        XCTAssertEqual(fromCrew.end, "12:00")
        let empty = eventFormTimes(
            eventStart: nil,
            eventEnd: nil,
            responderStarts: [],
            responderEnds: [],
            fallbackStart: "06:00"
        )
        XCTAssertEqual(empty.start, "06:00")
        XCTAssertEqual(empty.end, "")
    }
}
