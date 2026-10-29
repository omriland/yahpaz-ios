import XCTest

/// App Store screenshots taken from the running app on DEBUG demo data (`-StoreScreenshots`),
/// so nothing reaches Supabase and no real person or incident is on screen.
/// `scripts/store-screenshots.sh` runs this per simulator and exports the PNGs.
final class StoreScreenshotTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    /// No login screen: App Review rejected a set that showed only login (2.3.3), so every
    /// shot shows the app in use.
    func testCaptureStoreScreenshots() throws {
        launch()
        let continueFill = app.buttons["המשך התיעוד"].firstMatch
        XCTAssertTrue(continueFill.waitForExistence(timeout: 15))
        shot("01-my-events")

        continueFill.tap()
        XCTAssertTrue(app.staticTexts["4127"].firstMatch.waitForExistence(timeout: 10)
            || app.navigationBars["השלמת התיעוד שלי"].waitForExistence(timeout: 5))
        settle()
        shot("02-complete-my-part")
        app.navigationBars.buttons["חזרה"].firstMatch.tap()

        open(tab: "אנשי קשר")
        settle()
        shot("03-contacts")

        open(tab: "מפה")
        sleep(4) // map tiles
        // The demo members sit around Tel Aviv; zoom through the clusters to show pins.
        for _ in 0..<2 {
            let cluster = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", "מתנדבים")).firstMatch
            guard cluster.exists, cluster.isHittable else { break }
            cluster.tap()
            sleep(3)
        }
        sleep(3)
        shot("04-map")

        open(tab: "פרופיל")
        settle()
        shot("05-profile")

        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "זמינות")).firstMatch.tap()
        settle()
        shot("06-availability")
        app.swipeDown(velocity: .fast)
        settle()

        open(tab: "האירועים שלי")
        app.buttons["משוב"].firstMatch.tap()
        app.buttons["הצעה"].firstMatch.tap()
        settle()
        shot("07-feedback")
    }

    private func launch() {
        app = XCUIApplication()
        app.launchArguments = ["-StoreScreenshots", "-AppleLanguages", "(he)", "-AppleLocale", "he_IL"]
        app.launch()
    }

    /// Tab bar first, then the עוד list.
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

    private func settle() {
        sleep(2)
    }

    /// Writes straight to `STORE_SHOTS_DIR` on the host (set as `TEST_RUNNER_STORE_SHOTS_DIR`):
    /// the simulator runner shares the Mac's file system, and no result bundle is needed.
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
