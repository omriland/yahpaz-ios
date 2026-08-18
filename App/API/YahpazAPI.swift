import Foundation
import Supabase
import YahpazDomain

private let eventListSelect = """
id, event_date, police_event_id, location, status, is_cancelled, origin, shift_id,
event_type:event_types(name),
road:roads(name),
shift_lead:profiles!events_shift_lead_id_fkey(full_name, callsign),
shift:shifts!events_shift_id_fkey(
  shift_date, shift_kind, vehicle_type,
  personal_vehicle:vehicles!shifts_personal_vehicle_id_fkey(plate_number)
),
responders:event_responders(id, responder_id, status)
"""

private let fillSelect = """
id, status, event_date, police_event_id, location, is_cancelled,
event_type:event_types(name),
road:roads(name),
shift_lead:profiles!events_shift_lead_id_fkey(full_name, callsign),
responders:event_responders(
  id, responder_id, vehicle_plate, odometer_start, odometer_end, total_km,
  route, treatment_detail, treatment_notes, status, updated_at, ended_at,
  treated_plates:event_treated_plates(plate_number, model, color, sort_order)
)
"""

actor YahpazAPI {
    static let shared = YahpazAPI()

    let client: SupabaseClient

    init() {
        client = SupabaseClient(
            supabaseURL: AppConfig.supabaseURL,
            supabaseKey: AppConfig.supabaseAnonKey
        )
    }

    func sessionUserId() async -> String? {
        do {
            return try await client.auth.session.user.id.uuidString.lowercased()
        } catch {
            return nil
        }
    }

    func signIn(email: String, password: String) async -> String? {
        do {
            _ = try await client.auth.signIn(email: email, password: password)
            return nil
        } catch {
            let message = String(describing: error).lowercased()
            if message.contains("invalid login") {
                return "הדוא״ל או הסיסמה שגויים. נסו שוב."
            }
            return "הכניסה נכשלה. בדקו את החיבור ונסו שוב."
        }
    }

    func signOut() async {
        try? await client.auth.signOut()
    }

    func requestPasswordReset(email: String) async -> String? {
        do {
            try await client.auth.resetPasswordForEmail(
                email,
                redirectTo: AppConfig.passwordResetRedirect
            )
            return nil
        } catch {
            return "שליחת הקישור נכשלה. בדקו את החיבור ונסו שוב."
        }
    }

    func updatePassword(_ password: String) async -> String? {
        if let strength = passwordStrengthError(password) { return strength }
        do {
            try await client.auth.update(user: UserAttributes(password: password))
            try? await client.rpc("clear_must_change_password").execute()
            if let userId = await sessionUserId() {
                try? await client
                    .from("profiles")
                    .update(InviteClearRow(updatedAt: ISO8601DateFormatter().string(from: Date())))
                    .eq("id", value: userId)
                    .execute()
            }
            return nil
        } catch {
            return "שמירת הסיסמה נכשלה. נסו שוב."
        }
    }

    func loadProfile() async throws -> (ProfileRecord, [String]) {
        guard let userId = await sessionUserId() else {
            throw APIError.notSignedIn
        }
        async let profileReq: ProfileRecord = client
            .from("profiles")
            .select(
                "id, full_name, email, callsign, phone, active, must_change_password, availability, available_from, lifetime_event_count, lifetime_km, lifetime_stats_updated_at"
            )
            .eq("id", value: userId)
            .single()
            .execute()
            .value
        async let rolesReq: [RoleRow] = client
            .from("user_roles")
            .select("role")
            .eq("user_id", value: userId)
            .execute()
            .value
        let profile = try await profileReq
        let roles = try await rolesReq
        if profile.active == false {
            await signOut()
            throw APIError.inactive
        }
        return (profile, roles.map(\.role))
    }

    func fetchMyEvents() async throws -> [EventListItem] {
        guard let userId = await sessionUserId() else { return [] }
        let assignments: [AssignmentIdRow] = try await client
            .from("event_responders")
            .select("event_id")
            .eq("responder_id", value: userId)
            .execute()
            .value
        let ids = assignments.map(\.eventId)
        if ids.isEmpty { return [] }
        return try await client
            .from("events")
            .select(eventListSelect)
            .in("id", values: ids)
            .order("event_date", ascending: false)
            .execute()
            .value
    }

    func fetchFillContext(eventId: String) async throws -> FillContext? {
        guard let userId = await sessionUserId() else { return nil }
        async let eventReq: FillEventRow = client
            .from("events")
            .select(fillSelect)
            .eq("id", value: eventId)
            .single()
            .execute()
            .value
        async let vehiclesReq: [VehicleOption] = client
            .from("vehicles")
            .select("plate_number, model, archived")
            .eq("user_id", value: userId)
            .execute()
            .value
        let event = try await eventReq
        let vehicles = try await vehiclesReq
        guard let mine = event.responders.first(where: { $0.responderId == userId }) else {
            return nil
        }
        let existingPlate = plateDigits(mine.vehiclePlate ?? "")
        let options: [ResponderVehicle] = vehicles
            .map {
                ResponderVehicle(
                    plate: plateDigits($0.plateNumber),
                    model: $0.model?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                )
            }
            .filter { !$0.plate.isEmpty }
            .filter { vehicle in
                let archived = vehicles.first(where: { plateDigits($0.plateNumber) == vehicle.plate })?.archived ?? false
                return !archived || vehicle.plate == existingPlate
            }
        let allowed = Set(options.map(\.plate))
        let selected: String
        if !existingPlate.isEmpty, allowed.contains(existingPlate) {
            selected = existingPlate
        } else if options.count == 1 {
            selected = options[0].plate
        } else {
            selected = ""
        }
        return FillContext(
            eventId: event.id,
            assignmentId: mine.id,
            eventStatus: event.status,
            eventDate: event.eventDate,
            policeEventId: event.policeEventId,
            eventTypeName: event.eventType?.name,
            isCancelled: event.isCancelled,
            roadName: event.road?.name,
            location: event.location,
            shiftLeadName: event.shiftLead?.display,
            totalKm: mine.totalKm,
            participationStatus: mine.status,
            updatedAt: mine.updatedAt,
            draft: ResponderFillDraft(
                vehiclePlate: selected,
                odometerStart: mine.odometerStart.map { String(Int($0)) } ?? "",
                odometerEnd: mine.odometerEnd.map { String(Int($0)) } ?? "",
                route: mine.route ?? "",
                treatmentDetail: mine.treatmentDetail ?? "",
                treatmentNotes: mine.treatmentNotes ?? "",
                treatedPlates: mapTreatedPlateRows(mine.treatedPlates.map(\.asInput)),
                treatedPlatePending: ""
            ),
            vehicles: options,
            endedAt: mine.endedAt
        )
    }

    func saveFill(
        context: FillContext,
        draft: ResponderFillDraft,
        complete: Bool
    ) async -> String? {
        let errors = validateResponderFillDraft(
            draft,
            mode: complete ? .complete : .draft,
            allowedPlates: context.vehicles.map(\.plate),
            totalKm: context.totalKm
        )
        if !errors.isEmpty {
            return complete
                ? (errors.firstMessage ?? "יש למלא את כל שדות החובה לפני סיום הדיווח.")
                : (errors.firstMessage ?? "בדקו את השדות המסומנים.")
        }
        let start = parsedOdometer(draft.odometerStart)
        let end = parsedOdometer(draft.odometerEnd)
        do {
            let current: FillLockRow = try await client
                .from("event_responders")
                .select("status, event:events!inner(status)")
                .eq("id", value: context.assignmentId)
                .single()
                .execute()
                .value
            if current.status == .done || current.eventStatus == .done {
                return "לא ניתן לערוך דיווח שהושלם. רק אחמ״ש יכול לערוך."
            }
            let updated: [IdRow] = try await client
                .from("event_responders")
                .update(FillWrite(
                    vehiclePlate: plateNumberForSave(draft.vehiclePlate),
                    odometerStart: start,
                    odometerEnd: end,
                    route: draft.route.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    treatmentDetail: draft.treatmentDetail.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    treatmentNotes: draft.treatmentNotes.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    status: complete ? ParticipationStatus.done.rawValue : ParticipationStatus.inProgress.rawValue,
                    updatedAt: ISO8601DateFormatter().string(from: Date())
                ))
                .eq("id", value: context.assignmentId)
                .select("id")
                .execute()
                .value
            if updated.isEmpty {
                return "לא ניתן לערוך דיווח שהושלם. רק אחמ״ש יכול לערוך."
            }
            try await client
                .from("event_treated_plates")
                .delete()
                .eq("event_responder_id", value: context.assignmentId)
                .execute()
            if !draft.treatedPlates.isEmpty {
                try await client
                    .from("event_treated_plates")
                    .insert(
                        draft.treatedPlates.enumerated().map { index, row in
                            TreatedPlateWrite(
                                eventResponderId: context.assignmentId,
                                plateNumber: row.plateNumber,
                                model: row.model,
                                color: row.color,
                                sortOrder: index
                            )
                        }
                    )
                    .execute()
            }
            _ = try? await client
                .rpc("apply_event_status_from_participations", params: ["p_event_id": context.eventId])
                .execute()
            return nil
        } catch {
            return "שמירת הדיווח נכשלה. בדקו את החיבור ונסו שוב."
        }
    }

    func saveAvailability(userId: String, status: AvailabilityStatus, availableFrom: String?) async -> String? {
        let write = buildAvailabilityWrite(status: status, availableFrom: availableFrom, today: israelToday())
        switch write {
        case .error(let message):
            return message
        case let .ok(availability, from):
            do {
                try await client
                    .from("profiles")
                    .update(AvailabilityWriteRow(availability: availability.rawValue, availableFrom: from))
                    .eq("id", value: userId)
                    .execute()
                return nil
            } catch {
                return "עדכון הזמינות נכשל."
            }
        }
    }

    func loadTrack(token: String) async -> TrackLoadResponse {
        await invokeTrack(TrackCall(action: "load", trackToken: token, lat: nil, lng: nil, accuracyM: nil, recordedAt: nil))
    }

    func pingTrack(token: String, lat: Double, lng: Double, accuracy: Double?) async -> TrackLoadResponse {
        await invokeTrack(
            TrackCall(
                action: "ping",
                trackToken: token,
                lat: lat,
                lng: lng,
                accuracyM: accuracy,
                recordedAt: ISO8601DateFormatter().string(from: Date())
            )
        )
    }

    private func invokeTrack(_ body: TrackCall) async -> TrackLoadResponse {
        do {
            let response: TrackLoadResponse = try await client.functions.invoke(
                "responder-track",
                options: FunctionInvokeOptions(body: body)
            )
            return response
        } catch {
            return TrackLoadResponse(
                ok: false,
                error: "שיתוף המיקום נכשל. בדקו את החיבור ונסו שוב.",
                ended: nil,
                eventType: nil,
                road: nil,
                location: nil
            )
        }
    }
}

