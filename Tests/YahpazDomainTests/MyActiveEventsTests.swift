import XCTest
@testable import YahpazDomain

final class MyActiveEventsTests: XCTestCase {
    func testEmptyActiveCopyIsTheLeadFacingLine() {
        XCTAssertEqual(MY_ACTIVE_EVENTS_EMPTY, "אין אירועים פעילים באחמו\"ש שלך")
    }

    func testAnyEventCanBeAddedToMyActive() {
        XCTAssertTrue(canAddEventToMyActive(isCancelled: false, status: .done))
        XCTAssertTrue(canAddEventToMyActive(isCancelled: true, status: .inProgress))
        XCTAssertTrue(canAddEventToMyActive(isCancelled: false, status: .draft))
    }

    func testCannotRemoveOwnDraftEvent() {
        XCTAssertFalse(
            canRemoveFromMyActive(viewerId: "lead", shiftLeadId: "lead", status: .draft, isCancelled: false)
        )
        XCTAssertTrue(
            canRemoveFromMyActive(viewerId: "lead", shiftLeadId: "lead", status: .inProgress, isCancelled: false)
        )
        XCTAssertTrue(
            canRemoveFromMyActive(viewerId: "lead", shiftLeadId: "other", status: .draft, isCancelled: false)
        )
        XCTAssertTrue(
            canRemoveFromMyActive(viewerId: "lead", shiftLeadId: "lead", status: .draft, isCancelled: true)
        )
    }

    func testVisibleActiveIsLockedThenAutoMinusHidesThenPins() {
        XCTAssertEqual(
            visibleMyActiveIds(
                lockedIds: ["lock"],
                autoIds: ["lock", "auto", "hidden"],
                pinnedIds: ["pin"],
                hiddenIds: ["hidden", "lock"]
            ),
            ["lock", "auto", "pin"]
        )
    }

    func testAddAndRemoveLabels() {
        XCTAssertEqual(MY_ACTIVE_ADD, "הוספה לפעילים")
        XCTAssertEqual(MY_ACTIVE_REMOVE, "הסרה")
        XCTAssertEqual(MY_ACTIVE_REMOVE_LOCKED, "אירוע בהזנה — לא ניתן להסיר")
        XCTAssertEqual(MY_ACTIVE_DRAG_TO_ACTIVE, "הוספה לפעילים, או לחיצה ארוכה וגרירה")
    }

    func testAutoActiveKeepsOpenLeadEventsUntilDoneOrCancelled() {
        XCTAssertTrue(isAutoOnMyActive(isCancelled: false, status: .draft))
        XCTAssertTrue(isAutoOnMyActive(isCancelled: false, status: .inProgress))
        XCTAssertTrue(isAutoOnMyActive(isCancelled: false, status: .partial))
        XCTAssertFalse(isAutoOnMyActive(isCancelled: false, status: .done))
        XCTAssertFalse(isAutoOnMyActive(isCancelled: true, status: .inProgress))
        XCTAssertFalse(isAutoOnMyActive(isCancelled: true, status: .draft))
        XCTAssertFalse(isAutoOnMyActive(isCancelled: true, status: .partial))
    }

    func testOptimisticAddPinsACatalogEventAndDropsHide() {
        XCTAssertEqual(
            prefsAfterAddToMyActive(
                prefs: [ActivePref(eventId: "keep", kind: "hide"), ActivePref(eventId: "new", kind: "hide")],
                eventId: "new",
                alreadyAuto: false
            ),
            [ActivePref(eventId: "keep", kind: "hide"), ActivePref(eventId: "new", kind: "pin")]
        )
    }

    func testOptimisticAddOfAnAutoEventOnlyClearsHide() {
        XCTAssertEqual(
            prefsAfterAddToMyActive(
                prefs: [ActivePref(eventId: "auto", kind: "hide"), ActivePref(eventId: "other", kind: "pin")],
                eventId: "auto",
                alreadyAuto: true
            ),
            [ActivePref(eventId: "other", kind: "pin")]
        )
    }

    func testFailedAddRestoresOnlyThatEventsPreviousPrefs() {
        XCTAssertEqual(
            prefsRestoringEvent(
                prefs: [ActivePref(eventId: "keep", kind: "pin"), ActivePref(eventId: "new", kind: "pin")],
                eventId: "new",
                previous: [ActivePref(eventId: "new", kind: "hide")]
            ),
            [ActivePref(eventId: "keep", kind: "pin"), ActivePref(eventId: "new", kind: "hide")]
        )
    }

    func testShiftLeadCanDeleteOnlyTheirOwnUnassignedEvent() {
        XCTAssertTrue(
            canDeleteUnassignedEvent(
                canManageUnit: true,
                responderCount: 0,
                viewerIsAdmin: false,
                viewerId: "lead-a",
                shiftLeadId: "lead-a"
            )
        )
        XCTAssertFalse(
            canDeleteUnassignedEvent(
                canManageUnit: true,
                responderCount: 0,
                viewerIsAdmin: false,
                viewerId: "lead-a",
                shiftLeadId: "lead-b"
            )
        )
        XCTAssertFalse(
            canDeleteUnassignedEvent(
                canManageUnit: true,
                responderCount: 1,
                viewerIsAdmin: false,
                viewerId: "lead-a",
                shiftLeadId: "lead-a"
            )
        )
        XCTAssertFalse(
            canDeleteUnassignedEvent(
                canManageUnit: false,
                responderCount: 0,
                viewerIsAdmin: false,
                viewerId: "lead-a",
                shiftLeadId: "lead-a"
            )
        )
    }

    func testAdminCanDeleteAnotherLeadsUnassignedEvent() {
        XCTAssertTrue(
            canDeleteUnassignedEvent(
                canManageUnit: true,
                responderCount: 0,
                viewerIsAdmin: true,
                viewerId: "admin",
                shiftLeadId: "lead-b"
            )
        )
        XCTAssertEqual(EVENT_DELETE_OTHER_LEAD, "אין הרשאה למחוק אירוע שנוצר על ידי אחמ״ש אחר.")
    }
}
