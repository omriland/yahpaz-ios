import XCTest
@testable import YahpazDomain

final class FillValidationTests: XCTestCase {
    private let plates = ["1234567"]

    func testDraftDoesNotRequireTotalKmOrEnd() {
        let errors = validateResponderFillDraft(
            draft(odometerStart: "100"),
            mode: .draft,
            allowedPlates: plates,
            totalKm: nil
        )
        XCTAssertNil(errors.odometerEnd)
    }

    func testCompleteErrorsWhenTotalKmMissingWithoutShowingTheNumber() {
        let errors = validateResponderFillDraft(
            draft(
                vehiclePlate: "1234567",
                odometerStart: "100",
                odometerEnd: "112",
                route: "כביש 1",
                treatmentDetail: "טיפול"
            ),
            mode: .complete,
            allowedPlates: plates,
            totalKm: nil
        )
        XCTAssertEqual(
            errors.odometerEnd,
            "האחמ״ש טרם הזין קילומטרים לאירוע. לא ניתן לסיים את הדיווח."
        )
        XCTAssertFalse(String(describing: errors).contains("12"))
    }

    func testCompleteRequiresUserEnteredEndWhenTotalKmIsSet() {
        let errors = validateResponderFillDraft(
            draft(
                vehiclePlate: "1234567",
                odometerStart: "100",
                odometerEnd: "",
                route: "כביש 1",
                treatmentDetail: "טיפול"
            ),
            mode: .complete,
            allowedPlates: plates,
            totalKm: 12
        )
        XCTAssertEqual(errors.odometerEnd, "יש למלא מד אוץ סיום.")
    }

    func testCompleteAcceptsUserEndWhenTotalKmPresent() {
        let errors = validateResponderFillDraft(
            draft(
                vehiclePlate: "1234567",
                odometerStart: "100",
                odometerEnd: "115",
                route: "כביש 1",
                treatmentDetail: "טיפול"
            ),
            mode: .complete,
            allowedPlates: plates,
            totalKm: 12
        )
        XCTAssertTrue(errors.isEmpty)
    }

    func testEndMustBeGreaterThanStart() {
        let errors = validateResponderFillDraft(
            draft(odometerStart: "100", odometerEnd: "100"),
            mode: .draft,
            allowedPlates: plates,
            totalKm: nil
        )
        XCTAssertEqual(errors.odometerEnd, "מד אוץ סיום חייב להיות גדול ממד אוץ התחלה")
    }

    func testCompleteRequiresPlateFromRoster() {
        let errors = validateResponderFillDraft(
            draft(
                vehiclePlate: "9999999",
                odometerStart: "1",
                odometerEnd: "2",
                route: "כביש",
                treatmentDetail: "טיפול"
            ),
            mode: .complete,
            allowedPlates: plates,
            totalKm: 1
        )
        XCTAssertEqual(errors.vehiclePlate, "יש לבחור רכב מהרשימה המקושרת למשתמש.")
    }

    func testDeriveEventStatusKeepsDraftProgressAsInProgress() {
        XCTAssertEqual(
            deriveEventStatusAfterParticipation([.pending, .inProgress]),
            .inProgress
        )
    }

    func testDeriveEventStatusUsesPartialWhenSomeoneCompleted() {
        XCTAssertEqual(deriveEventStatusAfterParticipation([.done, .pending]), .partial)
    }

    func testDeriveEventStatusDoneWhenEveryParticipationIsDone() {
        XCTAssertEqual(deriveEventStatusAfterParticipation([.done, .done]), .done)
    }

    private func draft(
        vehiclePlate: String = "",
        odometerStart: String = "",
        odometerEnd: String = "",
        route: String = "",
        treatmentDetail: String = "",
        treatmentNotes: String = ""
    ) -> ResponderFillDraft {
        ResponderFillDraft(
            vehiclePlate: vehiclePlate,
            odometerStart: odometerStart,
            odometerEnd: odometerEnd,
            route: route,
            treatmentDetail: treatmentDetail,
            treatmentNotes: treatmentNotes
        )
    }
}
