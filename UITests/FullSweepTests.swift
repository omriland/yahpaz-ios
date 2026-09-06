import XCTest

/// One pass over every top-level tab, capturing a screenshot and an accessibility dump
/// at each stop. Deeper forms and sheets live in `DeepSweepTests`.
final class FullSweepTests: QACase {
    private let tabLabels = [
        "אירועים",
        "האירועים שלי",
        "ניהול",
        "המשמרות שלי",
        "משמרות",
        "אנשי קשר",
        "דוחות",
        "פרופיל",
    ]

    func test01_EveryTab() throws {
        try requireSignedIn()
        snapshot("10-landing")

        for label in tabLabels {
            guard open(tab: label) else { continue }
            sleep(2)
            snapshot("11-tab-\(label)")
        }

        if tapIfPresent(app.buttons["עוד"]) {
            sleep(1)
            snapshot("13-more-list")
        }
    }

    func test02_InboxSegments() throws {
        try requireSignedIn()
        guard open(tab: "האירועים שלי") else { return }
        sleep(2)
        snapshot("20-inbox")

        for segment in ["ממתינים", "תועדו"] where tapButton(startingWith: segment) {
            sleep(2)
            snapshot("21-inbox-\(segment)")
        }
    }
}
