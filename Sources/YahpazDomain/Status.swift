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
}

public struct StampDescriptor: Equatable, Sendable {
    public var label: String
    public var tone: StampTone

    public init(label: String, tone: StampTone) {
        self.label = label
        self.tone = tone
    }
}

public func eventStamp(_ status: EventStatus) -> StampDescriptor {
    switch status {
    case .draft: return StampDescriptor(label: "אירוע בהזנה", tone: .draft)
    case .inProgress: return StampDescriptor(label: "ממתין לתיעוד", tone: .pending)
    case .partial: return StampDescriptor(label: "תועד חלקית", tone: .partial)
    case .done: return StampDescriptor(label: "הושלם", tone: .done)
    }
}

public func cancelledStamp() -> StampDescriptor {
    StampDescriptor(label: "בוטל", tone: .draft)
}

public func participationStamp(_ status: ParticipationStatus, isViewer: Bool) -> StampDescriptor {
    if status == .done { return StampDescriptor(label: "הושלם", tone: .done) }
    if status == .inProgress && isViewer {
        return StampDescriptor(label: "טיוטה נשמרה", tone: .draft)
    }
    return StampDescriptor(label: isViewer ? "ממתין למילוי פרטים" : "ממתין לכונן", tone: .pending)
}

public func mineFillCtaLabel(_ status: ParticipationStatus) -> String? {
    switch status {
    case .done: return nil
    case .inProgress: return "המשך מילוי הפרטים"
    case .pending: return "השלמת הפרטים שלי"
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
