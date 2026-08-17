import XCTest
@testable import YahpazDomain

final class MineInboxTests: XCTestCase {
    func testOpenMineSummary() {
        XCTAssertEqual(openMineSummary(count: 0, ready: true), "אין אירועים שממתינים לתיעוד.")
        XCTAssertEqual(openMineSummary(count: 1, ready: true), "יש לך אירוע אחד לתעד.")
        XCTAssertEqual(openMineSummary(count: 2, ready: true), "יש לך שני אירועים לתעד.")
        XCTAssertEqual(openMineSummary(count: 3, ready: true), "יש לך 3 אירועים לתעד.")
        XCTAssertEqual(openMineSummary(count: 0, ready: false), "טוען את הדיווחים שלך…")
    }

    func testPendingTabLabelIncludesCountOnlyWhenThereIsWork() {
        XCTAssertEqual(minePendingTabLabel(count: 0), "ממתינים לתיעוד")
        XCTAssertEqual(minePendingTabLabel(count: 3), "ממתינים לתיעוד 3")
    }

    func testLoggedTabLabel() {
        XCTAssertEqual(MINE_LOGGED_TAB_LABEL, "תועדו")
    }

    func testPendingEmptyCopy() {
        XCTAssertEqual(MINE_PENDING_EMPTY_TITLE, "אין אירועים שממתינים לתיעוד.")
        XCTAssertEqual(MINE_PENDING_EMPTY_CAPTION, "אירוע חדש יופיע כאן כשישויך אליך.")
        XCTAssertEqual(MINE_PENDING_EMPTY_VIEW_LOGGED, "לצפייה באירועים שתועדו")
    }

    func testMineEventMatchesQuery() {
        let event = MineSearchFields(
            policeEventId: "12-34",
            roadName: "כביש 1",
            location: "צומת גזר"
        )
        XCTAssertTrue(mineEventMatchesQuery(event, query: "גזר"))
        XCTAssertTrue(mineEventMatchesQuery(event, query: "12"))
        XCTAssertFalse(mineEventMatchesQuery(event, query: "איילון"))
    }

    func testPartitionPutsOpenParticipationsInPending() {
        let sections = partitionMineList(
            [
                MineListEvent(id: "a", date: "2026-08-17", participation: .pending),
                MineListEvent(id: "b", date: "2026-08-16", participation: .done),
                MineListEvent(id: "c", date: "2026-08-10", participation: .inProgress),
            ],
            today: "2026-08-17",
            windowsLoaded: 1
        )
        XCTAssertEqual(sections.pending.map(\.id), ["a", "c"])
        XCTAssertEqual(sections.logged.map(\.id), ["b"])
    }

    func testFillCtaLabels() {
        XCTAssertEqual(mineFillCtaLabel(.pending), "השלמת הפרטים שלי")
        XCTAssertEqual(mineFillCtaLabel(.inProgress), "המשך מילוי הפרטים")
        XCTAssertNil(mineFillCtaLabel(.done))
    }

    func testParticipationStampsForViewer() {
        XCTAssertEqual(participationStamp(.done, isViewer: true).label, "הושלם")
        XCTAssertEqual(participationStamp(.inProgress, isViewer: true).label, "טיוטה נשמרה")
        XCTAssertEqual(participationStamp(.pending, isViewer: true).label, "ממתין למילוי פרטים")
    }
}
