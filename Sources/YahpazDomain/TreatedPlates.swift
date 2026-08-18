import Foundation

public struct TreatedPlate: Equatable, Sendable, Codable, Hashable {
    public var plateNumber: String
    public var model: String?
    public var color: String?

    public init(plateNumber: String, model: String? = nil, color: String? = nil) {
        self.plateNumber = plateNumber
        self.model = model
        self.color = color
    }

    enum CodingKeys: String, CodingKey {
        case plateNumber = "plate_number"
        case model
        case color
    }
}

public let TREATED_PLATE_LENGTH_ERROR = "יש להזין 7 או 8 ספרות."
public let TREATED_PLATE_DUPLICATE_ERROR = "מספר זה כבר נוסף."
public let TREATED_PLATE_LEFTOVER_ERROR = "השלימו או מחקו את המספר בתחתית."

public enum CommitTreatedPlateResult: Equatable, Sendable {
    case ok(plate: TreatedPlate, plates: [TreatedPlate])
    case error(String)
}

public func treatedPlateCaption(model: String?, color: String?) -> String? {
    let nextModel = model?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let nextColor = color?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !nextModel.isEmpty && !nextColor.isEmpty { return "\(nextModel) · \(nextColor)" }
    if !nextModel.isEmpty { return nextModel }
    if !nextColor.isEmpty { return nextColor }
    return nil
}

public func commitTreatedPlate(
    pending: String,
    plates: [TreatedPlate]
) -> CommitTreatedPlateResult {
    let digits = plateDigits(pending)
    if digits.count != 7 && digits.count != 8 {
        return .error(TREATED_PLATE_LENGTH_ERROR)
    }
    if plates.contains(where: { plateDigits($0.plateNumber) == digits }) {
        return .error(TREATED_PLATE_DUPLICATE_ERROR)
    }
    let plate = TreatedPlate(plateNumber: formatPlate(digits), model: nil, color: nil)
    return .ok(plate: plate, plates: plates + [plate])
}

public func leftoverTreatedPlateError(pending: String, mode: FillMode) -> String? {
    if mode != .complete { return nil }
    if plateDigits(pending).isEmpty { return nil }
    return TREATED_PLATE_LEFTOVER_ERROR
}

public func removeTreatedPlate(_ plates: [TreatedPlate], plateDigitsKey: String) -> [TreatedPlate] {
    let key = plateDigits(plateDigitsKey)
    return plates.filter { plateDigits($0.plateNumber) != key }
}

public struct TreatedPlateRowInput: Sendable {
    public var plateNumber: String?
    public var model: String?
    public var color: String?
    public var sortOrder: Int?

    public init(
        plateNumber: String? = nil,
        model: String? = nil,
        color: String? = nil,
        sortOrder: Int? = nil
    ) {
        self.plateNumber = plateNumber
        self.model = model
        self.color = color
        self.sortOrder = sortOrder
    }
}

/** Map DB rows (optional sort_order) into TreatedPlate[], ordered. */
public func mapTreatedPlateRows(_ rows: [TreatedPlateRowInput]?) -> [TreatedPlate] {
    (rows ?? [])
        .sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }
        .compactMap { row in
            let plateNumber = row.plateNumber?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !plateNumber.isEmpty else { return nil }
            return TreatedPlate(plateNumber: plateNumber, model: row.model, color: row.color)
        }
}
