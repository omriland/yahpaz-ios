import Foundation

public let ASSIGNED_VOLUNTEER_EVENT_EDIT_ERROR =
    "לא ניתן לערוך אירוע עליו אתה מוצב כמתנדב. לעדכון פרטים יש לפנות לאחמ\"ש המזין או למנהל מערכת"
public let ASSIGNED_VOLUNTEER_EVENT_EDIT_CLOSE = "סגירה"

/**
 True when the viewer has an event_responders row or is a secondary אחמ״ש.
 Role (including admin combo) does not bypass — they fill as a volunteer.
 */
public func isAssignedVolunteerEventEditBlocked(
    viewerId: String?,
    responderIds: [String?],
    secondaryLeadIds: [String?]
) -> Bool {
    let viewer = viewerId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if viewer.isEmpty { return false }
    if responderIds.contains(where: { $0?.trimmingCharacters(in: .whitespacesAndNewlines) == viewer }) {
        return true
    }
    if secondaryLeadIds.contains(where: { $0?.trimmingCharacters(in: .whitespacesAndNewlines) == viewer }) {
        return true
    }
    return false
}

extension EventDraft {
    public func blocksAssignedVolunteerEdit(viewerId: String?) -> Bool {
        isAssignedVolunteerEventEditBlocked(
            viewerId: viewerId,
            responderIds: responders.map { $0.responderId },
            secondaryLeadIds: secondaryLeads.map { $0.userId }
        )
    }
}
