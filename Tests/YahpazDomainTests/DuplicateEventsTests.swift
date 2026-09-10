import XCTest
@testable import YahpazDomain

final class DuplicateEventsTests: XCTestCase {
    private func participation(
        eventId: String,
        responderId: String = "r1",
        date: String = "2026-04-02",
        location: String? = "מחלף גלילות",
        startedAt: String? = "2026-04-02T08:00:00"
    ) -> DuplicateParticipation {
        DuplicateParticipation(
            eventId: eventId,
            responderId: responderId,
            eventDate: date,
            location: location,
            startedAt: startedAt,
            policeEventId: "900\(eventId)",
            eventTypeName: "פינוי",
            roadName: "כביש 2",
            name: "דנה כהן",
            callsign: "12"
        )
    }

    func testTwoEventsWithinTheWindowClusterAsAPair() {
        let clusters = buildDuplicateClusters([
            participation(eventId: "a"),
            participation(eventId: "b", startedAt: "2026-04-02T08:20:00"),
        ])
        XCTAssertEqual(clusters.count, 1)
        XCTAssertEqual(clusters[0].sizeLabel, "כפול")
        XCTAssertEqual(clusters[0].members.map(\.eventId), ["a", "b"])
    }

    func testMatchingIsTransitiveSoAChainBecomesOneTriple() {
        let clusters = buildDuplicateClusters([
            participation(eventId: "a", startedAt: "2026-04-02T08:00:00"),
            participation(eventId: "b", startedAt: "2026-04-02T08:25:00"),
            participation(eventId: "c", startedAt: "2026-04-02T08:50:00"),
        ])
        XCTAssertEqual(clusters.count, 1)
        XCTAssertEqual(clusters[0].sizeLabel, "משולש")
        XCTAssertEqual(clusters[0].members.count, 3)
    }

    func testOutsideTheWindowAnotherResponderOrAnotherPlaceIsNotADuplicate() {
        XCTAssertTrue(
            buildDuplicateClusters([
                participation(eventId: "a"),
                participation(eventId: "b", startedAt: "2026-04-02T09:01:00"),
            ]).isEmpty
        )
        XCTAssertTrue(
            buildDuplicateClusters([
                participation(eventId: "a"),
                participation(eventId: "b", responderId: "r2"),
            ]).isEmpty
        )
        XCTAssertTrue(
            buildDuplicateClusters([
                participation(eventId: "a"),
                participation(eventId: "b", location: "מחלף חולון"),
            ]).isEmpty
        )
        XCTAssertTrue(
            buildDuplicateClusters([
                participation(eventId: "a"),
                participation(eventId: "b", date: "2026-04-03"),
            ]).isEmpty
        )
    }

    func testAMissingPlaceOrStartTimeCannotMatch() {
        XCTAssertTrue(
            buildDuplicateClusters([
                participation(eventId: "a", location: "   "),
                participation(eventId: "b", location: nil),
            ]).isEmpty
        )
        XCTAssertTrue(
            buildDuplicateClusters([
                participation(eventId: "a", startedAt: nil),
                participation(eventId: "b", startedAt: nil),
            ]).isEmpty
        )
    }

    func testLocationWhitespaceDoesNotBreakAMatch() {
        let clusters = buildDuplicateClusters([
            participation(eventId: "a", location: " מחלף גלילות "),
            participation(eventId: "b", startedAt: "2026-04-02T08:10:00"),
        ])
        XCTAssertEqual(clusters.count, 1)
    }

    func testClustersSortNewestFirstAndTriplesBeforePairs() {
        let clusters = buildDuplicateClusters([
            participation(eventId: "old1", date: "2026-03-01", startedAt: "2026-03-01T07:00:00"),
            participation(eventId: "old2", date: "2026-03-01", startedAt: "2026-03-01T07:10:00"),
            participation(eventId: "new1"),
            participation(eventId: "new2", startedAt: "2026-04-02T08:10:00"),
        ])
        XCTAssertEqual(clusters.count, 2)
        XCTAssertEqual(clusters[0].eventDate, "2026-04-02")
        XCTAssertEqual(clusters[1].eventDate, "2026-03-01")
    }

    func testReportRowsStampTheClusterSizeAndStaySearchable() {
        let rows = duplicateEventsReportRows(
            buildDuplicateClusters([
                participation(eventId: "a"),
                participation(eventId: "b", startedAt: "2026-04-02T08:20:00"),
            ])
        )
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].title, "דנה כהן · 12")
        XCTAssertEqual(rows[0].subtitle, "02.04.2026 · 08:00 · פינוי")
        XCTAssertEqual(rows[0].stampLabel, "כפול")
        XCTAssertEqual(rows[0].detail, "כביש 2 · מחלף גלילות · 900a")
        XCTAssertEqual(filterReportRows(rows, query: "גלילות").count, 2)
        XCTAssertEqual(filterReportRows(rows, query: "900b").count, 1)
    }

    func testDuplicateEventsIsOpenToShiftLeadsAndHidesTheDateRange() {
        let spec = reportSpec(.duplicateEvents)
        XCTAssertEqual(spec.audience, .managesUnit)
        XCTAssertFalse(spec.hasDateRange)
    }

    func testWallTimeFormattingReadsTheStringWithoutShiftingZones() {
        XCTAssertEqual(formatTime("2026-04-02T08:00:00"), "08:00")
        XCTAssertEqual(formatTime("2026-04-02 08:00:00+03"), "08:00")
        XCTAssertNil(formatTime(nil))
        XCTAssertNil(formatTime("   "))
    }
}
