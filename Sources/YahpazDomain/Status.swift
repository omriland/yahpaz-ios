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

/// Responder-facing: they finished; the lead has not entered KM yet. Stamp stays הושלם.
public let LEAD_KM_PENDING_NOTE = "אחמ״ש טרם הזין ק״מ"

public func leadKmPendingNote(_ participation: ParticipationStatus?, totalKm: Double?) -> String? {
    if participation == .done && totalKm == nil { return LEAD_KM_PENDING_NOTE }
    return nil
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
