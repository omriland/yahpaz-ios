import Foundation

public let COCKPIT_DELETE_RESPONDERS = "יש מתנדבים משובצים. הסירו אותם תחילה."
public let COCKPIT_DELETE_CONFIRM_AGAIN = "לחצו שוב למחיקה."

public enum CockpitDeleteBlock: Sendable, Equatable {
    case responders
    case otherLead
}

public enum CockpitDeleteClick: Sendable, Equatable {
    case blocked(CockpitDeleteBlock)
    case arm
    case delete
}

public struct CockpitDeleteViewer: Equatable, Sendable {
    public var userId: String?
    public var isAdmin: Bool

    public init(userId: String?, isAdmin: Bool) {
        self.userId = userId
        self.isAdmin = isAdmin
    }
}

/// Blocked while responders remain, or when an אחמ״ש views another lead's event.
public func cockpitDeleteBlock(
    responderCount: Int,
    shiftLeadId: String?,
    viewer: CockpitDeleteViewer?
) -> CockpitDeleteBlock? {
    if let viewer,
       !viewer.isAdmin,
       !(viewer.userId ?? "").isEmpty,
       !(shiftLeadId ?? "").isEmpty,
       shiftLeadId != viewer.userId
    {
        return .otherLead
    }
    if responderCount > 0 { return .responders }
    return nil
}

public func shouldShowCockpitDelete(_ block: CockpitDeleteBlock?) -> Bool {
    block != .otherLead
}

public func cockpitDeleteHint(_ block: CockpitDeleteBlock?) -> String {
    switch block {
    case .responders: return COCKPIT_DELETE_RESPONDERS
    case .otherLead: return EVENT_DELETE_OTHER_LEAD
    case nil: return COCKPIT_DELETE_CONFIRM_AGAIN
    }
}

public func cockpitDeleteClick(
    armed: Bool,
    responderCount: Int,
    shiftLeadId: String?,
    viewer: CockpitDeleteViewer?
) -> CockpitDeleteClick {
    if let block = cockpitDeleteBlock(
        responderCount: responderCount,
        shiftLeadId: shiftLeadId,
        viewer: viewer
    ) {
        return .blocked(block)
    }
    return armed ? .delete : .arm
}
