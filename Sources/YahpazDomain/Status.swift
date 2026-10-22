import Foundation

public enum EventStatus: String, Codable, Hashable, Sendable {
    case draft
    case inProgress = "in_progress"
    case partial
    case done
}

public enum ParticipationStatus: String, Codable, Hashable, Sendable {
    case pending
    case inProgress = "in_progress"
    case done
}

public enum StampTone: String, Sendable {
    case done
    case partial
    case pending
    case draft
    case alert
}

public struct StampDescriptor: Equatable, Sendable {
    public var label: String
    public var tone: StampTone

    public init(label: String, tone: StampTone) {
        self.label = label
        self.tone = tone
    }
}

public let MISSING_KM_STAMP_LABEL = "חסר ק״מ"

public func eventStamp(_ status: EventStatus) -> StampDescriptor {
    switch status {
    case .draft: return StampDescriptor(label: "אירוע בהזנה", tone: .draft)
    case .inProgress: return StampDescriptor(label: "ממתין לתיעוד", tone: .pending)
    case .partial: return StampDescriptor(label: "תועד חלקית", tone: .partial)
    case .done: return StampDescriptor(label: "הושלם", tone: .done)
    }
}

/// Viewer-relative documentation stamp for אחמ״ש lists.
/// Does not change event/participation status — only the lead-facing label.
public func reportingDocumentationStamp(_ status: EventStatus, missingKm: Bool) -> StampDescriptor {
    overlayMissingKmOnDoneStamp(eventStamp(status), missingKm: missingKm)
}

public func overlayMissingKmOnDoneStamp(_ stamp: StampDescriptor, missingKm: Bool) -> StampDescriptor {
    if missingKm && stamp.tone == .done && stamp.label == "הושלם" {
        return StampDescriptor(label: MISSING_KM_STAMP_LABEL, tone: .alert)
    }
    return stamp
}

public func cancelledStamp() -> StampDescriptor {
    StampDescriptor(label: "בוטל", tone: .draft)
}

public func participationStamp(_ status: ParticipationStatus, isViewer: Bool) -> StampDescriptor {
    if status == .done { return StampDescriptor(label: "הושלם", tone: .done) }
    if status == .inProgress && isViewer {
        return StampDescriptor(label: "טיוטה נשמרה", tone: .draft)
    }
    return StampDescriptor(label: isViewer ? "ממתין לתיעוד" : "ממתין למתנדב", tone: .pending)
}

/// Responder finished fill; lead KM still missing. Replaces הושלם on their own stamp.
public let FILL_DONE_AWAITING_KM_LABEL = "סיימת לתעד"

/// Responder-facing: they finished; the lead has not entered KM yet.
public let LEAD_KM_PENDING_NOTE = "אחמ״ש טרם הזין ק״מ"

/// Responder-facing: they finished; the lead still owes end time (or other done-gate fields).
public let AWAITING_LEAD_DETAILS_NOTE = "ממתין לפרטים נוספים מאחמש"

/// Lead-owned field that keeps stored status from becoming `done`.
public func eventMissingLeadDoneDetails(endedAt: String?) -> Bool {
    endedAt?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
}

public func leadKmPendingNote(
    _ participation: ParticipationStatus?,
    totalKm: Double?,
    origin: String? = nil,
    missingLeadDetails: Bool = false
) -> String? {
    if origin == "shift" { return nil }
    if participation != .done { return nil }
    if missingLeadDetails { return AWAITING_LEAD_DETAILS_NOTE }
    return totalKm == nil ? LEAD_KM_PENDING_NOTE : nil
}

/// Own-row stamp for mine inbox / fill / detail: סיימת לתעד when lead KM is still null.
public func mineParticipationStamp(
    _ status: ParticipationStatus?,
    totalKm: Double?,
    missingLeadDetails: Bool = false
) -> StampDescriptor {
    let resolved = status ?? .pending
    if resolved == .done && missingLeadDetails { return eventStamp(.partial) }
    if resolved == .done && totalKm == nil {
        return StampDescriptor(label: FILL_DONE_AWAITING_KM_LABEL, tone: .done)
    }
    return participationStamp(resolved, isViewer: true)
}

/// Mine inbox: fill still open, or fill done but lead KM is missing.
public func mineInboxIsOpen(_ participation: ParticipationStatus?, totalKm: Double?) -> Bool {
    if participation != .done { return true }
    return totalKm == nil
}

public func mineFillCtaLabel(_ status: ParticipationStatus) -> String? {
    switch status {
    case .done: return nil
    case .inProgress: return "המשך התיעוד"
    case .pending: return "השלמת התיעוד שלי"
    }
}

public func deriveEventStatusAfterParticipation(
    _ statuses: [ParticipationStatus]
) -> EventStatus {
    if statuses.isEmpty { return .draft }
    if statuses.allSatisfy({ $0 == .done }) { return .done }
    if statuses.contains(.done) { return .partial }
    return .inProgress
}