enum APIError: LocalizedError {
    case notSignedIn
    case inactive

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "יש להתחבר מחדש."
        case .inactive: return "החשבון אינו פעיל. פנו למנהל המערכת."
        }
    }
}

private struct InviteClearRow: Encodable {
    var invitePending = false
    var inviteToken: String? = nil
    var inviteTokenExpiresAt: String? = nil
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case invitePending = "invite_pending"
        case inviteToken = "invite_token"
        case inviteTokenExpiresAt = "invite_token_expires_at"
        case updatedAt = "updated_at"
    }
}

private struct TrackCall: Encodable {
    var action: String
    var trackToken: String
    var lat: Double?
    var lng: Double?
    var accuracyM: Double?
    var recordedAt: String?

    enum CodingKeys: String, CodingKey {
        case action
        case trackToken = "track_token"
        case lat, lng
        case accuracyM = "accuracy_m"
        case recordedAt = "recorded_at"
    }
}

private struct FillWrite: Encodable {
    var vehiclePlate: String?
    var odometerStart: Double?
    var odometerEnd: Double?
    var route: String?
    var treatmentDetail: String?
    var treatmentNotes: String?
    var status: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case vehiclePlate = "vehicle_plate"
        case odometerStart = "odometer_start"
        case odometerEnd = "odometer_end"
        case route
        case treatmentDetail = "treatment_detail"
        case treatmentNotes = "treatment_notes"
        case status
        case updatedAt = "updated_at"
    }
}

private struct AvailabilityWriteRow: Encodable {
    var availability: String
    var availableFrom: String?
    enum CodingKeys: String, CodingKey {
        case availability
        case availableFrom = "available_from"
    }
}

private struct FillLockRow: Decodable {
    var status: ParticipationStatus
    var eventStatus: EventStatus?

    enum CodingKeys: String, CodingKey {
        case status
        case event
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = try c.decode(ParticipationStatus.self, forKey: .status)
        if let nested = try? c.decode(EventStatusHolder.self, forKey: .event) {
            eventStatus = nested.status
        } else if let nested = try? c.decode([EventStatusHolder].self, forKey: .event) {
            eventStatus = nested.first?.status
        } else {
            eventStatus = nil
        }
    }
}

private struct EventStatusHolder: Decodable {
    var status: EventStatus
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
