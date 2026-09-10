import XCTest

/// Focused probe for "tapping a pending event card does nothing".
///
/// `MineCard` wires its inner button to `onOpen`, which sets `detailEvent` and should
/// present a sheet. The full sweep saw the tap land with no sheet, so this test isolates
/// the interaction: tree before, one tap, poll for the sheet, tree after.
final class InboxCardTests: QACase {

    func test01_PendingCardOpensDetailSheet() throws {
        try requireSignedIn()
        guard open(tab: "האירועים שלי") else {
            XCTFail("Inbox tab never appeared")
            return
        }
        sleep(2)
        dumpTree("A0-inbox-before")

        let card = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "אחמ״ש טרם הזין")
        ).firstMatch
        guard card.waitForExistence(timeout: 5) else {
            snapshot("A1-no-pending-card")
            throw XCTSkip("No pending card in this account right now.")
        }

        let frame = card.frame
        XCTAssertTrue(card.isHittable, "Card exists but is not hittable: \(frame)")
        card.tap()

        // The detail sheet's only guaranteed control is its סגירה dismiss button.
        let sheetClose = app.buttons["סגירה"]
        let appeared = sheetClose.waitForExistence(timeout: 6)

        snapshot("A2-after-card-tap")
        dumpTree("A2-inbox-after")

        if appeared {
            snapshot("A3-detail-sheet")
            sheetClose.tap()
        } else {
            // Second attempt at the exact geometric centre, to separate "hit-test misses the
            // button" from "the button fires and the sheet never presents".
            card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            let second = sheetClose.waitForExistence(timeout: 6)
            snapshot("A4-after-coordinate-tap")
            if second {
                sheetClose.tap()
                XCTFail("Card only opened on the second tap — first tap was swallowed.")
            } else {
                XCTFail("Card tap never presents the detail sheet. Frame: \(frame)")
            }
        }
    }
}
