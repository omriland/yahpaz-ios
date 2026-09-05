import XCTest
@testable import YahpazDomain

final class ShiftDraftTests: XCTestCase {
    private func draft(
        date: String = "2026-02-02",
        kind: String = "morning",
        vehicleType: String = "patrol_north",
        crew: [String] = ["r1"],
        personalVehicleId: String? = nil
    ) -> ShiftDraft {
        ShiftDraft(
            shiftDate: date,
            shiftKind: kind,
            vehicleType: vehicleType,
            responderIds: crew,
            personalVehicleId: personalVehicleId
        )
    }

    func testDateKindVehicleAndCrewAreRequired() {
        XCTAssertTrue(validateShiftDraft(draft()).isEmpty)
        XCTAssertEqual(validateShiftDraft(draft(date: "")).shiftDate, SHIFT_DRAFT_DATE_ERROR)
        XCTAssertEqual(validateShiftDraft(draft(kind: "")).shiftKind, SHIFT_DRAFT_KIND_ERROR)
        XCTAssertEqual(validateShiftDraft(draft(vehicleType: "")).vehicleType, SHIFT_DRAFT_VEHICLE_ERROR)
    }

    func testCrewMustBeOneToThree() {
        XCTAssertEqual(validateShiftDraft(draft(crew: [])).crew, SHIFT_DRAFT_CREW_ERROR)
        XCTAssertNil(validateShiftDraft(draft(crew: ["a", "b", "c"])).crew)
        XCTAssertEqual(validateShiftDraft(draft(crew: ["a", "b", "c", "d"])).crew, SHIFT_DRAFT_CREW_ERROR)
    }

    func testCrewOnlyFailureReportsTheCrewMessage() {
        XCTAssertEqual(validateShiftDraft(draft(crew: [])).formMessage, SHIFT_DRAFT_CREW_ERROR)
        XCTAssertEqual(validateShiftDraft(draft(kind: "", crew: [])).formMessage, SHIFT_DRAFT_FORM_ERROR)
        XCTAssertNil(validateShiftDraft(draft()).formMessage)
    }

    func testTogglingCrewRespectsTheCeiling() {
        var crew = toggleCrewSelection([], responderId: "a")
        crew = toggleCrewSelection(crew, responderId: "b")
        crew = toggleCrewSelection(crew, responderId: "c")
        XCTAssertEqual(crew, ["a", "b", "c"])
        XCTAssertEqual(toggleCrewSelection(crew, responderId: "d"), crew)
        XCTAssertEqual(toggleCrewSelection(crew, responderId: "b"), ["a", "c"])
    }

    func testEveryOfferedKindAndVehicleTypeHasAHebrewLabel() {
        for kind in SHIFT_KIND_ORDER {
            XCTAssertEqual(shiftKindLabel(kind), SHIFT_KIND_LABELS[kind])
        }
        for type in SHIFT_VEHICLE_TYPE_ORDER {
            XCTAssertEqual(shiftVehicleTypeLabel(type), VEHICLE_TYPE_LABELS[type])
        }
        XCTAssertEqual(shiftKindLabel("unknown"), "unknown")
    }

    func testCrewSummaryCountsInHebrew() {
        XCTAssertEqual(shiftCrewSummary(0), "טרם שובצו מתנדבים")
        XCTAssertEqual(shiftCrewSummary(1), "מתנדב אחד משובץ")
        XCTAssertEqual(shiftCrewSummary(2), "2 מתנדבים משובצים")
    }

    func testPersonalVehicleIsOfferedOnlyWhenACrewPlateExists() {
        XCTAssertEqual(offeredShiftVehicleTypes(includePersonal: false), ["patrol_north", "patrol_center"])
        XCTAssertEqual(
            offeredShiftVehicleTypes(includePersonal: true),
            ["patrol_north", "patrol_center", "personal"]
        )
        for type in offeredShiftVehicleTypes(includePersonal: true) {
            XCTAssertEqual(shiftVehicleTypeLabel(type), VEHICLE_TYPE_LABELS[type])
        }
    }

    func testPersonalVehicleRequiresAPlateFromTheAssignedCrew() {
        XCTAssertEqual(validateShiftDraft(draft(vehicleType: "personal")).plate, SHIFT_DRAFT_PLATE_ERROR)
        XCTAssertTrue(validateShiftDraft(draft(vehicleType: "personal", personalVehicleId: "v1")).isEmpty)
        XCTAssertNil(keepPersonalVehicleId("v1", availableIds: []))
        XCTAssertEqual(keepPersonalVehicleId("v1", availableIds: ["v1", "v2"]), "v1")
    }

    func testShiftFormCopyMatchesTheWeb() {
        XCTAssertEqual(SHIFT_NEW_TITLE, "משמרת חדשה")
        XCTAssertEqual(SHIFT_EDIT_TITLE, "עריכת משמרת")
        XCTAssertEqual(SHIFT_SAVE_TITLE, "שמירה")
        XCTAssertEqual(SHIFT_ASSIGN_OPEN, "שיבוץ מתנדבים")
        XCTAssertEqual(SHIFT_ASSIGN_CLOSE, "סגירת שיבוץ")
        XCTAssertEqual(UNIT_SHIFTS_LOAD_FAILED, "טעינת המשמרות נכשלה. בדקו את החיבור ונסו שוב.")
        XCTAssertEqual(crewVehicleLabel(plateNumber: "1234567", model: "מאזדה"), "12-345-67 · מאזדה")
        XCTAssertEqual(crewVehicleLabel(plateNumber: "1234567", model: "  "), "12-345-67")
    }

    func testIdentityLockFollowsUnitManagers() {
        XCTAssertFalse(canEditShiftIdentity(["responder"]))
        XCTAssertTrue(canEditShiftIdentity(["shift_lead"]))
        XCTAssertTrue(canEditShiftIdentity(["admin"]))
        XCTAssertTrue(canEditShiftIdentity(["super_admin"]))
        XCTAssertFalse(canEditShiftIdentity([]))
    }

    func testFilterAssignableProfilesMatchesNameAndCallsign() {
        let profiles = [
            AssignableProfile(id: "r1", fullName: "דנה כהן", callsign: "12"),
            AssignableProfile(id: "r2", fullName: "יוסי לוי", callsign: "44"),
        ]
        XCTAssertEqual(filterAssignableProfiles(profiles, query: "דנה").map(\.id), ["r1"])
        XCTAssertEqual(filterAssignableProfiles(profiles, query: "44").map(\.id), ["r2"])
        XCTAssertEqual(filterAssignableProfiles(profiles, query: " ").count, 2)
    }
}
