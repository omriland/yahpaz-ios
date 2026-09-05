import Foundation

public struct TreatedPlate: Equatable, Sendable, Codable, Hashable {
    public var plateNumber: String
    public var model: String?
    public var color: String?
    public var leftWhere: String?
    public var manufacturer: String?
    public var logoSlug: String?

    public init(
        plateNumber: String,
        model: String? = nil,
        color: String? = nil,
        leftWhere: String? = nil,
        manufacturer: String? = nil,
        logoSlug: String? = nil
    ) {
        self.plateNumber = plateNumber
        self.model = model
        self.color = color
        self.leftWhere = leftWhere
        self.manufacturer = manufacturer
        self.logoSlug = logoSlug
    }

    enum CodingKeys: String, CodingKey {
        case plateNumber = "plate_number"
        case model
        case color
        case leftWhere = "left_where"
        case manufacturer
        case logoSlug = "logo_slug"
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
    let plate = TreatedPlate(plateNumber: formatPlate(digits), model: nil, color: nil, leftWhere: nil)
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

public func setTreatedPlateLeftWhere(
    _ plates: [TreatedPlate],
    plateDigitsKey: String,
    leftWhere: String
) -> [TreatedPlate] {
    let key = plateDigits(plateDigitsKey)
    return plates.map { row in
        guard plateDigits(row.plateNumber) == key else { return row }
        var next = row
        next.leftWhere = leftWhere.isEmpty ? nil : leftWhere
        return next
    }
}

public func applyTreatedPlateLookup(
    _ plates: [TreatedPlate],
    plateDigitsKey: String,
    hit: PlateLookupHit
) -> [TreatedPlate] {
    let key = plateDigits(plateDigitsKey)
    let manufacturer = hit.manufacturer?.trimmingCharacters(in: .whitespacesAndNewlines)
    return plates.map { row in
        guard plateDigits(row.plateNumber) == key else { return row }
        var next = row
        next.model = hit.model
        next.color = hit.color
        next.manufacturer = (manufacturer?.isEmpty == false) ? manufacturer : nil
        next.logoSlug = resolveCarLogoSlug(next.manufacturer)
        return next
    }
}

public struct TreatedPlateRowInput: Sendable {
    public var plateNumber: String?
    public var model: String?
    public var color: String?
    public var leftWhere: String?
    public var manufacturer: String?
    public var logoSlug: String?
    public var sortOrder: Int?

    public init(
        plateNumber: String? = nil,
        model: String? = nil,
        color: String? = nil,
        leftWhere: String? = nil,
        manufacturer: String? = nil,
        logoSlug: String? = nil,
        sortOrder: Int? = nil
    ) {
        self.plateNumber = plateNumber
        self.model = model
        self.color = color
        self.leftWhere = leftWhere
        self.manufacturer = manufacturer
        self.logoSlug = logoSlug
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
            let left = row.leftWhere?.trimmingCharacters(in: .whitespacesAndNewlines)
            let manufacturer = row.manufacturer?.trimmingCharacters(in: .whitespacesAndNewlines)
            let storedSlug = row.logoSlug?.trimmingCharacters(in: .whitespacesAndNewlines)
            return TreatedPlate(
                plateNumber: plateNumber,
                model: row.model,
                color: row.color,
                leftWhere: (left?.isEmpty == false) ? left : nil,
                manufacturer: (manufacturer?.isEmpty == false) ? manufacturer : nil,
                logoSlug: (storedSlug?.isEmpty == false) ? storedSlug : resolveCarLogoSlug(manufacturer)
            )
        }
}
