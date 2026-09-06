import XCTest

/// Shared plumbing for the QA sweep. Screenshots and hierarchy dumps are attached to the
/// result bundle so they can be exported with `xcrun xcresulttool export attachments`.
///
/// The sweep runs against production Supabase, so every helper here is read-only:
/// `forbidden` blocks any tap that would sign out, save, or delete.
class QACase: XCTestCase {
    var app: XCUIApplication!

    /// Never tap these, whatever a test asks for.
    private let forbidden = [
        "יציאה", "מחיקה", "שמירה", "אישור", "הסרה", "שליחה", "השלמה", "מחק", "שמור",
    ]

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(he)", "-AppleLocale", "he_IL"]
        app.launch()
    }

    // MARK: - Capture

    func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Frames in the tree reveal off-screen, zero-size, and overlapping elements that a
    /// screenshot alone cannot explain.
    func dumpTree(_ name: String) {
        let attachment = XCTAttachment(string: app.debugDescription)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func snapshot(_ name: String) {
        shot(name)
        dumpTree("\(name).tree.txt")
    }

    var isSignedIn: Bool {
        !app.staticTexts["כניסה למערכת"].waitForExistence(timeout: 8)
    }

    func requireSignedIn() throws {
        guard isSignedIn else {
            snapshot("00-NOT-SIGNED-IN")
            throw XCTSkip("Not signed in — sign in on the simulator, then re-run.")
        }
    }

    // MARK: - Safe interaction

    @discardableResult
    func tapIfPresent(_ element: XCUIElement) -> Bool {
        guard element.exists, element.isHittable else { return false }
        if let label = element.label as String?, forbidden.contains(where: label.contains) {
            XCTContext.runActivity(named: "BLOCKED destructive tap: \(label)") { _ in }
            return false
        }
        element.tap()
        return true
    }

    /// Bidi marks and trailing counts make exact label matching unreliable in Hebrew.
    func button(startingWith prefix: String) -> XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", prefix)
        ).firstMatch
    }

    @discardableResult
    func tapButton(startingWith prefix: String) -> Bool {
        tapIfPresent(button(startingWith: prefix))
    }

    /// Taps a tab bar button, falling back to the עוד overflow list.
    @discardableResult
    func open(tab label: String) -> Bool {
        if tapIfPresent(app.buttons[label]) { return true }
        guard tapIfPresent(app.buttons["עוד"]) else { return false }
        sleep(1)
        return tapIfPresent(app.buttons[label])
    }

    /// Leaves a form or sheet without saving.
    func cancelForm() {
        for label in ["ביטול", "סגירה", "חזרה"] where tapIfPresent(app.buttons[label]) {
            sleep(1)
            return
        }
        let back = app.navigationBars.buttons.element(boundBy: 0)
        if back.exists, back.isHittable {
            back.tap()
            sleep(1)
            return
        }
        app.swipeDown()
        sleep(1)
    }

    // MARK: - Focus / typing probe

    /// Taps each text field, types digits, and screenshots while the keyboard is still up.
    /// A mismatch between `value` and what was typed means the binding dropped input;
    /// a match with blank pixels means a rendering bug.
    func probeTextFields(prefix: String, type text: String = "1234") {
        let fields = app.textFields.allElementsBoundByIndex
        guard !fields.isEmpty else {
            XCTContext.runActivity(named: "\(prefix): no text fields on screen") { _ in }
            return
        }
        for (index, field) in fields.enumerated() where field.exists && field.isHittable {
            let label = field.label
            field.tap()
            shot("\(prefix)-\(index)-focused")
            field.typeText(text)
            shot("\(prefix)-\(index)-typed")
            // Distinguishes "never renders while focused" from "renders a frame late".
            sleep(2)
            shot("\(prefix)-\(index)-typed-settled")
            let value = (field.value as? String) ?? ""
            XCTContext.runActivity(
                named: "\(prefix)-\(index) label='\(label)' typed='\(text)' value='\(value)'"
            ) { _ in }
        }
    }
}
