import XCTest
@testable import YahpazDomain

final class EventIncompleteTests: XCTestCase {
    private func responder(
        totalKm: Double? = 12.0,
        startedAt: String? = "2026-09-04T06:00:00+03:00",
        endedAt: String? = "2026-09-04T07:00:00+03:00"
    ) -> IncompleteResponderSnapshot {
        IncompleteResponderSnapshot(totalKm: totalKm, startedAt: startedAt, endedAt: endedAt)
    }

    private func event(
        policeEventId: String? = "12345",
        patrolCallsign: String? = "ניידת 1",
        hasDistrict: Bool = true,
        hasEventType: Bool = true,
        hasRoad: Bool = true,
        location: String? = "מחלף אייל",
        responders: [IncompleteResponderSnapshot]? = nil
    ) -> IncompleteEventSnapshot {
        IncompleteEventSnapshot(
            policeEventId: policeEventId,
            patrolCallsign: patrolCallsign,
            hasDistrict: hasDistrict,
            hasEventType: hasEventType,
            hasRoad: hasRoad,
            location: location,
            responders: responders ?? [responder()]
        )
    }

    func testCompleteEventHasNoMissingFields() {
        XCTAssertEqual(missingEventFields(event()), [])
        XCTAssertFalse(isEventIncomplete(event()))
    }

    func testFlagsEachEventLevelRequiredField() {
        XCTAssertEqual(missingEventFields(event(policeEventId: nil)), [.policeEventId])
        XCTAssertEqual(missingEventFields(event(policeEventId: "   ")), [.policeEventId])
        XCTAssertEqual(missingEventFields(event(patrolCallsign: nil)), [.patrolCallsign])
        XCTAssertEqual(missingEventFields(event(hasDistrict: false)), [.district])
        XCTAssertEqual(missingEventFields(event(hasEventType: false)), [.eventType])
        XCTAssertEqual(missingEventFields(event(hasRoad: false)), [.road])
        XCTAssertEqual(missingEventFields(event(location: nil)), [.location])
        XCTAssertEqual(missingEventFields(event(location: "  ")), [.location])
    }

    func testKmZeroCountsAsFilledAndNullIsMissing() {
        XCTAssertEqual(missingEventFields(event(responders: [responder(totalKm: nil)])), [.responderKm])
        XCTAssertTrue(eventHasMissingResponderKm(event(responders: [responder(totalKm: nil)])))
        XCTAssertEqual(missingEventFields(event(responders: [responder(totalKm: 0.0)])), [])
        XCTAssertFalse(eventHasMissingResponderKm(event(responders: [responder(totalKm: 0.0)])))
        XCTAssertEqual(missingEventFields(event(responders: [responder(), responder(totalKm: nil)])), [.responderKm])
    }

    func testFlagsTimesWhenAnyResponderIsMissingStartOrEnd() {
        XCTAssertEqual(missingEventFields(event(responders: [responder(startedAt: nil)])), [.responderTimes])
        XCTAssertEqual(missingEventFields(event(responders: [responder(endedAt: "  ")])), [.responderTimes])
    }

    func testStillFlagsEventsWaitingForDocumentation() {
        XCTAssertTrue(isEventIncomplete(event(policeEventId: nil)))
    }

    func testHebrewLabelsStayShortAndOrdered() {
        let fields: Set<IncompleteField> = [.responderKm, .policeEventId]
        XCTAssertEqual(incompleteFieldLabels(fields), ["מספר אירוע", "ק״מ"])
        XCTAssertEqual(incompleteNoticeLabel(fields), "חסרים: מספר אירוע · ק״מ")
        XCTAssertEqual(INCOMPLETE_FIELD_LABELS[.responderKm], "ק״מ")
        XCTAssertEqual(INCOMPLETE_FIELD_LABELS[.responderTimes], "שעות")
        XCTAssertEqual(INCOMPLETE_EVENTS_HEADING, "דורשים השלמת פרטים")
        XCTAssertEqual(INCOMPLETE_NOTICE_MARK, "פרטים חסרים:")
    }

    func testPartitionPinsIncompleteFirstAndKeepsInputOrder() {
        let complete = ("ok", event())
        let incomplete = ("gap", event(location: nil))
        let parts = partitionIncompleteEvents([complete, incomplete]) { $0.1 }
        XCTAssertEqual(parts.incomplete.map(\.0), ["gap"])
        XCTAssertEqual(parts.rest.map(\.0), ["ok"])
    }
}
