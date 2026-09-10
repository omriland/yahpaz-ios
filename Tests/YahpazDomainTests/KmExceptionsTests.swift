import XCTest
@testable import YahpazDomain

final class KmExceptionsTests: XCTestCase {
    private func event(
        id: String,
        date: String,
        responders: [KmExceptionResponderInput]
    ) -> KmExceptionEventInput {
        KmExceptionEventInput(
            id: id,
            eventDate: date,
            policeEventId: "P-\(id)",
            location: "צומת",
            eventTypeName: "תקר",
            roadName: "6",
            leadName: "רון אחמש",
            leadCallsign: "A1",
            responders: responders
        )
    }

    func testOnlyKmAtOrAboveTheThresholdCount() {
        let rows = buildKmExceptionRows([
            event(
                id: "e1",
                date: "2026-02-02",
                responders: [
                    KmExceptionResponderInput(totalKm: 59.9, name: "מתחת", callsign: "1"),
                    KmExceptionResponderInput(totalKm: 60.0, name: "בדיוק", callsign: "2"),
                    KmExceptionResponderInput(totalKm: 120.0, name: "מעל", callsign: "3"),
                    KmExceptionResponderInput(totalKm: nil, name: "בלי ק״מ", callsign: "4"),
                ]
            ),
        ])
        XCTAssertEqual(rows.map(\.responderName), ["מעל", "בדיוק"])
    }

    func testRowsSortByNewestDateThenLargestKm() {
        let rows = buildKmExceptionRows([
            event(id: "old", date: "2026-01-01", responders: [KmExceptionResponderInput(totalKm: 200.0, name: "א", callsign: "1")]),
            event(id: "new", date: "2026-02-01", responders: [KmExceptionResponderInput(totalKm: 70.0, name: "ב", callsign: "2")]),
            event(id: "new2", date: "2026-02-01", responders: [KmExceptionResponderInput(totalKm: 90.0, name: "ג", callsign: "3")]),
        ])
        XCTAssertEqual(rows.map(\.responderName), ["ג", "ב", "א"])
    }

    func testRangeBoundsAreInclusiveAndOptional() {
        let events = [
            event(id: "in", date: "2026-02-10", responders: [KmExceptionResponderInput(totalKm: 90.0)]),
            event(id: "early", date: "2026-01-31", responders: [KmExceptionResponderInput(totalKm: 90.0)]),
        ]
        XCTAssertEqual(buildKmExceptionRows(events, from: "2026-02-01", to: "2026-02-28").map(\.eventId), ["in"])
        XCTAssertEqual(buildKmExceptionRows(events).count, 2)
    }

    func testReportRowsShowGroupedKmAndUniqueIds() {
        let rows = kmExceptionReportRows(
            buildKmExceptionRows([
                event(
                    id: "e1",
                    date: "2026-02-02",
                    responders: [
                        KmExceptionResponderInput(totalKm: 1500.0, name: "דנה כהן", callsign: "12"),
                        KmExceptionResponderInput(totalKm: 1500.0, name: "יוסי לוי", callsign: "12"),
                    ]
                ),
            ])
        )
        XCTAssertEqual(Set(rows.map(\.id)).count, 2)
        XCTAssertEqual(rows[0].trailing, "1,500 ק״מ")
        XCTAssertTrue(rows[0].detail!.contains("6"))
    }
}
