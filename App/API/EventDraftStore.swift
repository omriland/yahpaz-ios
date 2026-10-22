import Foundation
import YahpazDomain

struct StashedEventForm {
    var draft: EventDraft
    /// The form session that wrote it; once that session's row exists the stash is stale.
    var session: String
}

/// Device copy of a new event the lead has not saved yet, so a closed form,
/// a killed app, or a dead network does not lose typed notes, road, location
/// or assigned crew. Same 24-hour window as Android `EventDraftStore`; scoped to
/// the user who typed it so the next person on the phone never inherits it.
@MainActor
enum EventDraftStore {
    private static let key = "yahpaz_event_draft.new_event_draft"
    private static let maxAgeMs: Int64 = 24 * 60 * 60 * 1000
    private static let defaults = UserDefaults.standard

    static func stash(
        _ draft: EventDraft,
        session: String,
        userId: String?,
        now: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) {
        let payload = StashedEventPayload(savedAt: now, session: session, userId: userId, draft: StashedEventDraft(draft))
        guard let data = try? JSONEncoder().encode(payload) else { return }
        defaults.set(data, forKey: key)
    }

    static func read(userId: String?, now: Int64 = Int64(Date().timeIntervalSince1970 * 1000)) -> StashedEventForm? {
        guard let data = defaults.data(forKey: key) else { return nil }
        guard let parsed = try? JSONDecoder().decode(StashedEventPayload.self, from: data) else {
            clear()
            return nil
        }
        if now - parsed.savedAt > maxAgeMs || parsed.userId != userId {
            clear()
            return nil
        }
        return StashedEventForm(draft: parsed.draft.toDomain(), session: parsed.session)
    }

    static func clear() {
        defaults.removeObject(forKey: key)
    }

    /// Clears the stash only if `session` wrote it, so a later form's draft survives.
    static func clear(session: String) {
        guard let data = defaults.data(forKey: key),
              let parsed = try? JSONDecoder().decode(StashedEventPayload.self, from: data),
              parsed.session == session
        else { return }
        clear()
    }
}

private struct StashedEventPayload: Codable {
    var savedAt: Int64
    var session: String
    var userId: String?
    var draft: StashedEventDraft
}

private struct StashedEventDraft: Codable {
    var eventDate: String
    var policeEventId: String
    var patrolCallsign: String
    var patrolCallsignPrefix: String
    var patrolCallsignNumber: String
    var startTime: String
    var endTime: String
    var eventTypeId: String
    var roadId: String
    var districtId: String
    var location: String
    var locationPlaceId: String?
    var locationLat: Double?
    var locationLng: Double?
    var locationPinSource: String?
    var locationPinnedAt: String?
    var locationPinnedBy: String?
    var station: String
    var notes: String
    var isCancelled: Bool
    var busLane: Bool
    var shiftLeadId: String
    var responders: [StashedEventResponder]
    var secondaryLeads: [StashedSecondaryLead]

    init(_ draft: EventDraft) {
        eventDate = draft.eventDate
        policeEventId = draft.policeEventId
        patrolCallsign = draft.patrolCallsign
        patrolCallsignPrefix = draft.patrolCallsignPrefix
        patrolCallsignNumber = draft.patrolCallsignNumber
        startTime = draft.startTime
        endTime = draft.endTime
        eventTypeId = draft.eventTypeId
        roadId = draft.roadId
        districtId = draft.districtId
        location = draft.location
        locationPlaceId = draft.locationPlaceId
        locationLat = draft.locationLat
        locationLng = draft.locationLng
        locationPinSource = draft.locationPinSource
        locationPinnedAt = draft.locationPinnedAt
        locationPinnedBy = draft.locationPinnedBy
        station = draft.station
        notes = draft.notes
        isCancelled = draft.isCancelled
        busLane = draft.busLane
        shiftLeadId = draft.shiftLeadId
        responders = draft.responders.map(StashedEventResponder.init)
        secondaryLeads = draft.secondaryLeads.map(StashedSecondaryLead.init)
    }

    func toDomain() -> EventDraft {
        EventDraft(
            eventDate: eventDate,
            policeEventId: policeEventId,
            patrolCallsign: patrolCallsign,
            patrolCallsignPrefix: patrolCallsignPrefix,
            patrolCallsignNumber: patrolCallsignNumber,
            startTime: startTime,
            endTime: endTime,
            eventTypeId: eventTypeId,
            roadId: roadId,
            districtId: districtId,
            location: location,
            locationPlaceId: locationPlaceId,
            locationLat: locationLat,
            locationLng: locationLng,
            locationPinSource: locationPinSource,
            locationPinnedAt: locationPinnedAt,
            locationPinnedBy: locationPinnedBy,
            station: station,
            notes: notes,
            responders: responders.map(\.toDomain),
            isCancelled: isCancelled,
            busLane: busLane,
            shiftLeadId: shiftLeadId,
            secondaryLeads: secondaryLeads.map(\.toDomain)
        )
    }
}

private struct StashedEventResponder: Codable {
    var responderId: String
    var assignmentId: String
    var totalKm: String
    var emergencyMeans: Bool
    var hasVehicle: Bool
    var status: String
    var treated: [StashedTreatedVehicle]

    init(_ row: EventResponderDraft) {
        responderId = row.responderId
        assignmentId = row.assignmentId
        totalKm = row.totalKm
        emergencyMeans = row.emergencyMeans
        hasVehicle = row.hasVehicle
        status = row.status.rawValue
        treated = row.treated.map { StashedTreatedVehicle(vehicleKindId: $0.vehicleKindId, quantity: $0.quantity) }
    }

    var toDomain: EventResponderDraft {
        EventResponderDraft(
            responderId: responderId,
            assignmentId: assignmentId,
            totalKm: totalKm,
            emergencyMeans: emergencyMeans,
            treated: treated.map { TreatedVehicleDraft(vehicleKindId: $0.vehicleKindId, quantity: $0.quantity) },
            status: ParticipationStatus(rawValue: status) ?? .pending,
            hasVehicle: hasVehicle
        )
    }
}

private struct StashedTreatedVehicle: Codable {
    var vehicleKindId: String
    var quantity: Int
}

private struct StashedSecondaryLead: Codable {
    var userId: String
    var locked: Bool
    var fullName: String
    var callsign: String
    var addedAt: String?

    init(_ lead: SecondaryLead) {
        userId = lead.userId
        locked = lead.locked
        fullName = lead.fullName
        callsign = lead.callsign
        addedAt = lead.addedAt
    }

    var toDomain: SecondaryLead {
        SecondaryLead(userId: userId, locked: locked, fullName: fullName, callsign: callsign, addedAt: addedAt)
    }
}
