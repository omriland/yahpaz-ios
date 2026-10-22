import XCTest
@testable import YahpazDomain

final class StatusTests: XCTestCase {
    func testDoneWithMissingKmIsAlertStampForLeadReporting() {
        XCTAssertEqual(
            reportingDocumentationStamp(.done, missingKm: true),
            StampDescriptor(label: MISSING_KM_STAMP_LABEL, tone: .alert)
        )
    }

    func testDoneWithKmFilledStaysCompleted() {
        XCTAssertEqual(
            reportingDocumentationStamp(.done, missingKm: false),
            eventStamp(.done)
        )
    }

    func testPartialWithMissingKmIsNotOverridden() {
        XCTAssertEqual(
            reportingDocumentationStamp(.partial, missingKm: true),
            eventStamp(.partial)
        )
    }

    func testOverlaysOnlyAGreenCompletedStamp() {
        XCTAssertEqual(
            overlayMissingKmOnDoneStamp(StampDescriptor(label: "הושלם", tone: .done), missingKm: true),
            StampDescriptor(label: MISSING_KM_STAMP_LABEL, tone: .alert)
        )
        XCTAssertEqual(
            overlayMissingKmOnDoneStamp(StampDescriptor(label: "טיוטה נשמרה", tone: .draft), missingKm: true),
            StampDescriptor(label: "טיוטה נשמרה", tone: .draft)
        )
    }

    func testCompletedFillWithNoLeadKmShowsFinishedAndNotesTheLead() {
        XCTAssertEqual(leadKmPendingNote(.done, totalKm: nil), LEAD_KM_PENDING_NOTE)
        XCTAssertNil(leadKmPendingNote(.done, totalKm: 0))
        XCTAssertNil(leadKmPendingNote(.inProgress, totalKm: nil))
        XCTAssertTrue(mineInboxIsOpen(.done, totalKm: nil))
        XCTAssertFalse(mineInboxIsOpen(.done, totalKm: 12))
        XCTAssertEqual(
            mineParticipationStamp(.done, totalKm: nil),
            StampDescriptor(label: FILL_DONE_AWAITING_KM_LABEL, tone: .done)
        )
        XCTAssertEqual(FILL_DONE_AWAITING_KM_LABEL, "סיימת לתעד")
        XCTAssertEqual(mineParticipationStamp(.done, totalKm: 12), StampDescriptor(label: "הושלם", tone: .done))
    }

    func testCompletedFillWithMissingLeadEndTimeIsPartial() {
        XCTAssertTrue(eventMissingLeadDoneDetails(endedAt: nil))
        XCTAssertFalse(eventMissingLeadDoneDetails(endedAt: "2026-09-10T11:13:00"))
        XCTAssertEqual(
            mineParticipationStamp(.done, totalKm: 9, missingLeadDetails: true),
            eventStamp(.partial)
        )
        XCTAssertEqual(
            leadKmPendingNote(.done, totalKm: 9, origin: "manual", missingLeadDetails: true),
            AWAITING_LEAD_DETAILS_NOTE
        )
        XCTAssertEqual(AWAITING_LEAD_DETAILS_NOTE, "ממתין לפרטים נוספים מאחמש")
        XCTAssertEqual(
            mineParticipationStamp(.done, totalKm: 9, missingLeadDetails: false),
            StampDescriptor(label: "הושלם", tone: .done)
        )
    }

    func testShiftBornEventsNeverCarryALeadNote() {
        XCTAssertNil(leadKmPendingNote(.done, totalKm: nil, origin: "shift"))
        XCTAssertNil(leadKmPendingNote(.done, totalKm: nil, origin: "shift", missingLeadDetails: true))
    }
}
