import XCTest
@testable import YahpazDomain

final class KmDiscrepancyTests: XCTestCase {
    private func responder(
        id: String,
        status: ParticipationStatus = .done,
        totalKm: Double? = 40.0,
        start: Double? = 1_000.0,
        end: Double? = 1_050.0,
        name: String = "דנה כהן"
    ) -> KmDiscrepancyResponderInput {
        KmDiscrepancyResponderInput(
            assignmentId: id,
            status: status,
            totalKm: totalKm,
            odometerStart: start,
            odometerEnd: end,
            name: name,
            callsign: "12"
        )
    }

    private func event(
        id: String,
        date: String = "2026-03-10",
        responders: [KmDiscrepancyResponderInput]
    ) -> KmDiscrepancyEventInput {
        KmDiscrepancyEventInput(
            id: id,
            eventDate: date,
            policeEventId: "555",
            location: "צומת",
            roadName: "כביש 6",
            leadName: "יוסי לוי",
            leadCallsign: "7",
            responders: responders
        )
    }

    func testAGapBetweenLeadKmAndTheOdometerBecomesARow() {
        let rows = buildKmDiscrepancyRows([event(id: "e1", responders: [responder(id: "a")])])
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].leadKm, 40.0)
        XCTAssertEqual(rows[0].responderKm, 50.0)
        XCTAssertEqual(rows[0].diff, 10.0)
    }

    func testAlignedUnreportedAndUnfinishedParticipationsAreSkipped() {
        let rows = buildKmDiscrepancyRows([
            event(id: "aligned", responders: [responder(id: "a", totalKm: 50.0)]),
            event(id: "noLeadKm", responders: [responder(id: "b", totalKm: nil)]),
            event(id: "noOdometer", responders: [responder(id: "c", end: nil)]),
            event(id: "openDoc", responders: [responder(id: "d", status: .inProgress)]),
        ])
        XCTAssertTrue(rows.isEmpty)
    }

    func testRowsHonourTheRequestedRange() {
        let events = [
            event(id: "old", date: "2026-01-01", responders: [responder(id: "a")]),
            event(id: "new", date: "2026-03-10", responders: [responder(id: "b")]),
        ]
        let rows = buildKmDiscrepancyRows(events, from: "2026-02-01", to: "2026-03-31")
        XCTAssertEqual(rows.map(\.eventId), ["new"])
    }

    func testSortIsNewestFirstThenTheWidestGap() {
        let events = [
            event(
                id: "same-day",
                responders: [
                    responder(id: "small", end: 1_005.0, name: "אבי"),
                    responder(id: "big", end: 1_200.0, name: "בני"),
                ]
            ),
            event(id: "older", date: "2026-03-01", responders: [responder(id: "older")]),
        ]
        let rows = buildKmDiscrepancyRows(events)
        XCTAssertEqual(rows.map(\.assignmentId), ["big", "small", "older"])
    }

    func testReplacementResolvesToTheOdometerDifference() {
        XCTAssertEqual(
            resolveLeadKmReplacement(totalKm: 40.0, odometerStart: 1_000.0, odometerEnd: 1_050.0),
            .replace(totalKm: 50.0)
        )
        XCTAssertEqual(
            resolveLeadKmReplacement(totalKm: 50.0, odometerStart: 1_000.0, odometerEnd: 1_050.0),
            .alreadyAligned
        )
        XCTAssertEqual(
            resolveLeadKmReplacement(totalKm: nil, odometerStart: 1_000.0, odometerEnd: 1_050.0),
            .invalid
        )
        XCTAssertEqual(
            resolveLeadKmReplacement(totalKm: 40.0, odometerStart: nil, odometerEnd: 1_050.0),
            .invalid
        )
    }

    func testReportRowsCarryTheApplyActionAndAreSearchable() {
        let rows = kmDiscrepancyReportRows(
            buildKmDiscrepancyRows([event(id: "e1", responders: [responder(id: "a")])])
        )
        XCTAssertEqual(rows.count, 1)
        let row = rows[0]
        XCTAssertEqual(row.title, "דנה כהן · 12")
        XCTAssertEqual(row.actionId, "a")
        XCTAssertEqual(row.actionTitle, "החלפה ל־50 ק״מ")
        XCTAssertNotNil(row.actionConfirm)
        XCTAssertEqual(row.trailing, "אחמ״ש 40 · מתנדב 50 · פער 10")
        XCTAssertEqual(filterReportRows(rows, query: "555"), [row])
        XCTAssertEqual(filterReportRows(rows, query: "צומת"), [row])
    }

    func testKmDiscrepancyIsAdminOnlyAndKeepsADateRange() {
        let spec = reportSpec(.kmDiscrepancy)
        XCTAssertEqual(spec.audience, .admin)
        XCTAssertTrue(spec.hasDateRange)
    }
}
