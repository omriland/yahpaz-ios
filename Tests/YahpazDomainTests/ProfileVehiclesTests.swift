import XCTest
@testable import YahpazDomain

final class ProfileVehiclesTests: XCTestCase {
    func testEmptyInputYieldsEmptyList() {
        XCTAssertEqual(visibleProfileVehicles([]), [])
    }

    func testDropsArchived() {
        let rows = [
            VehicleRowInput(plateRaw: "1234567", modelRaw: "טויוטה", archived: false),
            VehicleRowInput(plateRaw: "7654321", modelRaw: "קיה", archived: true),
            VehicleRowInput(plateRaw: "1111111", modelRaw: "הונדה", archived: nil),
        ]
        XCTAssertEqual(
            visibleProfileVehicles(rows),
            [
                ProfileVehicle(plate: "1234567", model: "טויוטה"),
                ProfileVehicle(plate: "1111111", model: "הונדה"),
            ]
        )
    }

    func testDropsEmptyAndNonDigitPlates() {
        let rows = [
            VehicleRowInput(plateRaw: "", modelRaw: "טויוטה", archived: false),
            VehicleRowInput(plateRaw: "abc", modelRaw: "קיה", archived: false),
            VehicleRowInput(plateRaw: "12-345-67", modelRaw: "הונדה", archived: false),
        ]
        XCTAssertEqual(
            visibleProfileVehicles(rows),
            [ProfileVehicle(plate: "1234567", model: "הונדה")]
        )
    }

    func testTrimsModelAndKeepsBlank() {
        let rows = [
            VehicleRowInput(plateRaw: "1234567", modelRaw: "  טויוטה  ", archived: false),
            VehicleRowInput(plateRaw: "7654321", modelRaw: nil, archived: false),
            VehicleRowInput(plateRaw: "1111111", modelRaw: "   ", archived: false),
        ]
        XCTAssertEqual(
            visibleProfileVehicles(rows),
            [
                ProfileVehicle(plate: "1234567", model: "טויוטה"),
                ProfileVehicle(plate: "7654321", model: ""),
                ProfileVehicle(plate: "1111111", model: ""),
            ]
        )
    }

    func testPreservesOrderOfRemainingRows() {
        let rows = [
            VehicleRowInput(plateRaw: "1111111", modelRaw: "א", archived: false),
            VehicleRowInput(plateRaw: "2222222", modelRaw: "ב", archived: true),
            VehicleRowInput(plateRaw: "3333333", modelRaw: "ג", archived: false),
        ]
        XCTAssertEqual(
            visibleProfileVehicles(rows),
            [
                ProfileVehicle(plate: "1111111", model: "א"),
                ProfileVehicle(plate: "3333333", model: "ג"),
            ]
        )
    }

    func testVehicleRemoveModeArchivesWhenAttached() {
        XCTAssertEqual(vehicleRemoveMode(attached: true), "archive")
        XCTAssertEqual(vehicleRemoveMode(attached: false), "delete")
    }

    func testSetDefaultVehicleLabelMatchesWebTooltip() {
        XCTAssertEqual(SET_DEFAULT_VEHICLE_LABEL, "הגדר כרכב ברירת מחדל")
        XCTAssertEqual(DEFAULT_VEHICLE_LABEL, "רכב ראשי")
    }

    func testCanChooseDefaultVehicleNeedsTwoActiveCars() {
        XCTAssertFalse(canChooseDefaultVehicle([]))
        XCTAssertFalse(canChooseDefaultVehicle([ProfileVehicle(plate: "1", model: "א")]))
        XCTAssertTrue(
            canChooseDefaultVehicle([
                ProfileVehicle(plate: "1", model: "א"),
                ProfileVehicle(plate: "2", model: "ב", archived: true),
                ProfileVehicle(plate: "3", model: "ג"),
            ])
        )
    }

    func testIsProfileVehicleEditingKeepsUnsavedOpenAndSavedClosedUntilPencil() {
        XCTAssertTrue(isProfileVehicleEditing(id: nil, key: "new-1", editingKey: nil))
        XCTAssertFalse(isProfileVehicleEditing(id: "v1", key: "v1", editingKey: nil))
        XCTAssertTrue(isProfileVehicleEditing(id: "v1", key: "v1", editingKey: "v1"))
        XCTAssertFalse(isProfileVehicleEditing(id: "v1", key: "v1", editingKey: "v2"))
    }

    func testManagedProfileVehiclesKeepsArchivedAndIds() {
        let rows = [
            VehicleRowInput(
                plateRaw: "12-345-67",
                modelRaw: "טויוטה",
                archived: false,
                id: "v1",
                isDefault: true
            ),
            VehicleRowInput(
                plateRaw: "7654321",
                modelRaw: "קיה",
                archived: true,
                id: "v2",
                isDefault: false
            ),
        ]
        XCTAssertEqual(
            managedProfileVehicles(rows),
            [
                ProfileVehicle(plate: "1234567", model: "טויוטה", id: "v1", archived: false, isDefault: true),
                ProfileVehicle(plate: "7654321", model: "קיה", id: "v2", archived: true, isDefault: false),
            ]
        )
    }

    func testVehicleFieldsForSaveRequiresPlateAndModel() {
        XCTAssertEqual(
            vehicleFieldsForSave(plateNumber: "", model: "קורולה"),
            .error("יש להזין לוחית רישוי ודגם.")
        )
        XCTAssertEqual(
            vehicleFieldsForSave(plateNumber: "1234567", model: "  קורולה  "),
            .ok(plateNumber: "12-345-67", model: "קורולה")
        )
    }

    func testArchivedDefaultFlagIsCleared() {
        let rows = [
            VehicleRowInput(
                plateRaw: "1234567",
                modelRaw: "טויוטה",
                archived: true,
                id: "v1",
                isDefault: true
            ),
        ]
        XCTAssertEqual(
            managedProfileVehicles(rows),
            [ProfileVehicle(plate: "1234567", model: "טויוטה", id: "v1", archived: true, isDefault: false)]
        )
    }
}
