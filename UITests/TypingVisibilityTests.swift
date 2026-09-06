import XCTest

/// Reproduction probe for the reported bug: text typed into a field is not visible while
/// editing, but appears once the field loses focus.
///
/// The login screen is used because it needs no session. `value` tells us whether the
/// binding received the keystrokes; the screenshots tell us whether they were drawn.
final class TypingVisibilityTests: QACase {
    func testLoginEmailFieldShowsTextWhileTyping() throws {
        guard app.staticTexts["כניסה למערכת"].waitForExistence(timeout: 20) else {
            throw XCTSkip("Signed in — sign out first to exercise the login screen.")
        }
        snapshot("01-login-idle")

        let email = app.textFields.firstMatch
        XCTAssertTrue(email.waitForExistence(timeout: 5), "No text field on the login screen")

        email.tap()
        shot("02-login-email-focused-empty")

        for (index, chunk) in ["qa", "@yahpz", ".com"].enumerated() {
            email.typeText(chunk)
            shot("03-login-email-typing-\(index)-\(chunk)")
        }

        let typed = email.value as? String ?? ""
        snapshot("04-login-email-focused-full")

        // Move focus to the password field: same screen, keyboard stays up.
        let password = app.secureTextFields.firstMatch
        if password.waitForExistence(timeout: 3) {
            password.tap()
            shot("05-password-focused-email-blurred")
            password.typeText("hunter2")
            shot("06-password-typing")
        }

        // Dismiss the keyboard entirely — this is the state where the user says text appears.
        app.staticTexts["כניסה למערכת"].tap()
        shot("07-keyboard-dismissed")

        XCTAssertEqual(
            typed,
            "qa@yahpz.com",
            "Field binding did not receive the typed text (value was '\(typed)')"
        )
    }
}
