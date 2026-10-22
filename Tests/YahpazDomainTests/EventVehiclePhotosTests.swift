import XCTest
@testable import YahpazDomain

final class EventVehiclePhotosTests: XCTestCase {
    private func media(_ plateIds: String...) -> EventMedia {
        EventMedia(
            id: "m-\(plateIds.joined(separator: ","))",
            eventId: "e1",
            uploadedBy: "u1",
            uploaderName: "אחר",
            treatedPlateIds: plateIds,
            caption: nil,
            takenWhen: .duringAfterTreatment,
            storagePath: "p",
            mimeType: "image/jpeg",
            byteSize: 1,
            width: 1,
            height: 1,
            createdAt: "2026-09-10T00:00:00Z",
            signedUrl: nil
        )
    }

    func testSharedPhotoCoversEveryAttachedPlate() {
        let plates = [
            PhotoCoveragePlate(id: "p1", plateDigits: "1234567"),
            PhotoCoveragePlate(id: "p2", plateDigits: "7654321"),
        ]
        XCTAssertEqual(coveredPlateDigits(media: [media("p1", "p2")], plates: plates), ["1234567", "7654321"])
    }

    func testSamePlateNumberFromAnotherResponderCounts() {
        let myPlates = [TreatedPlate(plateNumber: "12-345-67", model: "טוסון", color: "לבן")]
        XCTAssertTrue(vehiclesMissingPhotos(myPlates: myPlates, coveredDigits: ["1234567"]).isEmpty)
    }

    func testListsVehiclesStillMissingAPhoto() {
        let myPlates = [
            TreatedPlate(plateNumber: "12-345-67", model: "טוסון", color: "לבן"),
            TreatedPlate(plateNumber: "76-543-21", model: "קורולה", color: "כסף"),
        ]
        XCTAssertEqual(vehiclesMissingPhotos(myPlates: myPlates, coveredDigits: ["1234567"]), [myPlates[1]])
        XCTAssertEqual(VEHICLE_PHOTOS_TITLE, "לא צורפו תמונות לרכבים הבאים:")
        XCTAssertEqual(VEHICLE_PHOTOS_BACK, "חזרה לעריכה")
        XCTAssertEqual(VEHICLE_PHOTOS_PROCEED, "שמירה ללא תמונות נוספות")
    }

    func testCoveragePlatesComeFromMediaPlateOptions() {
        let options = [EventMediaPlateOption(id: "p1", plateNumber: "12-345-67", model: nil, color: nil, logoSlug: nil)]
        XCTAssertEqual(coveragePlatesFromOptions(options), [PhotoCoveragePlate(id: "p1", plateDigits: "1234567")])
    }
}
