import Foundation

public struct ResponderFillDraft: Equatable, Sendable {
    public var vehiclePlate: String
    public var odometerStart: String
    public var odometerEnd: String
    public var route: String
    public var treatmentDetail: String
    public var treatmentNotes: String
    public var treatedPlates: [TreatedPlate]
    public var treatedPlatePending: String

    public init(
        vehiclePlate: String = "",
        odometerStart: String = "",
        odometerEnd: String = "",
        route: String = "",
        treatmentDetail: String = "",
        treatmentNotes: String = "",
        treatedPlates: [TreatedPlate] = [],
        treatedPlatePending: String = ""
    ) {
        self.vehiclePlate = vehiclePlate
        self.odometerStart = odometerStart
        self.odometerEnd = odometerEnd
        self.route = route
        self.treatmentDetail = treatmentDetail
        self.treatmentNotes = treatmentNotes
        self.treatedPlates = treatedPlates
        self.treatedPlatePending = treatedPlatePending
    }

    public static func empty() -> ResponderFillDraft {
        ResponderFillDraft()
    }
}

public struct ResponderFillErrors: Equatable, Sendable {
    public var vehiclePlate: String?
    public var odometerStart: String?
    public var odometerEnd: String?
    public var route: String?
    public var treatmentDetail: String?
    public var treatedPlates: String?
    public var eventMedia: String?
    public var form: String?

    public init(
        vehiclePlate: String? = nil,
        odometerStart: String? = nil,
        odometerEnd: String? = nil,
        route: String? = nil,
        treatmentDetail: String? = nil,
        treatedPlates: String? = nil,
        eventMedia: String? = nil,
        form: String? = nil
    ) {
        self.vehiclePlate = vehiclePlate
        self.odometerStart = odometerStart
        self.odometerEnd = odometerEnd
        self.route = route
        self.treatmentDetail = treatmentDetail
        self.treatedPlates = treatedPlates
        self.eventMedia = eventMedia
        self.form = form
    }

    public var isEmpty: Bool {
        vehiclePlate == nil
            && odometerStart == nil
            && odometerEnd == nil
            && route == nil
            && treatmentDetail == nil
            && treatedPlates == nil
            && eventMedia == nil
            && form == nil
    }

    public var firstMessage: String? {
        form
            ?? vehiclePlate
            ?? odometerStart
            ?? odometerEnd
            ?? route
            ?? treatmentDetail
            ?? treatedPlates
            ?? eventMedia
    }
}

public enum FillMode: String, Sendable {
    case draft
    case complete
}

private enum ParsedNumber {
    case missing
    case invalid
    case value(Double)
}

private func parseOptionalNumber(_ raw: String) -> ParsedNumber {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return .missing }
    guard let value = Double(trimmed), value.isFinite else { return .invalid }
    return .value(value)
}

public func validateResponderFillDraft(
    _ draft: ResponderFillDraft,
    mode: FillMode,
    allowedPlates: [String] = [],
    totalKm: Double? = nil,
    unfinishedMediaDraftCount: Int = 0
) -> ResponderFillErrors {
    var errors = ResponderFillErrors()
    let start = parseOptionalNumber(draft.odometerStart)
    let end = parseOptionalNumber(draft.odometerEnd)
    let plate = plateDigits(draft.vehiclePlate)
    let allowed = Set(allowedPlates.map(plateDigits).filter { !$0.isEmpty })

    if case .invalid = start { errors.odometerStart = "מד אוץ התחלה חייב להיות מספר." }
    if case .invalid = end { errors.odometerEnd = "מד אוץ סיום חייב להיות מספר." }

    if mode == .complete {
        if plate.isEmpty {
            errors.vehiclePlate = "יש לבחור רכב."
        } else if !allowed.isEmpty && !allowed.contains(plate) {
            errors.vehiclePlate = "יש לבחור רכב מהרשימה המקושרת למשתמש."
        } else if allowed.isEmpty {
            errors.vehiclePlate = "לא מקושר רכב למשתמש. פנו למנהל המערכת."
        }
        switch start {
        case .missing, .invalid:
            errors.odometerStart = "יש למלא מד אוץ התחלה."
        case .value:
            break
        }
        switch end {
        case .missing, .invalid:
            errors.odometerEnd = "יש למלא מד אוץ סיום."
        case .value:
            break
        }
        if draft.route.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.route = "יש למלא נתיב נסיעה."
        }
        if draft.treatmentDetail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.treatmentDetail = "יש למלא פירוט הטיפול."
        }
    }

    if errors.odometerEnd == nil,
       case let .value(startValue) = start,
       case let .value(endValue) = end,
       endValue < startValue
    {
        errors.odometerEnd = "מד אוץ סיום אינו יכול להיות קטן ממד אוץ התחלה"
    }

    if let leftover = leftoverTreatedPlateError(pending: draft.treatedPlatePending, mode: mode) {
        errors.treatedPlates = leftover
    }
    if let leftover = leftoverEventMediaError(unfinishedDraftCount: unfinishedMediaDraftCount, mode: mode) {
        errors.eventMedia = leftover
    }

    return errors
}

public func odometerRangeError(odometerStart: String, odometerEnd: String) -> String? {
    guard case let .value(start) = parseOptionalNumber(odometerStart),
          case let .value(end) = parseOptionalNumber(odometerEnd)
    else { return nil }
    if end < start { return "מד אוץ סיום אינו יכול להיות קטן ממד אוץ התחלה" }
    return nil
}

public func parsedOdometer(_ raw: String) -> Double? {
    switch parseOptionalNumber(raw) {
    case .value(let value): return value
    case .missing, .invalid: return nil
    }
}

public enum FillWriteGate: String, Equatable, Sendable {
    case proceed
    case locked
    case alreadyComplete
}

/** Completing an already-done assignment is success; drafts stay locked. */
public func gateResponderFillWrite(
    complete: Bool,
    participationStatus: ParticipationStatus,
    eventStatus: EventStatus?
) -> FillWriteGate {
    if participationStatus == .done {
        return complete ? .alreadyComplete : .locked
    }
    if eventStatus == .done { return .locked }
    return .proceed
}
