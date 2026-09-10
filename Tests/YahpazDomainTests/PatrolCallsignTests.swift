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

    func testEventTimesCopyOntoResponders() {
        let crew = [
            EventResponderDraft(responderId: "a", startTime: "08:00", endTime: "09:00"),
            EventResponderDraft(responderId: "b"),
        ]
        let next = applyEventTimesToResponders(crew, startTime: "10:15", endTime: "11:40")
        XCTAssertTrue(next.allSatisfy { $0.startTime == "10:15" && $0.endTime == "11:40" })
    }

    func testEventFormTimesPreferEventThenResponders() {
        let crew = [
            EventResponderDraft(responderId: "a", startTime: "08:00", endTime: "09:00"),
            EventResponderDraft(responderId: "b", startTime: "07:30", endTime: "12:00"),
        ]
        let fromEvent = eventFormTimes(
            eventStart: "2026-02-02T10:00:00",
            eventEnd: "2026-02-02T11:00:00",
            responders: crew,
            fallbackStart: "06:00"
        )
        XCTAssertEqual(fromEvent.start, "10:00")
        XCTAssertEqual(fromEvent.end, "11:00")
        let fromCrew = eventFormTimes(
            eventStart: nil,
            eventEnd: nil,
            responders: crew,
            fallbackStart: "06:00"
        )
        XCTAssertEqual(fromCrew.start, "07:30")
        XCTAssertEqual(fromCrew.end, "12:00")
        let empty = eventFormTimes(
            eventStart: nil,
            eventEnd: nil,
            responders: [],
            fallbackStart: "06:00"
        )
        XCTAssertEqual(empty.start, "06:00")
        XCTAssertEqual(empty.end, "")
    }
}
