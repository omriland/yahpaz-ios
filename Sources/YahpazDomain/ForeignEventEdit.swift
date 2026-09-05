import Foundation

public let FOREIGN_EVENT_EDIT_BODY = "כל שינוי שתבצע יתועד ויישמר במערכת"
public let FOREIGN_EVENT_EDIT_CONFIRM = "עריכה"
public let FOREIGN_EVENT_EDIT_CANCEL = "ביטול"
public let FOREIGN_EVENT_EDIT_LEAD_FALLBACK = "אחמ״ש אחר"

public func isForeignShiftLeadEvent(viewerId: String?, shiftLeadId: String?) -> Bool {
    let viewer = viewerId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let lead = shiftLeadId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return !viewer.isEmpty && !lead.isEmpty && viewer != lead
}

public func foreignEventEditLeadName(fullName: String?, callsign: String?) -> String {
    let name = fullName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !name.isEmpty { return name }
    let sign = callsign?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return sign.isEmpty ? FOREIGN_EVENT_EDIT_LEAD_FALLBACK : sign
}

public func foreignEventEditTitle(_ leadName: String) -> String {
    "האם אתה בטוח שברצונך לערוך אירוע שהוזן על ידי \(leadName)?"
}
