import Foundation

public let ASSIGNED_VOLUNTEER_EVENT_EDIT_ERROR =
    "לא ניתן לערוך אירוע עליו אתה מוצב כמתנדב. לעדכון פרטים יש לפנות לאחמ\"ש המזין או למנהל מערכת"
public let ASSIGNED_VOLUNTEER_EVENT_EDIT_CLOSE = "סגירה"

/**
 True when the viewer has an event_responders row.
 אחמ״ש משני is a co-lead, not a volunteer — that assignment must not block edit.
 Role (including admin combo) does not bypass a real responder row.
 */
public func isAssignedVolunteerEventEditBlocked(
    viewerId: String?,
    responderIds: [String?],
    secondaryLeadIds _: [String?]
) -> Bool {
    let viewer = viewerId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if viewer.isEmpty { return false }
    return responderIds.contains(where: { $0?.trimmingCharacters(in: .whitespacesAndNewlines) == viewer })
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
