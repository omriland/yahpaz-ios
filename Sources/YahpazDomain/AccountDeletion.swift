import Foundation

/// Self-service account deletion (App Store guideline 5.1.1(v)). Same flow and copy as the
/// web `DeleteAccountSection`; the server is the `delete-account` edge function.

public enum AccountDeletionResult: Equatable, Sendable {
    case deleted
    /// The App Review demo account: the server reports success but keeps it.
    case simulated
    case failed(String)
}

public let ACCOUNT_DELETION_FAILED = "מחיקת החשבון נכשלה. בדקו את החיבור ונסו שוב."

public let DELETE_ACCOUNT_BUTTON_TITLE = "מחיקת חשבון"
public let DELETE_ACCOUNT_EXPLAIN_TITLE = "למחוק את החשבון?"
public let DELETE_ACCOUNT_EXPLAIN_MESSAGE =
    "מחיקת החשבון תסיר לצמיתות את פרטי הפרופיל והקשר (שם, אות קריאה, דוא״ל וטלפון), את הרכבים והכתובות שלך, תמונות, סרטונים ומשובים שהעלית, ואת הכניסה לחשבון בכל המכשירים. תיעוד אירועים ומשמרות שהשתתפת בהם נשמר ביחידה, ללא הפרטים האישיים שלך."
public let DELETE_ACCOUNT_CONTINUE = "המשך"
public let DELETE_ACCOUNT_FINAL_TITLE = "אישור סופי"
public let DELETE_ACCOUNT_FINAL_MESSAGE = "המחיקה סופית ואי אפשר לבטל אותה."
public let DELETE_ACCOUNT_CONFIRM = "מחיקת החשבון לצמיתות"
public let DELETE_ACCOUNT_DONE_TITLE = "החשבון נמחק"
public let DELETE_ACCOUNT_FAILED_TITLE = "המחיקה לא הושלמה"

public func deleteAccountDoneMessage(_ result: AccountDeletionResult) -> String {
    if result == .simulated {
        return "זהו חשבון הדמו של App Review, ולכן הוא לא נמחק בפועל, כדי שהבדיקה תוכל להמשיך. בחשבון רגיל, החשבון והמידע האישי נמחקים עכשיו."
    }
    return "החשבון והמידע האישי שלך נמחקו. תודה על הפעילות ביחידה."
}

/// Never from "view as" or a role preview: the session is not (only) the member's own.
public func canDeleteOwnAccount(impersonating: Bool, previewingRole: Bool) -> Bool {
    !impersonating && !previewingRole
}

/// A 2xx body: `{"ok":true,"status":"deleted"|"simulated"}`.
public func accountDeletionResult(success data: Data) -> AccountDeletionResult {
    let status = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["status"] as? String
    switch status {
    case "deleted": return .deleted
    case "simulated": return .simulated
    default: return .failed(ACCOUNT_DELETION_FAILED)
    }
}

/// A non-2xx body: `{"error":"<Hebrew reason>"}` is shown as is; anything else is generic.
public func accountDeletionResult(failure data: Data?) -> AccountDeletionResult {
    guard let data,
          let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String,
          !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else { return .failed(ACCOUNT_DELETION_FAILED) }
    return .failed(message)
}
