import Foundation

/// Manual events stay off the responder until או״ק (the number), כביש, and
/// מספר אירוע are all filled. Shift-born events stay visible — responders fill
/// those before a police id exists.
public func eventReleasedToResponders(
    origin: String?,
    policeEventId: String?,
    patrolCallsignNumber: String? = nil,
    hasRoad: Bool = false,
    patrolCallsignLegacy: String? = nil,
    patrolCallsignPrefix: String? = nil
) -> Bool {
    if origin == "shift" { return true }
    if policeEventId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true { return false }
    if !hasRoad { return false }
    let callsign = resolvePatrolCallsign(
        prefix: patrolCallsignPrefix,
        number: patrolCallsignNumber,
        legacy: patrolCallsignLegacy
    )
    return !callsign.number.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}
