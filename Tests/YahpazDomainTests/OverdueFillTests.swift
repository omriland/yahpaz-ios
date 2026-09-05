import XCTest
@testable import YahpazDomain

final class OverdueFillTests: XCTestCase {
    private let t0 = "2026-08-16T10:00:00.000Z"
    private var t0Ms: Int64 {
        Int64(ISO8601DateFormatter().date(from: "2026-08-16T10:00:00Z")!.timeIntervalSince1970 * 1000)
    }

    func testOverdueCardTip() {
        XCTAssertEqual(OVERDUE_FILL_CARD_TIP, "אירוע ממתין לתיעוד מעל ל־48 שעות")
    }

    func testNotOverdueBefore48Hours() {
        XCTAssertFalse(
            isMineFillOverdue(
                isCancelled: false,
                participationStatus: .pending,
                fillCompletableAt: t0,
                nowMs: t0Ms + OVERDUE_48H_MS - 1
            )
        )
    }

    func testOverdueAt48HoursForOpenParticipation() {
        XCTAssertTrue(
            isMineFillOverdue(
                isCancelled: false,
                participationStatus: .inProgress,
                fillCompletableAt: t0,
                nowMs: t0Ms + OVERDUE_48H_MS
            )
        )
    }

    func testNotOverdueWhenDoneCancelledOrNotCompletable() {
        let now = t0Ms + OVERDUE_48H_MS
        XCTAssertFalse(
            isMineFillOverdue(
                isCancelled: false,
                participationStatus: .done,
                fillCompletableAt: t0,
                nowMs: now
            )
        )
        XCTAssertFalse(
            isMineFillOverdue(
                isCancelled: true,
                participationStatus: .pending,
                fillCompletableAt: t0,
                nowMs: now
            )
        )
        XCTAssertFalse(
            isMineFillOverdue(
                isCancelled: false,
                participationStatus: .pending,
                fillCompletableAt: nil,
                nowMs: now
            )
        )
    }
}
