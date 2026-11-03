import XCTest
@testable import YahpazDomain

final class AccountDeletionTests: XCTestCase {
    func testOfferedOnlyOnTheMembersOwnOrdinarySession() {
        XCTAssertTrue(canDeleteOwnAccount(impersonating: false, previewingRole: false))
        XCTAssertFalse(canDeleteOwnAccount(impersonating: true, previewingRole: false))
        XCTAssertFalse(canDeleteOwnAccount(impersonating: false, previewingRole: true))
    }

    func testSuccessBodies() {
        XCTAssertEqual(accountDeletionResult(success: Data(#"{"ok":true,"status":"deleted"}"#.utf8)), .deleted)
        XCTAssertEqual(accountDeletionResult(success: Data(#"{"ok":true,"status":"simulated"}"#.utf8)), .simulated)
        XCTAssertEqual(accountDeletionResult(success: Data(#"{"ok":true,"status":"odd"}"#.utf8)), .failed(ACCOUNT_DELETION_FAILED))
        XCTAssertEqual(accountDeletionResult(success: Data("not json".utf8)), .failed(ACCOUNT_DELETION_FAILED))
    }

    func testRefusalShowsTheServersText() {
        let body = Data(#"{"error":"זהו המנהל האחרון ביחידה. יש למנות מנהל נוסף לפני מחיקת החשבון.","code":"account_is_last_admin"}"#.utf8)
        XCTAssertEqual(
            accountDeletionResult(failure: body),
            .failed("זהו המנהל האחרון ביחידה. יש למנות מנהל נוסף לפני מחיקת החשבון.")
        )
    }

    func testAnyOtherFailureIsGeneric() {
        XCTAssertEqual(accountDeletionResult(failure: nil), .failed(ACCOUNT_DELETION_FAILED))
        XCTAssertEqual(accountDeletionResult(failure: Data("{}".utf8)), .failed(ACCOUNT_DELETION_FAILED))
        XCTAssertEqual(accountDeletionResult(failure: Data(#"{"error":"  "}"#.utf8)), .failed(ACCOUNT_DELETION_FAILED))
    }

    func testCopyMatchesWhatTheServerDoes() {
        XCTAssertEqual(DELETE_ACCOUNT_BUTTON_TITLE, "מחיקת חשבון")
        XCTAssertTrue(DELETE_ACCOUNT_EXPLAIN_MESSAGE.contains("רכבים"))
        XCTAssertTrue(DELETE_ACCOUNT_EXPLAIN_MESSAGE.contains("נשמר"))
        XCTAssertTrue(DELETE_ACCOUNT_FINAL_MESSAGE.contains("אי אפשר לבטל"))
        XCTAssertNotEqual(deleteAccountDoneMessage(.deleted), deleteAccountDoneMessage(.simulated))
        XCTAssertTrue(deleteAccountDoneMessage(.simulated).contains("App Review"))
    }
}
