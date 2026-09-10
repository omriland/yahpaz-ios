import XCTest
@testable import YahpazDomain

final class EventsByResponderTests: XCTestCase {
    private func event(
        id: String,
        date: String,
        responders: [EventsByResponderResponderInput],
        isCancelled: Bool = false
    ) -> EventsByResponderEventInput {
        EventsByResponderEventInput(
            id: id,
            eventDate: date,
            isCancelled: isCancelled,
            policeEventId: "P-\(id)",
            location: "צומת",
            eventTypeName: "תקר",
            districtName: "מרכז",
            roadName: "6",
            leadName: "רון אחמש",
            leadCallsign: "A1",
            responders: responders
        )
    }

    func testEachResponderBecomesItsOwnRow() {
        let rows = buildEventsByResponderRows(
            [
                event(
                    id: "e1",
                    date: "2026-02-02",
                    responders: [
                        EventsByResponderResponderInput(responderId: "r1", totalKm: 12.0, name: "דנה כהן", callsign: "12"),
                        EventsByResponderResponderInput(responderId: "r2", totalKm: nil, name: "יוסי לוי", callsign: "44"),
                    ]
                ),
            ],
            from: "2026-01-01",
            to: "2026-03-01"
        )
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows.map(\.id), ["e1:r1", "e1:r2"])
        XCTAssertEqual(rows[0].totalKm, 12.0)
        XCTAssertNil(rows[1].totalKm)
    }

    func testRowsSortByResponderThenNewestEventFirst() {
        let rows = buildEventsByResponderRows(
            [
                event(id: "e1", date: "2026-01-05", responders: [
                    EventsByResponderResponderInput(responderId: "r2", totalKm: 1.0, name: "יוסי לוי", callsign: "44"),
                ]),
                event(id: "e2", date: "2026-01-01", responders: [
                    EventsByResponderResponderInput(responderId: "r1", totalKm: 1.0, name: "דנה כהן", callsign: "12"),
                ]),
                event(id: "e3", date: "2026-01-09", responders: [
                    EventsByResponderResponderInput(responderId: "r1", totalKm: 1.0, name: "דנה כהן", callsign: "12"),
                ]),
            ],
            from: "2026-01-01",
            to: "2026-03-01"
        )
        XCTAssertEqual(rows.map(\.id), ["e3:r1", "e2:r1", "e1:r2"])
    }

    func testEventsOutsideTheRangeDropOut() {
        let rows = buildEventsByResponderRows(
            [
                event(id: "in", date: "2026-02-10", responders: [EventsByResponderResponderInput(responderId: "r1")]),
                event(id: "early", date: "2026-01-31", responders: [EventsByResponderResponderInput(responderId: "r1")]),
                event(id: "late", date: "2026-03-01", responders: [EventsByResponderResponderInput(responderId: "r1")]),
            ],
            from: "2026-02-01",
            to: "2026-02-28"
        )
        XCTAssertEqual(rows.map(\.id), ["in:r1"])
    }

    func testEventsWithNoRespondersContributeNothing() {
        let rows = buildEventsByResponderRows(
            [event(id: "e1", date: "2026-02-02", responders: [])],
            from: "2026-01-01",
            to: "2026-03-01"
        )
        XCTAssertTrue(rows.isEmpty)
    }

    func testReportRowsCarryKmPlaceAndCancelledStamp() {
        let rows = eventsByResponderReportRows(
            buildEventsByResponderRows(
                [
                    event(
                        id: "e1",
                        date: "2026-02-02",
                        responders: [
                            EventsByResponderResponderInput(responderId: "r1", totalKm: 1234.0, name: "דנה כהן", callsign: "12"),
                        ],
                        isCancelled: true
                    ),
                ],
                from: "2026-01-01",
                to: "2026-03-01"
            )
        )
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].title, "דנה כהן · 12")
        XCTAssertEqual(rows[0].trailing, "1,234 ק״מ")
        XCTAssertEqual(rows[0].stampLabel, "בוטל")
        XCTAssertEqual(rows[0].eventId, "e1")
        XCTAssertTrue(rows[0].subtitle.contains("02.02.2026"))
        XCTAssertTrue(rows[0].detail!.contains("אחמ״ש: A1 · רון אחמש"))
    }
}
