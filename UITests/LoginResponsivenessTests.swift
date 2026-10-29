import XCTest

/// App Review rejected 1.0 (3) with "the app became unresponsive after login" on an iPad.
/// Cause: the login screen left with text in its password field, so iOS put up "Save Password?";
/// on an iPad running this iPhone app that sheet's window takes every tap for seconds before it
/// is drawn. This walks the real login screen on DEBUG demo data (`-StoreScreenshots
/// -StoreSignedOut`: any credentials sign in, nothing reaches Supabase), with the notification
/// prompt left in, and fails if the sheet comes back or any screen stops responding.
/// Run it on an iPad simulator as well as an iPhone one.
final class LoginResponsivenessTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-StoreScreenshots", "-StoreSignedOut", "-StorePushPrompt",
            "-AppleLanguages", "(he)", "-AppleLocale", "he_IL",
        ]
    }

    func testScreensRespondAfterLogin() throws {
        app.launch()

        let email = app.textFields.firstMatch
        XCTAssertTrue(email.waitForExistence(timeout: 15), "login screen")
        email.tap()
        // iOS offers to save each new credential once, so a fresh address keeps the test honest.
        email.typeText("reviewer\(Int.random(in: 10_000...99_999))@example.com")
        let password = app.secureTextFields.firstMatch
        password.tap()
        password.typeText("demo-password")
        app.buttons["כניסה"].firstMatch.tap()

        step("inbox after login") { self.app.buttons["המשך התיעוד"].firstMatch }
        let allow = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["Allow"]
        if allow.waitForExistence(timeout: 5) { allow.tap() }
        let saveSheet = app.buttons.matching(
            NSPredicate(format: "label IN %@", ["Not Now", "לא עכשיו"])
        ).firstMatch
        XCTAssertFalse(saveSheet.waitForExistence(timeout: 5), "iOS offered to save the password")
        XCTAssertTrue(app.buttons["המשך התיעוד"].firstMatch.isHittable, "inbox does not take taps")

        app.buttons["המשך התיעוד"].firstMatch.tap()
        step("fill screen") { self.app.navigationBars["השלמת התיעוד שלי"] }
        app.navigationBars.buttons["חזרה"].firstMatch.tap()

        open(tab: "המשמרות שלי")
        step("my shifts") { self.app.staticTexts["משמרות ממתינות לתיעוד"] }
        open(tab: "אנשי קשר")
        step("contacts") { self.app.staticTexts["אחמ״ש דמו"] }
        open(tab: "מפה")
        step("map") { self.app.staticTexts["מפה"] }
        open(tab: "פרופיל")
        step("profile") { self.app.staticTexts["כונן דמו"] }
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "זמינות")).firstMatch.tap()
        step("availability sheet") { self.app.buttons["שמירת זמינות"] }
        app.swipeDown(velocity: .fast)
        open(tab: "האירועים שלי")
        app.buttons["משוב"].firstMatch.tap()
        step("feedback sheet") { self.app.buttons["הצעה"] }
    }

    /// Each screen must answer within a few seconds; a blocked or hung UI fails here.
    private func step(_ name: String, _ element: () -> XCUIElement, timeout: TimeInterval = 8) {
        XCTAssertTrue(element().waitForExistence(timeout: timeout), "\(name) did not appear")
    }

    private func open(tab label: String) {
        let direct = app.buttons[label].firstMatch
        if direct.exists && direct.isHittable {
            direct.tap()
            return
        }
        app.buttons["עוד"].firstMatch.tap()
        let entry = app.buttons[label].firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 5), "no \(label) in עוד")
        entry.tap()
    }
}
