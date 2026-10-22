import XCTest
@testable import YahpazDomain

final class EventEditLockTests: XCTestCase {
    private let now: Int64 = 1_789_027_200_000 // 2026-09-10T08:00:00Z

    private func iso(_ ms: Int64) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date(timeIntervalSince1970: Double(ms) / 1000))
    }

    func testLocksShiftLeadAfterMoreThanSevenDays() {
        XCTAssertTrue(isEventEditAgeLocked(createdAt: iso(now - EVENT_EDIT_LOCK_MS - 1), roles: ["shift_lead"], nowMs: now))
    }

    func testStaysOpenAtExactlySevenDays() {
        XCTAssertFalse(isEventEditAgeLocked(createdAt: iso(now - EVENT_EDIT_LOCK_MS), roles: ["shift_lead"], nowMs: now))
    }

    func testNeverLocksAdmin() {
        let created = iso(now - EVENT_EDIT_LOCK_MS * 3)
        XCTAssertFalse(isEventEditAgeLocked(createdAt: created, roles: ["admin"], nowMs: now))
        XCTAssertFalse(isEventEditAgeLocked(createdAt: created, roles: ["super_admin", "shift_lead"], nowMs: now))
    }

    func testReadsPostgresTimestamptzAndIgnoresBlanks() {
        XCTAssertTrue(isEventEditAgeLocked(createdAt: "2026-09-01T07:59:59.123456+00:00", roles: ["shift_lead"], nowMs: now))
        XCTAssertFalse(isEventEditAgeLocked(createdAt: "", roles: ["shift_lead"], nowMs: now))
        XCTAssertFalse(isEventEditAgeLocked(createdAt: nil, roles: ["shift_lead"], nowMs: now))
        XCTAssertEqual(EVENT_EDIT_LOCKED_TOOLTIP, "לא ניתן לערוך אירוע שנוצר לפני מעל ל-7 ימים")
    }
}
