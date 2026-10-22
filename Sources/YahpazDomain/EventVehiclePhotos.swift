import Foundation

public let VEHICLE_PHOTOS_TITLE = "לא צורפו תמונות לרכבים הבאים:"
public let VEHICLE_PHOTOS_BACK = "חזרה לעריכה"
public let VEHICLE_PHOTOS_PROCEED = "שמירה ללא תמונות נוספות"

public struct PhotoCoveragePlate: Equatable, Sendable {
    public var id: String
    public var plateDigits: String

    public init(id: String, plateDigits: String) {
        self.id = id
        self.plateDigits = plateDigits
    }
}

/// Plate digits that already have at least one attached photo (any uploader).
public func coveredPlateDigits(media: [EventMedia], plates: [PhotoCoveragePlate]) -> Set<String> {
    let digitsById = Dictionary(plates.map { ($0.id, $0.plateDigits) }, uniquingKeysWith: { _, last in last })
    var covered = Set<String>()
    for item in media {
        for plateId in item.treatedPlateIds {
            if let digits = digitsById[plateId], !digits.isEmpty { covered.insert(digits) }
        }
    }
    return covered
}

public func coveragePlatesFromOptions(_ options: [EventMediaPlateOption]) -> [PhotoCoveragePlate] {
    options.map { PhotoCoveragePlate(id: $0.id, plateDigits: plateDigits($0.plateNumber)) }
}

/// Vehicles on this responder's log that have no photo on the event.
/// A photo attached to several plates counts for each; another responder's
/// photo on the same plate number also counts.
public func vehiclesMissingPhotos(myPlates: [TreatedPlate], coveredDigits: Set<String>) -> [TreatedPlate] {
    myPlates.filter { plate in
        let digits = plateDigits(plate.plateNumber)
        return !digits.isEmpty && !coveredDigits.contains(digits)
    }
}
