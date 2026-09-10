import XCTest
@testable import YahpazDomain

final class OpenDocumentationTests: XCTestCase {
    private func event(
        id: String,
        date: String,
        status: EventStatus = .inProgress,
        cancelled: Bool = false,
        leadId: String = "lead-1",
        responders: [OpenDocResponderInput] = [
            OpenDocResponderInput(responderId: "r-1", status: .pending, name: "דנה כהן", callsign: "12"),
        ]
    ) -> OpenDocEventInput {
        OpenDocEventInput(
            id: id,
            eventDate: date,
            status: status,
            isCancelled: cancelled,
            shiftLeadId: leadId,
            leadName: "אופר לוי",
            leadCallsign: "7",
            responders: responders
        )
    }

    func testOnlyOpenEventsAndOpenParticipationsProduceRows() {
        let rows = buildOpenDocRows(
            events: [
                event(id: "e-1", date: "2026-08-10"),
                event(id: "e-2", date: "2026-08-11", status: .done),
                event(id: "e-3", date: "2026-08-12", cancelled: true),
                event(
                    id: "e-4",
                    date: "2026-08-13",
                    responders: [OpenDocResponderInput(responderId: "r-9", status: .done)]
                ),
            ],
            from: "2026-08-01",
            to: "2026-08-31",
            viewerId: "lead-1",
            viewerIsAdmin: false
        )
        XCTAssertEqual(rows.map(\.eventId), ["e-1"])
        XCTAssertEqual(rows[0].fillStatusLabel, "טרם הוזן")
        XCTAssertEqual(rows[0].responderDisplay, "דנה כהן · 12")
        XCTAssertEqual(rows[0].leadDisplay, "אופר לוי · 7")
    }

    func testALeadSeesOnlyTheirOwnEventsWhileAnAdminSeesAll() {
        let events = [
            event(id: "mine", date: "2026-08-10"),
            event(id: "theirs", date: "2026-08-11", leadId: "lead-2"),
        ]
        let leadRows = buildOpenDocRows(
            events: events,
            from: "2026-08-01",
            to: "2026-08-31",
            viewerId: "lead-1",
            viewerIsAdmin: false
        )
        XCTAssertEqual(leadRows.map(\.eventId), ["mine"])
        let adminRows = buildOpenDocRows(
            events: events,
            from: "2026-08-01",
            to: "2026-08-31",
            viewerId: "lead-1",
            viewerIsAdmin: true
        )
        XCTAssertEqual(adminRows.map(\.eventId), ["theirs", "mine"])
    }

    func testRowsOutsideTheRangeAreDroppedAndDraftsAreLabelled() {
        let rows = buildOpenDocRows(
            events: [
                event(id: "old", date: "2026-07-01"),
                event(
                    id: "draft",
                    date: "2026-08-10",
                    status: .partial,
                    responders: [
                        OpenDocResponderInput(responderId: "r-2", status: .inProgress, name: "רון", callsign: "3"),
                    ]
                ),
            ],
            from: "2026-08-01",
            to: "2026-08-31",
            viewerId: "lead-1",
            viewerIsAdmin: true
        )
        XCTAssertEqual(rows.map(\.eventId), ["draft"])
        XCTAssertEqual(rows[0].fillStatusLabel, "נשמרה טיוטה")
        XCTAssertEqual(rows[0].id, "draft:r-2")
    }

    func testSummaryCountsInHebrew() {
        XCTAssertFalse(openDocSummary(0).isEmpty)
        XCTAssertEqual(openDocSummary(1), "דיווח אחד ממתין לתיעוד")
        XCTAssertEqual(openDocSummary(4), "4 דיווחים ממתינים לתיעוד")
    }
}
