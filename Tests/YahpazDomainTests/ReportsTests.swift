import XCTest
@testable import YahpazDomain

final class ReportsTests: XCTestCase {
    func testShiftLeadSeesUnitReportsButNotTheAdminOnes() {
        let ids = visibleReportSpecs(["shift_lead"]).map(\.id)
        XCTAssertTrue(ids.contains(.openDocumentation))
        XCTAssertTrue(ids.contains(.eventsByResponder))
        XCTAssertTrue(ids.contains(.kmExceptions))
        XCTAssertTrue(ids.contains(.duplicateEvents))
        XCTAssertFalse(ids.contains(.kmDiscrepancy))
        XCTAssertFalse(ids.contains(.fuelRefund))
    }

    func testAdminSeesEveryReport() {
        XCTAssertEqual(REPORT_SPECS.count, visibleReportSpecs(["admin"]).count)
    }

    func testPlainResponderSeesNoReports() {
        XCTAssertTrue(visibleReportSpecs(["responder"]).isEmpty)
    }

    func testRollingReportsDefaultToThirtyDaysBack() {
        let range = defaultReportRange(spec: reportSpec(.eventsByResponder), today: "2026-03-15")
        XCTAssertEqual(range.0, "2026-02-13")
        XCTAssertEqual(range.1, "2026-03-15")
    }

    func testFuelRefundDefaultsToTheFirstOfTheMonth() {
        let range = defaultReportRange(spec: reportSpec(.fuelRefund), today: "2026-03-15")
        XCTAssertEqual(range.0, "2026-03-01")
        XCTAssertEqual(range.1, "2026-03-15")
    }

    func testRangeValidationRejectsReversedAndEmptyDays() {
        XCTAssertTrue(isValidReportRange("2026-01-01", "2026-01-01"))
        XCTAssertFalse(isValidReportRange("2026-02-01", "2026-01-01"))
        XCTAssertFalse(isValidReportRange("", "2026-01-01"))
    }

    func testReportFilterMatchesSearchTextAndHebrewKeyboardSlips() {
        let rows = [
            ReportRow(id: "a", title: "דנה כהן", searchText: "דנה כהן 12345"),
            ReportRow(id: "b", title: "יוסי לוי", searchText: "יוסי לוי 99999"),
        ]
        XCTAssertEqual(filterReportRows(rows, query: "12345").map(\.id), ["a"])
        // `s` maps to `ד` on a Hebrew keyboard.
        XCTAssertEqual(filterReportRows(rows, query: "sbv").map(\.id), ["a"])
        XCTAssertEqual(filterReportRows(rows, query: "   ").count, 2)
    }

    func testPersonAndPlaceDisplaysDropBlanks() {
        XCTAssertEqual(personDisplay("דנה כהן", callsign: "12"), "דנה כהן · 12")
        XCTAssertEqual(personDisplay("דנה כהן", callsign: "  "), "דנה כהן")
        XCTAssertEqual(personDisplay(nil, callsign: nil), "מתנדב")
        XCTAssertEqual(personDisplay(nil, callsign: nil, fallback: ""), "")
        XCTAssertEqual(placeDisplay("כביש 6", "צומת"), "כביש 6 · צומת")
        XCTAssertEqual(placeDisplay(nil, ""), "")
    }

    func testPoliceLabelMarksCancelledEventsFirst() {
        XCTAssertEqual(policeEventLabel("55", isCancelled: true), "בוטל · 55")
        XCTAssertEqual(policeEventLabel(nil, isCancelled: true), "בוטל")
        XCTAssertEqual(policeEventLabel("55", isCancelled: false), "55")
        XCTAssertEqual(policeEventLabel("  ", isCancelled: false), "—")
    }

    func testOnlyTheAllTimeReportHidesItsDateRange() {
        XCTAssertEqual(
            REPORT_SPECS.filter { !$0.hasDateRange }.map(\.id),
            [.duplicateEvents]
        )
    }

    func testEverySpecIdResolvesAndIsUnique() {
        XCTAssertEqual(REPORT_SPECS.count, Set(REPORT_SPECS.map(\.id)).count)
        for spec in REPORT_SPECS {
            XCTAssertEqual(spec, reportSpec(spec.id))
            XCTAssertEqual(spec.id, ReportKindId.fromRaw(spec.id.rawValue))
        }
        XCTAssertNil(ReportKindId.fromRaw("cockpit"))
    }

    func testRowSummaryCountsInHebrew() {
        XCTAssertEqual(reportRowSummary(0), "אין שורות בדוח")
        XCTAssertEqual(reportRowSummary(1), "שורה אחת בדוח")
        XCTAssertEqual(reportRowSummary(4), "4 שורות בדוח")
    }
}
