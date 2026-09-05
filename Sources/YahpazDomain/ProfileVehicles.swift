import Foundation

public struct VehicleRowInput: Equatable, Sendable {
    public var plateRaw: String
    public var modelRaw: String?
    public var archived: Bool?
    public var id: String?
    public var isDefault: Bool?

    public init(
        plateRaw: String,
        modelRaw: String?,
        archived: Bool?,
        id: String? = nil,
        isDefault: Bool? = nil
    ) {
        self.plateRaw = plateRaw
        self.modelRaw = modelRaw
        self.archived = archived
        self.id = id
        self.isDefault = isDefault
    }
}

public struct ProfileVehicle: Equatable, Hashable, Identifiable, Sendable {
    public var plate: String
    public var model: String
    public var rowId: String?
    public var archived: Bool
    public var isDefault: Bool

    public var id: String { rowId ?? plate }

    public init(
        plate: String,
        model: String,
        id: String? = nil,
        archived: Bool = false,
        isDefault: Bool = false
    ) {
        self.plate = plate
        self.model = model
        self.rowId = id
        self.archived = archived
        self.isDefault = isDefault
    }
}

public let SET_DEFAULT_VEHICLE_LABEL = "הגדר כרכב ברירת מחדל"
public let DEFAULT_VEHICLE_LABEL = "רכב ראשי"
public let ADD_VEHICLE = "הוספת רכב"
public let VEHICLE_PLATE_LABEL = "לוחית רישוי"
public let VEHICLE_MODEL_LABEL = "דגם"
public let VEHICLE_DELETE_CONFIRM = "האם למחוק את הרכב הזה? לא ניתן לשחזר אותו לאחר המחיקה."
public let VEHICLE_ARCHIVE_CONFIRM =
    "לא ניתן למחוק רכב זה כי הוא מקושר לאירוע קיים. האם להעביר אותו לארכיון כדי שאיש לא יוכל להשתמש בו יותר במערכת?"
public let VEHICLE_ARCHIVED_CAPTION = "בארכיון — לא ניתן לשייך לאירועים חדשים"
public let VEHICLE_DELETE_FAILED = "מחיקת הרכב נכשלה."
public let VEHICLE_ARCHIVE_FAILED = "העברת הרכב לארכיון נכשלה."
public let VEHICLE_UNARCHIVE_FAILED = "שחזור הרכב מהארכיון נכשל."
public let SAVE_VEHICLES_FAILED = "שמירת הרכבים נכשלה."
public let DUPLICATE_PLATE_ERROR = "לא ניתן לשייך את אותה לוחית רישוי יותר מפעם אחת לאותו משתמש."
public let SET_DEFAULT_VEHICLE_FAILED = "עדכון הרכב הראשי נכשל."

public enum VehicleFieldsResult: Equatable, Sendable {
    case ok(plateNumber: String, model: String)
    case error(String)
}

public func vehicleRemoveMode(attached: Bool) -> String {
    attached ? "archive" : "delete"
}

public func canChooseDefaultVehicle(_ vehicles: [ProfileVehicle]) -> Bool {
    vehicles.filter { !$0.archived }.count >= 2
}

public func isProfileVehicleEditing(id: String?, key: String, editingKey: String?) -> Bool {
    id == nil || key == editingKey
}

public func vehicleFieldsForSave(plateNumber: String, model: String) -> VehicleFieldsResult {
    let plate = plateNumberForSave(plateNumber)
    let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
    if plate == nil || plate?.isEmpty == true || trimmedModel.isEmpty {
        return .error("יש להזין לוחית רישוי ודגם.")
    }
    return .ok(plateNumber: plate!, model: trimmedModel)
}

public func visibleProfileVehicles(_ rows: [VehicleRowInput]) -> [ProfileVehicle] {
    managedProfileVehicles(rows).filter { !$0.archived }
}

public func managedProfileVehicles(_ rows: [VehicleRowInput]) -> [ProfileVehicle] {
    rows.compactMap { row in
        let plate = plateDigits(row.plateRaw)
        if plate.isEmpty { return nil }
        let archived = row.archived == true
        return ProfileVehicle(
            plate: plate,
            model: row.modelRaw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            id: row.id,
            archived: archived,
            isDefault: row.isDefault == true && !archived
        )
    }
}
