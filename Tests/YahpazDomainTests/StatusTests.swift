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

    func testCompletedFillWithNoLeadKmKeepsCompletedAndNotesTheLead() {
        XCTAssertEqual(leadKmPendingNote(.done, totalKm: nil), LEAD_KM_PENDING_NOTE)
        XCTAssertNil(leadKmPendingNote(.done, totalKm: 0))
        XCTAssertNil(leadKmPendingNote(.inProgress, totalKm: nil))
        XCTAssertTrue(mineInboxIsOpen(.done, totalKm: nil))
        XCTAssertFalse(mineInboxIsOpen(.done, totalKm: 12))
    }
}
