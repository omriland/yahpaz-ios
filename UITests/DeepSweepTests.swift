import XCTest

/// Opens the forms, sheets and detail screens behind the tab bar, using the labels read
/// off the real accessibility trees.
///
/// READ-ONLY: `QACase.tapIfPresent` refuses destructive labels, and nothing here submits.
final class DeepSweepTests: QACase {
    func test10_EventForm() throws {
        try requireSignedIn()
        guard open(tab: "אירועים") else { return }
        sleep(2)

        guard tapButton(startingWith: "אירוע חדש") else {
            snapshot("60-event-form-NOT-OPENED")
            return
        }
        sleep(2)
        snapshot("61-event-form")
        probeTextFields(prefix: "62-event-form-field")
        snapshot("63-event-form-after-typing")
        cancelForm()
    }

    func test11_ShiftForm() throws {
        try requireSignedIn()
        guard open(tab: "משמרות") else { return }
        sleep(2)

        guard tapButton(startingWith: "משמרת חדשה") else {
            snapshot("64-shift-form-NOT-OPENED")
            return
        }
        sleep(2)
        snapshot("65-shift-form")
        probeTextFields(prefix: "66-shift-form-field")
        cancelForm()
    }

    /// Opens an event card from the inbox. Card labels start with the event type, so match
    /// on the pending-documentation note instead of tapping by index.
    func test12_InboxCardAndFill() throws {
        try requireSignedIn()
        guard open(tab: "האירועים שלי") else { return }
        sleep(2)

        let card = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "הושלם")
        ).firstMatch
        guard tapIfPresent(card) else {
            snapshot("70-inbox-card-NOT-OPENED")
            return
        }
        sleep(2)
        snapshot("71-inbox-card-opened")
        probeTextFields(prefix: "72-fill-field")
        snapshot("73-fill-after-typing")
        cancelForm()
    }

    func test13_AdminSheets() throws {
        try requireSignedIn()
        guard open(tab: "ניהול") else { return }
        sleep(2)

        if tapButton(startingWith: "משתמש חדש") {
            sleep(2)
            snapshot("80-invite-user-form")
            probeTextFields(prefix: "81-invite-field")
            cancelForm()
            sleep(1)
        }

        // First user row opens the edit sheet.
        let row = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "אבי")
        ).firstMatch
        if tapIfPresent(row) {
            sleep(2)
            snapshot("82-admin-user-edit")
            cancelForm()
            sleep(1)
        }

        if tapButton(startingWith: "דוחות וסטטיסטיקות") {
            sleep(2)
            snapshot("83-reports-catalog")
        }
    }

    func test14_ProfileSheets() throws {
        try requireSignedIn()
        guard open(tab: "פרופיל") else { return }
        sleep(2)

        if tapButton(startingWith: "זמינות") {
            sleep(2)
            snapshot("90-availability")
            probeTextFields(prefix: "91-availability-field")
            cancelForm()
            sleep(1)
        }

        if tapButton(startingWith: "הוספת רכב") {
            sleep(2)
            snapshot("92-add-vehicle")
            probeTextFields(prefix: "93-vehicle-field")
            cancelForm()
            sleep(1)
        }

        if tapButton(startingWith: "מדיניות פרטיות") {
            sleep(3)
            snapshot("94-privacy-policy")
            cancelForm()
        }
    }

    func test15_MoreAndFeedback() throws {
        try requireSignedIn()
        guard tapIfPresent(app.buttons["עוד"]) else { return }
        sleep(1)

        // View-as pickers: opened and closed, never confirmed.
        for entry in ["צפייה כמשתמש", "צפייה בתפקיד אחר"] where tapButton(startingWith: entry) {
            sleep(2)
            snapshot("95-\(entry)")
            cancelForm()
            sleep(1)
            _ = tapIfPresent(app.buttons["עוד"])
            sleep(1)
        }

        if tapIfPresent(app.buttons["משוב"]) {
            sleep(2)
            snapshot("96-feedback-sheet")
            probeTextFields(prefix: "97-feedback-field")
            cancelForm()
        }
    }
}
