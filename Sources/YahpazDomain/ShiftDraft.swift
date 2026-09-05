import Foundation

public let SHIFT_DRAFT_DATE_ERROR = "יש לבחור תאריך"
public let SHIFT_DRAFT_KIND_ERROR = "יש לבחור שם משמרת"
public let SHIFT_DRAFT_VEHICLE_ERROR = "יש לבחור סוג רכב"
public let SHIFT_DRAFT_CREW_ERROR = "יש לשבץ בין מתנדב אחד לשלושה"
public let SHIFT_DRAFT_PLATE_ERROR = "יש לבחור לוחית לרכב פרטי"
public let SHIFT_DRAFT_FORM_ERROR = "יש למלא תאריך, שם משמרת וסוג רכב לפני השמירה."
public let SHIFT_DRAFT_SAVE_FAILED = "שמירת המשמרת נכשלה. בדקו את החיבור ונסו שוב."
public let SHIFT_DRAFT_SAVED = "המשמרת נשמרה."
public let SHIFT_NEW_TITLE = "משמרת חדשה"
public let SHIFT_EDIT_TITLE = "עריכת משמרת"
public let SHIFT_SAVE_TITLE = "שמירה"
public let SHIFT_ASSIGN_OPEN = "שיבוץ מתנדבים"
public let SHIFT_ASSIGN_CLOSE = "סגירת שיבוץ"
public let SHIFT_ASSIGN_EMPTY = "יש לשבץ מתנדבים למשמרת."
public let SHIFT_EDIT_LOAD_FAILED = "טעינת המשמרת נכשלה. בדקו את החיבור ונסו שוב."
public let UNIT_SHIFTS_LOAD_FAILED = "טעינת המשמרות נכשלה. בדקו את החיבור ונסו שוב."
public let EVENT_ASSIGN_REMOVE = "הסרת מתנדב"

public let SHIFT_CREW_MIN = 1
public let SHIFT_CREW_MAX = 3

/// Order matches the web `SHIFT_KIND_OPTIONS`.
public let SHIFT_KIND_ORDER = ["morning", "midday", "reinforcement", "escort", "other"]

/// Patrol vehicles are always offered. Personal is added only when a selected crew
/// member has a plate in the vehicles lookup — same gate as the web form.
public let SHIFT_VEHICLE_TYPE_ORDER = ["patrol_north", "patrol_center"]

public func offeredShiftVehicleTypes(includePersonal: Bool) -> [String] {
    includePersonal ? SHIFT_VEHICLE_TYPE_ORDER + ["personal"] : SHIFT_VEHICLE_TYPE_ORDER
}

public func shiftKindLabel(_ kind: String) -> String {
    SHIFT_KIND_LABELS[kind] ?? kind
}

public func shiftVehicleTypeLabel(_ vehicleType: String) -> String {
    VEHICLE_TYPE_LABELS[vehicleType] ?? vehicleType
}

public func crewVehicleLabel(plateNumber: String, model: String?) -> String {
    let plate = formatPlate(plateNumber)
    let modelText = model?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return modelText.isEmpty ? plate : "\(plate) · \(modelText)"
}

/// Drop a personal plate that no longer belongs to the assigned crew.
public func keepPersonalVehicleId(_ selectedId: String?, availableIds: Set<String>) -> String? {
    guard let selectedId, availableIds.contains(selectedId) else { return nil }
    return selectedId
}

public struct ShiftDraft: Equatable, Sendable {
    public var shiftDate: String
    public var shiftKind: String
    public var vehicleType: String
    public var notes: String
    public var responderIds: [String]
    public var personalVehicleId: String?

    public init(
        shiftDate: String,
        shiftKind: String = "",
        vehicleType: String = "",
        notes: String = "",
        responderIds: [String] = [],
        personalVehicleId: String? = nil
    ) {
        self.shiftDate = shiftDate
        self.shiftKind = shiftKind
        self.vehicleType = vehicleType
        self.notes = notes
        self.responderIds = responderIds
        self.personalVehicleId = personalVehicleId
    }
}

public struct ShiftDraftErrors: Equatable, Sendable {
    public var shiftDate: String?
    public var shiftKind: String?
    public var vehicleType: String?
    public var crew: String?
    public var plate: String?

    public init(
        shiftDate: String? = nil,
        shiftKind: String? = nil,
        vehicleType: String? = nil,
        crew: String? = nil,
        plate: String? = nil
    ) {
        self.shiftDate = shiftDate
        self.shiftKind = shiftKind
        self.vehicleType = vehicleType
        self.crew = crew
        self.plate = plate
    }

    public var isEmpty: Bool {
        shiftDate == nil && shiftKind == nil && vehicleType == nil && crew == nil && plate == nil
    }

    public var formMessage: String? {
        if isEmpty { return nil }
        if crew != nil && shiftDate == nil && shiftKind == nil && vehicleType == nil && plate == nil {
            return SHIFT_DRAFT_CREW_ERROR
        }
        return SHIFT_DRAFT_FORM_ERROR
    }
}

/// Minimal save gate: date + shift kind + vehicle type + one to three crew (+ plate when private).
public func validateShiftDraft(_ draft: ShiftDraft) -> ShiftDraftErrors {
    ShiftDraftErrors(
        shiftDate: normalizeReturnDate(draft.shiftDate) == nil ? SHIFT_DRAFT_DATE_ERROR : nil,
        shiftKind: draft.shiftKind.isEmpty ? SHIFT_DRAFT_KIND_ERROR : nil,
        vehicleType: draft.vehicleType.isEmpty ? SHIFT_DRAFT_VEHICLE_ERROR : nil,
        crew: (SHIFT_CREW_MIN...SHIFT_CREW_MAX).contains(draft.responderIds.count) ? nil : SHIFT_DRAFT_CREW_ERROR,
        plate: draft.vehicleType == "personal" && (draft.personalVehicleId?.isEmpty ?? true)
            ? SHIFT_DRAFT_PLATE_ERROR
            : nil
    )
}

public func shiftCrewSummary(_ count: Int) -> String {
    switch count {
    case 0: return "טרם שובצו מתנדבים"
    case 1: return "מתנדב אחד משובץ"
    default: return "\(count) מתנדבים משובצים"
    }
}

/// Selecting past the crew ceiling is ignored rather than silently dropping someone else.
public func toggleCrewSelection(_ selected: [String], responderId: String) -> [String] {
    if selected.contains(responderId) { return selected.filter { $0 != responderId } }
    if selected.count >= SHIFT_CREW_MAX { return selected }
    return selected + [responderId]
}

/// Date / kind / vehicle / plate may only be changed by unit managers.
/// Android never opens the unit form for a plain responder — same gate.
public func canEditShiftIdentity(_ roles: [String]) -> Bool {
    managesUnit(roles)
}

public struct AssignableProfile: Equatable, Identifiable, Sendable {
    public var id: String
    public var fullName: String
    public var callsign: String

    public init(id: String, fullName: String, callsign: String) {
        self.id = id
        self.fullName = fullName
        self.callsign = callsign
    }

    public var display: String {
        personDisplay(fullName, callsign: callsign)
    }

    public var searchFields: [String?] {
        [fullName, callsign]
    }
}

public func filterAssignableProfiles(_ profiles: [AssignableProfile], query: String) -> [AssignableProfile] {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return profiles }
    return profiles.filter { fieldsMatchQuery($0.searchFields, query: trimmed) }
}

public struct LookupOption: Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var code: String?
    public var sortOrder: Int

    public init(id: String, name: String, code: String? = nil, sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.code = code
        self.sortOrder = sortOrder
    }
}
