import XCTest

/// The profile's "מחיקת חשבון" flow on DEBUG demo data (`-StoreScreenshots`): nothing reaches
/// Supabase, and the server call is stubbed to the App Review demo's simulated result.
/// Screenshots go to `STORE_SHOTS_DIR` (set as `TEST_RUNNER_STORE_SHOTS_DIR`) when given.
final class AccountDeletionTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    func testDeleteAccountTwoStepConfirmationThenLocalSignOut() throws {
        app = XCUIApplication()
        app.launchArguments = ["-StoreScreenshots", "-AppleLanguages", "(he)", "-AppleLocale", "he_IL"]
        app.launch()
        XCTAssertTrue(app.buttons["המשך התיעוד"].firstMatch.waitForExistence(timeout: 15))

        app.buttons["עוד"].firstMatch.tap()
        let profile = app.buttons["פרופיל"].firstMatch
        XCTAssertTrue(profile.waitForExistence(timeout: 5))
        profile.tap()

        let delete = app.buttons["מחיקת חשבון"].firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 10))
        for _ in 0..<6 where !delete.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(delete.isHittable)
        sleep(1)
        shot("ios-01-profile-delete-button")

        // Step 1: what is deleted and what is kept. (On iOS 26+ the sheet is a popover with
        // no Cancel button; tapping outside dismisses it.)
        delete.tap()
        XCTAssertTrue(app.staticTexts["למחוק את החשבון?"].firstMatch.waitForExistence(timeout: 5))
        sleep(1)
        shot("ios-02-step1-explain")
        let proceed = app.buttons["המשך"].firstMatch
        XCTAssertTrue(proceed.waitForExistence(timeout: 5))
        proceed.tap()

        // Step 2: final confirmation.
        let confirm = app.buttons["מחיקת החשבון לצמיתות"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        sleep(1)
        shot("ios-03-step2-final")
        confirm.tap()

        // Result, then this device signs out.
        let done = app.buttons["סיום"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["החשבון נמחק"].firstMatch.exists)
        sleep(1)
        shot("ios-04-done")
        done.tap()

        XCTAssertTrue(app.secureTextFields.firstMatch.waitForExistence(timeout: 10), "expected the sign-in screen")
        sleep(1)
        shot("ios-05-signed-out")
    }

    private func shot(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["STORE_SHOTS_DIR"], !dir.isEmpty {
            let url = URL(fileURLWithPath: dir).appendingPathComponent("\(name).png")
            XCTAssertNoThrow(try screenshot.pngRepresentation.write(to: url))
        }
    }
}
