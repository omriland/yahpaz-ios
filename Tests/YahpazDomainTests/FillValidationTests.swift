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

    func testCompleteAcceptsOdometersWhenLeadTotalKmMissing() {
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
        XCTAssertTrue(errors.isEmpty)
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

    func testCompleteErrorsOnLeftoverTreatedPlatePending() {
        let errors = validateResponderFillDraft(
            draft(
                vehiclePlate: "1234567",
                odometerStart: "100",
                odometerEnd: "112",
                route: "כביש 1",
                treatmentDetail: "טיפול",
                treatedPlatePending: "123"
            ),
            mode: .complete,
            allowedPlates: plates,
            totalKm: nil
        )
        XCTAssertEqual(errors.treatedPlates, TREATED_PLATE_LEFTOVER_ERROR)
    }

    func testDraftAllowsLeftoverTreatedPlatePending() {
        let errors = validateResponderFillDraft(
            draft(treatedPlatePending: "123"),
            mode: .draft,
            allowedPlates: plates,
            totalKm: nil
        )
        XCTAssertNil(errors.treatedPlates)
    }

    func testCompleteErrorsOnUnfinishedMediaDrafts() {
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
            totalKm: 12,
            unfinishedMediaDraftCount: 1
        )
        XCTAssertEqual(errors.eventMedia, EVENT_MEDIA_LEFTOVER_ERROR)
    }

    func testDraftIgnoresUnfinishedMediaDrafts() {
        let errors = validateResponderFillDraft(
            ResponderFillDraft(),
            mode: .draft,
            allowedPlates: plates,
            totalKm: nil,
            unfinishedMediaDraftCount: 2
        )
        XCTAssertNil(errors.eventMedia)
    }

    func testCompleteAllowsZeroTreatedPlates() {
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
            totalKm: 12
        )
        XCTAssertNil(errors.treatedPlates)
        XCTAssertTrue(errors.isEmpty)
    }

    func testCompleteOnAlreadyDoneAssignmentIsSuccess() {
        XCTAssertEqual(
            gateResponderFillWrite(
                complete: true,
                participationStatus: .done,
                eventStatus: .inProgress
            ),
            .alreadyComplete
        )
    }

    func testDraftOnAlreadyDoneAssignmentIsLocked() {
        XCTAssertEqual(
            gateResponderFillWrite(
                complete: false,
                participationStatus: .done,
                eventStatus: .inProgress
            ),
            .locked
        )
    }

    func testWriteOnDoneEventIsLocked() {
        XCTAssertEqual(
            gateResponderFillWrite(
                complete: true,
                participationStatus: .inProgress,
                eventStatus: .done
            ),
            .locked
        )
    }

    func testInProgressCompleteMayProceed() {
        XCTAssertEqual(
            gateResponderFillWrite(
                complete: true,
                participationStatus: .inProgress,
                eventStatus: .inProgress
            ),
            .proceed
        )
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
        treatmentNotes: String = "",
        treatedPlates: [TreatedPlate] = [],
        treatedPlatePending: String = ""
    ) -> ResponderFillDraft {
        ResponderFillDraft(
            vehiclePlate: vehiclePlate,
            odometerStart: odometerStart,
            odometerEnd: odometerEnd,
            route: route,
            treatmentDetail: treatmentDetail,
            treatmentNotes: treatmentNotes,
            treatedPlates: treatedPlates,
            treatedPlatePending: treatedPlatePending
        )
    }
}
