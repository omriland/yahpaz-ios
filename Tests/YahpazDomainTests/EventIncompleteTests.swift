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
        responders: [IncompleteResponderSnapshot]? = nil,
        startedAt: String? = nil,
        endedAt: String? = nil,
        origin: String? = nil
    ) -> IncompleteEventSnapshot {
        IncompleteEventSnapshot(
            origin: origin,
            policeEventId: policeEventId,
            patrolCallsign: patrolCallsign,
            startedAt: startedAt,
            endedAt: endedAt,
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

    func testCallsignWithoutANumberIsMissing() {
        XCTAssertEqual(missingEventFields(event(patrolCallsign: "אביב")), [.patrolCallsign])
        XCTAssertEqual(
            missingEventFields(IncompleteEventSnapshot(
                policeEventId: "12345",
                patrolCallsign: nil,
                patrolCallsignNumber: "411",
                hasDistrict: true,
                hasEventType: true,
                hasRoad: true,
                location: "מחלף אייל",
                responders: [responder()]
            )),
            []
        )
    }

    func testKmZeroCountsAsFilledAndNullIsMissing() {
        XCTAssertEqual(missingEventFields(event(responders: [responder(totalKm: nil)])), [.responderKm])
        XCTAssertTrue(eventHasMissingResponderKm(event(responders: [responder(totalKm: nil)])))
        XCTAssertEqual(missingEventFields(event(responders: [responder(totalKm: 0.0)])), [])
        XCTAssertFalse(eventHasMissingResponderKm(event(responders: [responder(totalKm: 0.0)])))
        XCTAssertEqual(missingEventFields(event(responders: [responder(), responder(totalKm: nil)])), [.responderKm])
    }

    func testFlagsTimesWhenAnyResponderIsMissingStartOrEnd() {
        XCTAssertEqual(missingEventFields(event(responders: [responder(startedAt: nil)])), [.eventTimes])
        XCTAssertEqual(missingEventFields(event(responders: [responder(endedAt: "  ")])), [.eventTimes])
    }

    func testEventLevelTimesWinOverResponderTimes() {
        XCTAssertEqual(
            missingEventFields(event(
                responders: [responder(startedAt: nil, endedAt: nil)],
                startedAt: "2026-09-04T06:00:00",
                endedAt: "2026-09-04T07:00:00"
            )),
            []
        )
        XCTAssertEqual(
            missingEventFields(event(
                responders: [responder()],
                startedAt: "2026-09-04T06:00:00",
                endedAt: nil
            )),
            [.eventTimes]
        )
    }

    func testStillFlagsEventsWaitingForDocumentation() {
        XCTAssertTrue(isEventIncomplete(event(policeEventId: nil)))
    }

    func testHebrewLabelsStayShortAndOrdered() {
        let fields: Set<IncompleteField> = [.responderKm, .policeEventId]
        XCTAssertEqual(incompleteFieldLabels(fields), ["מספר אירוע", "ק״מ"])
        XCTAssertEqual(incompleteNoticeLabel(fields), "חסרים: מספר אירוע · ק״מ")
        XCTAssertEqual(INCOMPLETE_FIELD_LABELS[.responderKm], "ק״מ")
        XCTAssertEqual(INCOMPLETE_FIELD_LABELS[.eventTimes], "שעות")
        XCTAssertEqual(INCOMPLETE_FIELD_LABELS[.patrolCallsign], "אוק - מס")
        XCTAssertEqual(INCOMPLETE_EVENTS_HEADING, "דורשים השלמת פרטים")
        XCTAssertEqual(INCOMPLETE_NOTICE_MARK, "פרטים חסרים:")
    }

    func testAddsNotSentMarkWhenVolunteersAreAssignedBeforeTheEventIsReleased() {
        XCTAssertEqual(incompleteLeadNoticeLabels(event(policeEventId: nil)), ["מספר אירוע", "לא נשלח למתנדבים"])
        XCTAssertEqual(incompleteLeadNoticeLabels(event(policeEventId: nil, responders: [])), ["מספר אירוע"])
        XCTAssertEqual(incompleteLeadNoticeLabels(event(hasRoad: false)), ["כביש", "לא נשלח למתנדבים"])
        XCTAssertEqual(incompleteLeadNoticeLabels(event(patrolCallsign: nil)), ["אוק - מס", "לא נשלח למתנדבים"])
        XCTAssertEqual(incompleteLeadNoticeLabels(event()), [])
        XCTAssertEqual(incompleteLeadNoticeLabels(event(policeEventId: nil, origin: "shift")), ["מספר אירוע"])
        XCTAssertEqual(
            RESPONDERS_HELD_FOR_POLICE_ID_NOTE,
            "האירוע לא יוצג למתנדב עד שאו״ק, כביש ומספר אירוע מלאים."
        )
    }

    func testPartitionPinsIncompleteFirstAndKeepsInputOrder() {
        let complete = ("ok", event())
        let incomplete = ("gap", event(location: nil))
        let parts = partitionIncompleteEvents([complete, incomplete]) { $0.1 }
        XCTAssertEqual(parts.incomplete.map(\.0), ["gap"])
        XCTAssertEqual(parts.rest.map(\.0), ["ok"])
    }
}
