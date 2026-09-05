import Foundation
import Supabase
import YahpazDomain

private let EVENT_SECONDARY_LEADS_EMBED =
    "secondary_leads:event_secondary_leads(user_id, locked, added_at, profile:profiles!event_secondary_leads_user_id_fkey(full_name, callsign))"

private let eventListSelect = """
id, event_date, police_event_id, patrol_callsign, location, status, is_cancelled, bus_lane, origin, shift_lead_id, shift_id,
frozen_over_60km, frozen_suspicious_duplicate,
district:districts(name),
event_type:event_types(name),
road:roads(name),
shift_lead:profiles!events_shift_lead_id_fkey(full_name, callsign),
\(EVENT_SECONDARY_LEADS_EMBED),
shift:shifts!events_shift_id_fkey(
  shift_date, shift_kind, vehicle_type,
  personal_vehicle:vehicles!shifts_personal_vehicle_id_fkey(plate_number)
),
responders:event_responders(id, responder_id, status, fill_completable_at, total_km, started_at, ended_at, profile:profiles(full_name, callsign))
"""

private let shiftListSelect = """
id, shift_date, shift_kind, vehicle_type, status, odometer_start, odometer_end,
personal_vehicle:vehicles!shifts_personal_vehicle_id_fkey(plate_number),
shift_lead:profiles!shifts_shift_lead_id_fkey(full_name, callsign),
responders:shift_responders(id, responder_id),
born_events:events!events_shift_id_fkey(
  id, event_date, police_event_id, status,
  event_type:event_types(name)
)
"""

private let fillSelect = """
id, status, event_date, police_event_id, location, is_cancelled,
event_type:event_types(name),
road:roads(name),
shift_lead:profiles!events_shift_lead_id_fkey(full_name, callsign),
responders:event_responders(
  id, responder_id, vehicle_plate, odometer_start, odometer_end, total_km,
  route, treatment_detail, treatment_notes, status, updated_at, ended_at,
  treated_plates:event_treated_plates(plate_number, model, color, left_where, manufacturer, logo_slug, sort_order)
)
"""

private let reportEventSelect = """
id, event_date, is_cancelled, police_event_id, location,
event_type:event_types(name),
district:districts(name),
road:roads(name),
shift_lead:profiles!events_shift_lead_id_fkey(full_name, callsign),
responders:event_responders(
  responder_id, total_km,
  profile:profiles(full_name, callsign)
)
"""

private let kmDiscrepancySelect = """
id, event_date, is_cancelled, police_event_id, location,
road:roads(name),
shift_lead:profiles!events_shift_lead_id_fkey(full_name, callsign),
responders:event_responders(
  id, status, total_km, odometer_start, odometer_end,
  profile:profiles(full_name, callsign)
)
"""

private let duplicateEventSelect = """
id, event_date, is_cancelled, police_event_id, location,
event_type:event_types(name),
road:roads(name),
responders:event_responders(
  responder_id, started_at,
  profile:profiles(full_name, callsign)
)
"""

private let openDocSelect = """
id, event_date, status, is_cancelled, police_event_id, location, shift_lead_id,
road:roads(name),
shift_lead:profiles!events_shift_lead_id_fkey(full_name, callsign),
responders:event_responders(
  responder_id, status,
  profile:profiles(full_name, callsign)
)
"""

enum EventMediaWriteResult: Equatable {
    case uploaded(EventMedia)
    case done
    case error(String)
}

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
        let loginEmail = normalizeLoginEmail(email)
        let loginPassword = normalizeLoginSecret(password)
        do {
            _ = try await client.auth.signIn(email: loginEmail, password: loginPassword)
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
        ViewAsStore.clearAll()
        try? await client.auth.signOut()
    }

    func startImpersonation(targetUserId: String) async -> String? {
        if ViewAsStore.readImpersonation() != nil { return IMPERSONATION_ALREADY }
        ViewAsStore.clearRolePreview()
        guard let session = try? await client.auth.session else {
            return "יש להתחבר מחדש."
        }
        let actorId = session.user.id.uuidString.lowercased()
        do {
            let payload: AdminUsersResponse = try await client.functions.invoke(
                "admin-users",
                options: functionOptions(
                    body: ImpersonateCall(action: "impersonate", targetUserId: targetUserId)
                )
            )
            if let error = payload.error { return error }
            guard let access = payload.accessToken, !access.isEmpty,
                  let refresh = payload.refreshToken, !refresh.isEmpty,
                  let target = payload.target
            else {
                return IMPERSONATION_OPEN_FAILED
            }
            ViewAsStore.writeImpersonation(
                ImpersonationStash(
                    actorAccessToken: session.accessToken,
                    actorRefreshToken: session.refreshToken,
                    actorUserId: actorId,
                    targetUserId: target.id,
                    targetFullName: target.fullName,
                    targetCallsign: target.callsign
                )
            )
            do {
                _ = try await client.auth.setSession(accessToken: access, refreshToken: refresh)
                return nil
            } catch {
                ViewAsStore.clearImpersonation()
                return IMPERSONATION_OPEN_FAILED
            }
        } catch {
            return IMPERSONATION_OPEN_FAILED
        }
    }

    func stopImpersonation() async -> String? {
        guard let stash = ViewAsStore.readImpersonation() else { return IMPERSONATION_NONE }
        do {
            _ = try await client.auth.setSession(
                accessToken: stash.actorAccessToken,
                refreshToken: stash.actorRefreshToken
            )
            ViewAsStore.clearImpersonation()
            let _: AdminUsersResponse? = try? await client.functions.invoke(
                "admin-users",
                options: functionOptions(
                    body: ImpersonateCall(action: "stop_impersonation", targetUserId: stash.targetUserId)
                )
            )
            return nil
        } catch {
            ViewAsStore.clearImpersonation()
            return IMPERSONATION_RESTORE_FAILED
        }
    }

    func fetchImpersonationCandidates(actorUserId: String) async throws -> [AdminUserListItem] {
        try await fetchAdminUsers().filter { row in
            canImpersonateTarget(
                actorUserId: actorUserId,
                target: ImpersonationTarget(id: row.id, active: row.active, roles: row.roles)
            )
        }
    }

    /// Same `report_android_session` RPC as Android. Schema has no platform column.
    func reportSession(versionCode: Int, versionName: String) async throws {
        try await client
            .rpc(
                SESSION_REPORT_RPC,
                params: ReportSessionCall(versionCode: versionCode, versionName: versionName)
            )
            .execute()
    }

    func upsertDeviceToken(_ token: String, environment: String) async {
        _ = try? await client
            .rpc(
                "upsert_device_token",
                params: [
                    "p_token": token,
                    "p_platform": "ios",
                    "p_environment": environment,
                ]
            )
            .execute()
    }

    func deleteDeviceToken(_ token: String) async {
        _ = try? await client
            .from("device_tokens")
            .delete()
            .eq("token", value: token)
            .execute()
    }

    func requestPasswordReset(email: String) async -> String? {
        do {
            try await client.auth.resetPasswordForEmail(
                normalizeLoginEmail(email),
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

    func fetchMyShifts() async throws -> [ShiftListItem] {
        guard let userId = await sessionUserId() else { return [] }
        let assignments: [ShiftAssignmentIdRow] = try await client
            .from("shift_responders")
            .select("shift_id")
            .eq("responder_id", value: userId)
            .execute()
            .value
        let ids = assignments.map(\.shiftId)
        if ids.isEmpty { return [] }
        var rows: [ShiftListItem] = []
        for chunkStart in stride(from: 0, to: ids.count, by: 100) {
            let chunk = Array(ids[chunkStart..<min(chunkStart + 100, ids.count)])
            let part: [ShiftListItem] = try await client
                .from("shifts")
                .select(shiftListSelect)
                .in("id", values: chunk)
                .execute()
                .value
            rows.append(contentsOf: part)
        }
        return rows
    }

    func fetchUnitShifts(limit: Int = 80) async throws -> [ShiftListItem] {
        try await client
            .from("shifts")
            .select(shiftListSelect)
            .order("shift_date", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    func fetchUnitEvents(limit: Int = 80, shiftLeadId: String? = nil) async throws -> [EventListItem] {
        var query = client
            .from("events")
            .select(eventListSelect)
        if let shiftLeadId {
            query = query.eq("shift_lead_id", value: shiftLeadId)
        }
        return try await query
            .order("event_date", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    func fetchMyActiveUnitEvents() async throws -> [EventListItem] {
        guard let userId = await sessionUserId() else { return [] }
        return try await client
            .from("events")
            .select(eventListSelect)
            .eq("shift_lead_id", value: userId)
            .eq("is_cancelled", value: false)
            .in("status", values: AUTO_MY_ACTIVE_STATUSES.map(\.rawValue))
            .order("event_date", ascending: false)
            .execute()
            .value
    }

    func fetchMyActiveEventPrefs() async throws -> [MyActiveEventPrefRow] {
        guard let userId = await sessionUserId() else { return [] }
        return try await client
            .from("my_active_event_prefs")
            .select("user_id, event_id, kind")
            .eq("user_id", value: userId)
            .execute()
            .value
    }

    func fetchUnitEventsByIds(_ ids: [String]) async throws -> [EventListItem] {
        if ids.isEmpty { return [] }
        var rows: [EventListItem] = []
        for chunkStart in stride(from: 0, to: ids.count, by: 100) {
            let chunk = Array(ids[chunkStart..<min(chunkStart + 100, ids.count)])
            let part: [EventListItem] = try await client
                .from("events")
                .select(eventListSelect)
                .in("id", values: chunk)
                .execute()
                .value
            rows.append(contentsOf: part)
        }
        return rows
    }

    func addEventToMyActive(eventId: String, alreadyAuto: Bool) async -> String? {
        guard let userId = await sessionUserId() else { return MY_ACTIVE_PREF_FAILED }
        do {
            try await deleteMyActivePref(userId: userId, eventId: eventId)
            if !alreadyAuto {
                try await client
                    .from("my_active_event_prefs")
                    .insert(MyActiveEventPrefWrite(userId: userId, eventId: eventId, kind: "pin"))
                    .execute()
            }
            return nil
        } catch {
            return MY_ACTIVE_PREF_FAILED
        }
    }

    func removeEventFromMyActive(eventId: String, isAuto: Bool) async -> String? {
        guard let userId = await sessionUserId() else { return MY_ACTIVE_PREF_FAILED }
        do {
            try await deleteMyActivePref(userId: userId, eventId: eventId)
            if isAuto {
                try await client
                    .from("my_active_event_prefs")
                    .insert(MyActiveEventPrefWrite(userId: userId, eventId: eventId, kind: "hide"))
                    .execute()
            }
            return nil
        } catch {
            let raw = error.localizedDescription
            if raw.contains("בהזנה") {
                return "לא ניתן להסיר אירוע בהזנה שאתם אחמ״ש שלו."
            }
            return MY_ACTIVE_PREF_FAILED
        }
    }

    private func deleteMyActivePref(userId: String, eventId: String) async throws {
        try await client
            .from("my_active_event_prefs")
            .delete()
            .eq("user_id", value: userId)
            .eq("event_id", value: eventId)
            .execute()
    }

    func deleteUnitEvent(eventId: String) async -> String? {
        do {
            try await client
                .from("events")
                .delete()
                .eq("id", value: eventId)
                .execute()
            let stillThere: [EventOwnerRow] = try await client
                .from("events")
                .select("id, shift_lead_id")
                .eq("id", value: eventId)
                .limit(1)
                .execute()
                .value
            if stillThere.isEmpty { return nil }
            let viewerId = await sessionUserId()
            let ownerId = stillThere.first?.shiftLeadId
            if let viewerId, let ownerId, ownerId != viewerId {
                return EVENT_DELETE_OTHER_LEAD
            }
            return EVENT_DELETE_FAILED
        } catch {
            return EVENT_DELETE_FAILED
        }
    }

    func fetchUnitEventDetailResponders(eventId: String) async throws -> [UnitEventDetailResponderRow] {
        let wrap: UnitEventDetailRespondersWrap = try await client
            .from("events")
            .select(
                """
                responders:event_responders(
                  id, responder_id, started_at, ended_at, vehicle_plate, total_km,
                  odometer_start, odometer_end, route, treatment_detail, treatment_notes,
                  emergency_means, status,
                  profile:profiles(full_name, callsign),
                  treated:event_treated_vehicles(quantity, kind:vehicle_kinds(name)),
                  treated_plates:event_treated_plates(plate_number, model, color, left_where, manufacturer, logo_slug, sort_order)
                )
                """
            )
            .eq("id", value: eventId)
            .single()
            .execute()
            .value
        return wrap.responders
    }

    func fetchEventLookups() async throws -> EventLookups {
        func lookup(_ table: String, columns: String) async throws -> [LookupOption] {
            let rows: [LookupRow] = try await client
                .from(table)
                .select(columns)
                .eq("active", value: true)
                .order("sort_order", ascending: true)
                .order("name", ascending: true)
                .execute()
                .value
            return rows.map(\.asOption)
        }
        let roads = try await lookup("roads", columns: "id, name")
        return EventLookups(
            districts: sortLookupsBySortOrder(try await lookup("districts", columns: "id, name, code, sort_order")),
            eventTypes: try await lookup("event_types", columns: "id, name"),
            roads: sortByRoadName(roads) { $0.name },
            vehicleKinds: try await lookup("vehicle_kinds", columns: "id, name")
        )
    }

    func fetchShiftLeadProfiles() async throws -> [AssignableProfile] {
        let rows: [AssignableProfileRow] = try await client
            .rpc("list_shift_lead_profiles")
            .execute()
            .value
        return rows.map(\.asProfile)
    }

    func fetchEventFormDetail(eventId: String) async throws -> EventFormDetail {
        try await client
            .from("events")
            .select(
                """
                id, event_date, police_event_id, district_id, patrol_callsign, event_type_id, road_id,
                location, station, notes, is_cancelled, bus_lane, status, shift_lead_id,
                shift_lead:profiles!events_shift_lead_id_fkey(full_name, callsign),
                \(EVENT_SECONDARY_LEADS_EMBED),
                responders:event_responders(
                  id, responder_id, started_at, ended_at, total_km, emergency_means, status,
                  treated:event_treated_vehicles(vehicle_kind_id, quantity)
                )
                """
            )
            .eq("id", value: eventId)
            .single()
            .execute()
            .value
    }

    func createUnitEvent(
        _ draft: EventDraft,
        districts: [LookupOption],
        vehicleKinds: [LookupOption],
        allowPartial: Bool = false
    ) async -> String? {
        let errors = allowPartial ? validateEventDraftPartial(draft) : validateEventDraft(draft, districts: districts)
        if !errors.isEmpty {
            return errors.eventDate ?? errors.formMessage ?? EVENT_DRAFT_FORM_ERROR
        }
        guard let userId = await sessionUserId() else { return "יש להתחבר מחדש." }
        if createIncludesSelfAssign(shiftLeadId: userId, responders: draft.responders) {
            return EVENT_SELF_ASSIGN_ON_CREATE_ERROR
        }
        guard let eventDate = normalizeReturnDate(draft.eventDate) else { return EVENT_DRAFT_DATE_ERROR }
        let mainLeadId = draft.shiftLeadId.isEmpty ? userId : draft.shiftLeadId
        do {
            let nextStatus = deriveEventStatusFromDraft(draft.responders)
            let inserted: IdRow = try await client
                .from("events")
                .insert(
                    EventInsert(
                        eventDate: eventDate,
                        policeEventId: draft.policeEventId.nilIfEmpty,
                        districtId: draft.districtId.nilIfEmpty,
                        patrolCallsign: draft.patrolCallsign.nilIfEmpty,
                        eventTypeId: draft.eventTypeId.nilIfEmpty,
                        roadId: draft.roadId.nilIfEmpty,
                        location: draft.location.nilIfEmpty,
                        station: stationForSave(districts, districtId: draft.districtId, station: draft.station),
                        notes: draft.notes.nilIfEmpty,
                        busLane: draft.busLane,
                        status: nextStatus.rawValue,
                        shiftLeadId: mainLeadId,
                        updatedAt: nowIso()
                    )
                )
                .select("id")
                .single()
                .execute()
                .value
            if let error = await syncEventResponders(
                eventId: inserted.id,
                eventDate: eventDate,
                responders: draft.responders,
                vehicleKinds: vehicleKinds,
                isCancelled: draft.isCancelled
            ) {
                return error
            }
            return await syncEventSecondaryLeads(
                eventId: inserted.id,
                desired: draft.secondaryLeads,
                creatorSecondary: createTimeCreatorSecondary(creatorId: userId, mainLeadId: mainLeadId),
                mainLeadId: mainLeadId
            )
        } catch {
            return await recoverOwnCreatedEvent(
                draft: draft,
                eventDate: eventDate,
                mainLeadId: mainLeadId,
                districts: districts,
                vehicleKinds: vehicleKinds,
                allowPartial: allowPartial
            ) ?? EVENT_DRAFT_SAVE_FAILED
        }
    }

    private func recoverOwnCreatedEvent(
        draft: EventDraft,
        eventDate: String,
        mainLeadId: String,
        districts: [LookupOption],
        vehicleKinds: [LookupOption],
        allowPartial: Bool
    ) async -> String? {
        let policeId = digitsOnly(draft.policeEventId)
        if policeId.isEmpty { return nil }
        let existing: [SameDayPoliceEventApiRow] = (try? await client
            .from("events")
            .select("id, shift_lead_id, is_cancelled, police_event_id")
            .eq("event_date", value: eventDate)
            .eq("shift_lead_id", value: mainLeadId)
            .eq("is_cancelled", value: false)
            .execute()
            .value) ?? []
        let matches = existing.filter { digitsOnly($0.policeEventId ?? "") == policeId }
        guard let recovered = ownResumableEventId(
            currentEventId: nil,
            viewerLeadId: mainLeadId,
            existing: matches.map {
                SameDayPoliceEventRow(id: $0.id, shiftLeadId: $0.shiftLeadId, isCancelled: $0.isCancelled)
            }
        ) else { return nil }
        return await updateUnitEvent(
            eventId: recovered,
            draft: draft,
            districts: districts,
            vehicleKinds: vehicleKinds,
            viewerIsAdmin: false,
            previousIsCancelled: false,
            allowPartial: allowPartial
        )
    }

    func updateUnitEvent(
        eventId: String,
        draft: EventDraft,
        districts: [LookupOption],
        vehicleKinds: [LookupOption],
        viewerIsAdmin: Bool,
        previousIsCancelled: Bool,
        allowPartial: Bool = false,
        previousDraft: EventDraft? = nil
    ) async -> String? {
        let errors = allowPartial ? validateEventDraftPartial(draft) : validateEventDraft(draft, districts: districts)
        if !errors.isEmpty {
            return errors.eventDate ?? errors.formMessage ?? EVENT_DRAFT_FORM_ERROR
        }
        if previousIsCancelled && !draft.isCancelled {
            if let blocked = canToggleEventCancelled(next: false, canClearCancelled: viewerIsAdmin) {
                return blocked
            }
        }
        if let previousDraft, previousDraft.forPersistCompare() == draft.forPersistCompare() {
            return nil
        }
        let assignmentSource = previousDraft ?? draft
        if assignmentSource.blocksAssignedVolunteerEdit(viewerId: await sessionUserId()) {
            return ASSIGNED_VOLUNTEER_EVENT_EDIT_ERROR
        }
        guard let eventDate = normalizeReturnDate(draft.eventDate) else { return EVENT_DRAFT_DATE_ERROR }
        let mainLeadId = draft.shiftLeadId.trimmingCharacters(in: .whitespacesAndNewlines)
        if mainLeadId.isEmpty { return "אין אחמ״ש ראשי." }
        do {
            let nextStatus = deriveEventStatusFromDraft(draft.responders)
            let updated: [IdRow] = try await client
                .from("events")
                .update(
                    EventUpdateWrite(
                        eventDate: eventDate,
                        policeEventId: draft.policeEventId.nilIfEmpty,
                        districtId: draft.districtId.nilIfEmpty,
                        patrolCallsign: draft.patrolCallsign.nilIfEmpty,
                        eventTypeId: draft.eventTypeId.nilIfEmpty,
                        roadId: draft.roadId.nilIfEmpty,
                        location: draft.location.nilIfEmpty,
                        station: stationForSave(districts, districtId: draft.districtId, station: draft.station),
                        notes: draft.notes.nilIfEmpty,
                        isCancelled: draft.isCancelled,
                        busLane: draft.busLane,
                        status: nextStatus.rawValue,
                        shiftLeadId: mainLeadId,
                        updatedAt: nowIso()
                    )
                )
                .eq("id", value: eventId)
                .select("id")
                .execute()
                .value
            if updated.isEmpty { return "אין הרשאה לעדכן את האירוע." }
            if let error = await syncEventResponders(
                eventId: eventId,
                eventDate: eventDate,
                responders: draft.responders,
                vehicleKinds: vehicleKinds,
                isCancelled: draft.isCancelled
            ) {
                return error
            }
            return await syncEventSecondaryLeads(
                eventId: eventId,
                desired: draft.secondaryLeads,
                creatorSecondary: nil,
                mainLeadId: mainLeadId
            )
        } catch {
            return EVENT_DRAFT_SAVE_FAILED
        }
    }

    private func syncEventSecondaryLeads(
        eventId: String,
        desired: [SecondaryLead],
        creatorSecondary: SecondaryLead?,
        mainLeadId: String
    ) async -> String? {
        do {
            let existing: [EventSecondaryLeadRow] = try await client
                .from("event_secondary_leads")
                .select(
                    "user_id, locked, added_at, profile:profiles!event_secondary_leads_user_id_fkey(full_name, callsign)"
                )
                .eq("event_id", value: eventId)
                .order("added_at", ascending: true)
                .execute()
                .value
            var wanted: [String: Bool] = [:]
            for row in desired {
                let id = row.userId.trimmingCharacters(in: .whitespacesAndNewlines)
                if !id.isEmpty && id != mainLeadId {
                    wanted[id] = row.locked
                }
            }
            if let creator = creatorSecondary?.userId.trimmingCharacters(in: .whitespacesAndNewlines),
               !creator.isEmpty,
               creator != mainLeadId
            {
                wanted[creator] = wanted[creator] == true
            }
            for row in existing where wanted[row.userId] == nil && !row.locked {
                do {
                    try await client
                        .from("event_secondary_leads")
                        .delete()
                        .eq("event_id", value: eventId)
                        .eq("user_id", value: row.userId)
                        .eq("locked", value: false)
                        .execute()
                } catch {
                    return EVENT_DRAFT_SAVE_FAILED
                }
            }
            for (userId, locked) in wanted {
                let found = existing.first(where: { $0.userId == userId })
                do {
                    if found == nil {
                        try await client
                            .from("event_secondary_leads")
                            .insert(EventSecondaryLeadInsert(eventId: eventId, userId: userId, locked: locked))
                            .execute()
                    } else if locked && found?.locked != true {
                        try await client
                            .from("event_secondary_leads")
                            .update(EventSecondaryLeadLockWrite(locked: true))
                            .eq("event_id", value: eventId)
                            .eq("user_id", value: userId)
                            .execute()
                    }
                } catch {
                    return EVENT_DRAFT_SAVE_FAILED
                }
            }
            return nil
        } catch {
            return EVENT_DRAFT_SAVE_FAILED
        }
    }

    private func syncEventResponders(
        eventId: String,
        eventDate: String,
        responders: [EventResponderDraft],
        vehicleKinds: [LookupOption],
        isCancelled: Bool
    ) async -> String? {
        do {
            let existing: [EventFormResponderRow] = try await client
                .from("event_responders")
                .select("id, responder_id, status, total_km")
                .eq("event_id", value: eventId)
                .execute()
                .value
            let keepIds = Set(responders.map(\.responderId))
            let toRemove = existing.filter { !keepIds.contains($0.responderId) }
            if !toRemove.isEmpty {
                try await client
                    .from("event_responders")
                    .delete()
                    .in("id", values: toRemove.map(\.id))
                    .execute()
            }
            let existingByResponder = keyedLastWins(existing.map { ($0.responderId, $0.id) })
            var nextKmRows: [FillReadyNextRow] = []
            for responder in responders {
                let km = leadKmForSave(hasVehicle: responder.hasVehicle, totalKm: responder.totalKm)
                if responder.hasVehicle
                    && !responder.totalKm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && km == nil
                {
                    return "קילומטרים חייבים להיות מספר."
                }
                let overnight = isOvernightEnd(startTime: responder.startTime, endTime: responder.endTime)
                let startedAt = wallTimestamp(eventDate: eventDate, timeHm: responder.startTime, dayOffset: 0)
                let endedAt = wallTimestamp(
                    eventDate: eventDate,
                    timeHm: responder.endTime,
                    dayOffset: overnight ? 1 : 0
                )
                let assignmentId = responder.assignmentId.isEmpty
                    ? existingByResponder[responder.responderId]
                    : responder.assignmentId
                let now = nowIso()
                let resolvedId: String
                if let assignmentId {
                    let updated: [IdRow] = try await client
                        .from("event_responders")
                        .update(
                            EventResponderLeadWrite(
                                startedAt: startedAt,
                                endedAt: endedAt,
                                totalKm: km,
                                emergencyMeans: responder.emergencyMeans,
                                updatedAt: now
                            )
                        )
                        .eq("id", value: assignmentId)
                        .select("id")
                        .execute()
                        .value
                    resolvedId = updated.first?.id ?? assignmentId
                } else {
                    let inserted: IdRow = try await client
                        .from("event_responders")
                        .insert(
                            EventResponderInsert(
                                eventId: eventId,
                                responderId: responder.responderId,
                                startedAt: startedAt,
                                endedAt: endedAt,
                                totalKm: km,
                                emergencyMeans: responder.emergencyMeans,
                                status: responder.status.rawValue
                            )
                        )
                        .select("id")
                        .single()
                        .execute()
                        .value
                    resolvedId = inserted.id
                }
                nextKmRows.append(FillReadyNextRow(assignmentId: resolvedId, totalKm: km))
                try await client
                    .from("event_treated_vehicles")
                    .delete()
                    .eq("event_responder_id", value: resolvedId)
                    .execute()
                if !isCancelled {
                    let treatedRows = vehicleKinds.compactMap { kind -> EventTreatedVehicleInsert? in
                        let quantity = responder.treated.first(where: { $0.vehicleKindId == kind.id })?.quantity ?? 0
                        guard quantity > 0 else { return nil }
                        return EventTreatedVehicleInsert(
                            eventResponderId: resolvedId,
                            vehicleKindId: kind.id,
                            quantity: quantity
                        )
                    }
                    if !treatedRows.isEmpty {
                        try await client
                            .from("event_treated_vehicles")
                            .insert(treatedRows)
                            .execute()
                    }
                }
            }
            if !isCancelled {
                let notifyIds = fillReadyNotifyIds(
                    previous: existing.map { FillReadyPreviousRow(id: $0.id, totalKm: $0.totalKm) },
                    next: nextKmRows
                )
                if !notifyIds.isEmpty {
                    await notifyFillReady(notifyIds)
                }
            }
            return nil
        } catch {
            return EVENT_DRAFT_SAVE_FAILED
        }
    }

    private func notifyFillReady(_ eventResponderIds: [String]) async {
        guard !eventResponderIds.isEmpty else { return }
        let _: NotifyFillReadyResponse? = try? await client.functions.invoke(
            "responder-fill",
            options: functionOptions(body: NotifyFillReadyCall(eventResponderIds: eventResponderIds))
        )
    }

    func fetchAssignableProfiles() async throws -> [AssignableProfile] {
        let rows: [AssignableProfileRow] = try await client
            .from("profiles")
            .select("id, full_name, callsign")
            .eq("active", value: true)
            .order("full_name", ascending: true)
            .execute()
            .value
        return rows.map(\.asProfile)
    }

    func fetchReport(_ kind: ReportKindId, from: String, to: String) async throws -> [ReportRow] {
        switch kind {
        case .openDocumentation:
            return openDocReportRows(try await fetchOpenDocumentation(from: from, to: to))
        case .eventsByResponder:
            return eventsByResponderReportRows(
                buildEventsByResponderRows(
                    try await fetchReportEvents(from: from, to: to).map(\.asEventsByResponderInput),
                    from: from,
                    to: to
                )
            )
        case .kmExceptions:
            return kmExceptionReportRows(
                buildKmExceptionRows(
                    try await fetchReportEvents(from: from, to: to).map(\.asKmExceptionInput),
                    from: from,
                    to: to
                )
            )
        case .kmDiscrepancy:
            return kmDiscrepancyReportRows(
                buildKmDiscrepancyRows(
                    try await fetchKmDiscrepancyEvents(from: from, to: to).map(\.asInput),
                    from: from,
                    to: to
                )
            )
        case .duplicateEvents:
            return duplicateEventsReportRows(
                buildDuplicateClusters(try await fetchDuplicateEvents().flatMap(\.asParticipations))
            )
        case .fuelRefund:
            return fuelRefundReportRows(try await fetchFuelRefundRows(from: from, to: to))
        }
    }

    /// Overwrite the lead's `total_km` with the responder's odometer difference.
    func applyLeadKmFromOdometer(_ assignmentId: String) async -> String? {
        do {
            let row: LeadKmRow = try await client
                .from("event_responders")
                .select("id, total_km, odometer_start, odometer_end")
                .eq("id", value: assignmentId)
                .single()
                .execute()
                .value
            switch resolveLeadKmReplacement(
                totalKm: row.totalKm,
                odometerStart: row.odometerStart,
                odometerEnd: row.odometerEnd
            ) {
            case .invalid:
                return KM_DISCREPANCY_APPLY_FAILED
            case .alreadyAligned:
                return KM_DISCREPANCY_ALIGNED
            case .replace(let totalKm):
                let updated: [IdRow] = try await client
                    .from("event_responders")
                    .update(LeadKmWrite(
                        totalKm: totalKm,
                        updatedAt: ISO8601DateFormatter().string(from: Date())
                    ))
                    .eq("id", value: assignmentId)
                    .select("id")
                    .execute()
                    .value
                return updated.isEmpty ? KM_DISCREPANCY_APPLY_FAILED : nil
            }
        } catch {
            return KM_DISCREPANCY_APPLY_FAILED
        }
    }

    private func fetchOpenDocumentation(from: String, to: String) async throws -> [OpenDocRow] {
        guard let userId = await sessionUserId() else { return [] }
        let roleRows: [RoleRow] = try await client
            .from("user_roles")
            .select("role")
            .eq("user_id", value: userId)
            .execute()
            .value
        let viewerIsAdmin = isAdmin(roleRows.map(\.role))
        var query = client
            .from("events")
            .select(openDocSelect)
            .in("status", values: [EventStatus.inProgress.rawValue, EventStatus.partial.rawValue])
            .eq("is_cancelled", value: false)
            .gte("event_date", value: from)
            .lte("event_date", value: to)
        if !viewerIsAdmin {
            query = query.eq("shift_lead_id", value: userId)
        }
        let rows: [OpenDocEventRow] = try await query
            .order("event_date", ascending: false)
            .execute()
            .value
        return buildOpenDocRows(
            events: rows.map(\.asInput),
            from: from,
            to: to,
            viewerId: userId,
            viewerIsAdmin: viewerIsAdmin
        )
    }

    private func fetchReportEvents(from: String, to: String) async throws -> [ReportEventRow] {
        try await client
            .from("events")
            .select(reportEventSelect)
            .gte("event_date", value: from)
            .lte("event_date", value: to)
            .order("event_date", ascending: false)
            .execute()
            .value
    }

    private func fetchKmDiscrepancyEvents(from: String, to: String) async throws -> [KmDiscrepancyEventRow] {
        try await client
            .from("events")
            .select(kmDiscrepancySelect)
            .gte("event_date", value: from)
            .lte("event_date", value: to)
            .order("event_date", ascending: false)
            .execute()
            .value
    }

    /// Duplicates are looked for across the whole history, like the web report.
    private func fetchDuplicateEvents() async throws -> [DuplicateEventRow] {
        try await client
            .from("events")
            .select(duplicateEventSelect)
            .order("event_date", ascending: false)
            .execute()
            .value
    }

    private func fetchFuelRefundRows(from: String, to: String) async throws -> [FuelRefundRow] {
        let profiles: [AssignableProfileRow] = try await client
            .from("profiles")
            .select("id, full_name, callsign")
            .eq("active", value: true)
            .execute()
            .value
        let bounds = jerusalemDayBounds(from: from, to: to)
        let eventRows: [FuelEventFreezeRow] = try await client
            .from("events")
            .select("id, frozen_over_60km, frozen_suspicious_duplicate")
            .eq("origin", value: "manual")
            .gte("created_at", value: bounds.0)
            .lte("created_at", value: bounds.1)
            .execute()
            .value
        let eventIds = eventRows.filter { !$0.isFrozen }.map(\.id)
        var participations: [FuelParticipationRow] = []
        if !eventIds.isEmpty {
            for chunkStart in stride(from: 0, to: eventIds.count, by: 100) {
                let chunk = Array(eventIds[chunkStart..<min(chunkStart + 100, eventIds.count)])
                let part: [FuelParticipationRow] = try await client
                    .from("event_responders")
                    .select("responder_id, event_id, total_km")
                    .in("event_id", values: chunk)
                    .execute()
                    .value
                participations.append(contentsOf: part)
            }
        }
        let credits: [FuelShiftRow] = try await client
            .from("shifts")
            .select("total_km, vehicles!shifts_personal_vehicle_id_fkey(user_id)")
            .eq("vehicle_type", value: "personal")
            .gte("shift_date", value: from)
            .lte("shift_date", value: to)
            .execute()
            .value
        return buildFuelRefundRows(
            profiles: profiles.map { FuelRefundProfileInput(id: $0.id, fullName: $0.fullName, callsign: $0.callsign) },
            participations: participations.map {
                FuelRefundParticipationInput(responderId: $0.responderId, eventId: $0.eventId, totalKm: $0.totalKm)
            },
            credits: credits.compactMap { row in
                guard let owner = row.vehicles?.userId, let km = row.totalKm else { return nil }
                return FuelRefundCreditInput(responderId: owner, totalKm: km)
            }
        )
    }

    /// Inclusive local-day bounds in Asia/Jerusalem, as UTC instants for `created_at` filters.
    private func jerusalemDayBounds(from: String, to: String) -> (String, String) {
        guard let zone = TimeZone(identifier: "Asia/Jerusalem") else { return (from, to) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let parser = DateFormatter()
        parser.calendar = Calendar(identifier: .gregorian)
        parser.timeZone = zone
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        guard let startDay = parser.date(from: from),
              let endDay = parser.date(from: to),
              let endExclusive = calendar.date(byAdding: .day, value: 1, to: endDay) else {
            return (from, to)
        }
        let end = endExclusive.addingTimeInterval(-0.001)
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        iso.timeZone = TimeZone(secondsFromGMT: 0)
        return (iso.string(from: startDay), iso.string(from: end))
    }

    func fetchVehiclesForResponders(_ responderIds: [String]) async throws -> [CrewVehicleRow] {
        let ids = Array(Set(responderIds))
        if ids.isEmpty { return [] }
        let rows: [CrewVehicleRow] = try await client
            .from("vehicles")
            .select("id, user_id, plate_number, model, archived")
            .in("user_id", values: ids)
            .order("plate_number", ascending: true)
            .execute()
            .value
        return rows.filter { $0.archived != true }
    }

    func fetchShiftFormDetail(shiftId: String) async throws -> ShiftFormDetail {
        try await client
            .from("shifts")
            .select(
                """
                id, shift_date, shift_kind, vehicle_type, notes, personal_vehicle_id,
                responders:shift_responders(id, responder_id)
                """
            )
            .eq("id", value: shiftId)
            .single()
            .execute()
            .value
    }

    func createUnitShift(_ draft: ShiftDraft) async -> String? {
        let errors = validateShiftDraft(draft)
        if !errors.isEmpty { return errors.formMessage ?? SHIFT_DRAFT_FORM_ERROR }
        guard let userId = await sessionUserId() else { return "יש להתחבר מחדש." }
        guard let shiftDate = normalizeReturnDate(draft.shiftDate) else { return SHIFT_DRAFT_DATE_ERROR }
        do {
            let inserted: IdRow = try await client
                .from("shifts")
                .insert(
                    ShiftInsert(
                        shiftDate: shiftDate,
                        shiftKind: draft.shiftKind,
                        vehicleType: draft.vehicleType,
                        personalVehicleId: draft.vehicleType == "personal" ? draft.personalVehicleId : nil,
                        notes: draft.notes.nilIfEmpty,
                        shiftLeadId: userId,
                        lastSavedBy: userId,
                        updatedAt: nowIso()
                    )
                )
                .select("id")
                .single()
                .execute()
                .value
            try await client
                .from("shift_responders")
                .insert(
                    Array(Set(draft.responderIds)).map {
                        ShiftResponderInsert(shiftId: inserted.id, responderId: $0)
                    }
                )
                .execute()
            try? await client
                .rpc("sync_shift_born_events", params: SyncShiftBornEventsCall(shiftId: inserted.id))
                .execute()
            return nil
        } catch {
            return SHIFT_DRAFT_SAVE_FAILED
        }
    }

    func updateUnitShift(shiftId: String, draft: ShiftDraft) async -> String? {
        let errors = validateShiftDraft(draft)
        if !errors.isEmpty { return errors.formMessage ?? SHIFT_DRAFT_FORM_ERROR }
        guard let userId = await sessionUserId() else { return "יש להתחבר מחדש." }
        guard let shiftDate = normalizeReturnDate(draft.shiftDate) else { return SHIFT_DRAFT_DATE_ERROR }
        do {
            let detail = try await fetchShiftFormDetail(shiftId: shiftId)
            let personalVehicleId = draft.vehicleType == "personal" ? draft.personalVehicleId : nil
            let existing = detail.responders
            let keepIds = Set(draft.responderIds)
            let toRemove = existing.filter { !keepIds.contains($0.responderId) }
            if !toRemove.isEmpty {
                try await client
                    .from("shift_responders")
                    .delete()
                    .in("id", values: toRemove.map { $0.id })
                    .execute()
            }
            let existingResponderIds = Set(existing.map(\.responderId))
            let toAdd = keepIds.filter { !existingResponderIds.contains($0) }
            if !toAdd.isEmpty {
                try await client
                    .from("shift_responders")
                    .insert(toAdd.map { ShiftResponderInsert(shiftId: shiftId, responderId: $0) })
                    .execute()
            }
            let updated: [IdRow] = try await client
                .from("shifts")
                .update(
                    ShiftUpdateWrite(
                        shiftDate: shiftDate,
                        shiftKind: draft.shiftKind,
                        vehicleType: draft.vehicleType,
                        personalVehicleId: personalVehicleId,
                        notes: draft.notes.nilIfEmpty,
                        lastSavedBy: userId,
                        updatedAt: nowIso()
                    )
                )
                .eq("id", value: shiftId)
                .select("id")
                .execute()
                .value
            if updated.isEmpty { return "אין הרשאה לעדכן את המשמרת." }
            try? await client
                .rpc("sync_shift_born_events", params: SyncShiftBornEventsCall(shiftId: shiftId))
                .execute()
            return nil
        } catch {
            return SHIFT_DRAFT_SAVE_FAILED
        }
    }

    func fetchUnitContacts() async throws -> [UnitContact] {
        try await client
            .rpc("list_unit_contacts")
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
        complete: Bool,
        unfinishedMediaDraftCount: Int = 0
    ) async -> String? {
        let errors = validateResponderFillDraft(
            draft,
            mode: complete ? .complete : .draft,
            allowedPlates: context.vehicles.map(\.plate),
            totalKm: context.totalKm,
            unfinishedMediaDraftCount: unfinishedMediaDraftCount
        )
        if !errors.isEmpty {
            return complete
                ? (errors.firstMessage ?? "יש למלא את כל שדות החובה לפני סיום הדיווח.")
                : (errors.firstMessage ?? "בדקו את השדות המסומנים.")
        }
        let start = parsedOdometer(draft.odometerStart)
        let end = parsedOdometer(draft.odometerEnd)
        let lockError = "לא ניתן לערוך דיווח שהושלם. רק אחמ״ש יכול לערוך."
        let saveError = "שמירת הדיווח נכשלה. בדקו את החיבור ונסו שוב."
        do {
            let current: FillLockRow = try await client
                .from("event_responders")
                .select("status, event:events!inner(status)")
                .eq("id", value: context.assignmentId)
                .single()
                .execute()
                .value
            switch gateResponderFillWrite(
                complete: complete,
                participationStatus: current.status,
                eventStatus: current.eventStatus
            ) {
            case .alreadyComplete:
                return nil
            case .locked:
                return lockError
            case .proceed:
                break
            }
            // Keep status writable until plates are saved — RLS blocks plate writes after done.
            let fieldsUpdated: [IdRow] = try await client
                .from("event_responders")
                .update(FillWrite(
                    vehiclePlate: plateNumberForSave(draft.vehiclePlate),
                    odometerStart: start,
                    odometerEnd: end,
                    route: draft.route.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    treatmentDetail: draft.treatmentDetail.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    treatmentNotes: draft.treatmentNotes.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    status: ParticipationStatus.inProgress.rawValue,
                    updatedAt: ISO8601DateFormatter().string(from: Date())
                ))
                .eq("id", value: context.assignmentId)
                .select("id")
                .execute()
                .value
            if fieldsUpdated.isEmpty {
                if complete, await participationIsDone(context.assignmentId) { return nil }
                return lockError
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
                                leftWhere: row.leftWhere?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                                manufacturer: row.manufacturer?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                                logoSlug: row.logoSlug?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                                sortOrder: index
                            )
                        }
                    )
                    .execute()
            }
            if complete {
                let completed: [IdRow] = try await client
                    .from("event_responders")
                    .update(FillStatusWrite(
                        status: ParticipationStatus.done.rawValue,
                        updatedAt: ISO8601DateFormatter().string(from: Date())
                    ))
                    .eq("id", value: context.assignmentId)
                    .select("id")
                    .execute()
                    .value
                if completed.isEmpty, !(await participationIsDone(context.assignmentId)) {
                    return lockError
                }
            }
            _ = try? await client
                .rpc("apply_event_status_from_participations", params: ["p_event_id": context.eventId])
                .execute()
            return nil
        } catch {
            if complete, await participationIsDone(context.assignmentId) { return nil }
            return saveError
        }
    }

    private func participationIsDone(_ assignmentId: String) async -> Bool {
        do {
            let row: FillLockRow = try await client
                .from("event_responders")
                .select("status")
                .eq("id", value: assignmentId)
                .single()
                .execute()
                .value
            return row.status == .done
        } catch {
            return false
        }
    }

    private let eventMediaSelect =
        "id, event_id, uploaded_by, caption, taken_when, storage_path, mime_type, byte_size, width, height, created_at, uploader:profiles!event_media_uploaded_by_fkey(full_name), plates:event_media_plates(treated_plate_id)"

    func listEventMedia(eventId: String) async -> [EventMedia] {
        do {
            let rows: [EventMediaRow] = try await client
                .from("event_media")
                .select(eventMediaSelect)
                .eq("event_id", value: eventId)
                .order("created_at", ascending: true)
                .execute()
                .value
            var out: [EventMedia] = []
            for row in rows {
                let signed = await signedUrlFor(row.storagePath)
                out.append(row.toDomain(signedUrl: signed))
            }
            return out
        } catch {
            return []
        }
    }

    func listEventMediaPlates(eventId: String) async -> [EventMediaPlateOption] {
        let plateSelect = "id, plate_number, model, color, logo_slug"
        let eventKeyed: [EventMediaPlateOptionRow]
        do {
            eventKeyed = try await client
                .from("event_treated_plates")
                .select(plateSelect)
                .eq("event_id", value: eventId)
                .execute()
                .value
        } catch {
            eventKeyed = []
        }
        let responderKeyed: [EventMediaPlateOptionRow]
        do {
            responderKeyed = try await client
                .from("event_treated_plates")
                .select("\(plateSelect), event_responders!event_treated_plates_event_responder_id_fkey!inner(event_id)")
                .eq("event_responders.event_id", value: eventId)
                .execute()
                .value
        } catch {
            responderKeyed = []
        }
        return mergeMediaPlates(
            responderKeyed: responderKeyed.compactMap(\.toOption),
            eventKeyed: eventKeyed.compactMap(\.toOption)
        )
    }

    func uploadEventMedia(
        eventId: String,
        jpegBytes: Data,
        width: Int,
        height: Int,
        takenWhen: EventMediaTakenWhen,
        treatedPlateIds: [String],
        caption: String?
    ) async -> EventMediaWriteResult {
        guard let userId = await sessionUserId() else {
            return .error(EVENT_MEDIA_NETWORK)
        }
        let trimmed = caption?.trimmingCharacters(in: .whitespacesAndNewlines)
        let storedCaption = (trimmed?.isEmpty == false) ? trimmed : nil
        if let issue = captionError(storedCaption ?? "") {
            return .error(issue)
        }
        let id = UUID().uuidString.lowercased()
        let storagePath = eventMediaStoragePath(eventId: eventId, mediaId: id)
        do {
            try await client.storage.from("event-media").upload(
                storagePath,
                data: jpegBytes,
                options: FileOptions(contentType: "image/jpeg", upsert: false)
            )
        } catch {
            return .error(mapEventMediaError(error.localizedDescription))
        }
        let inserted: EventMediaRow
        do {
            inserted = try await client
                .from("event_media")
                .insert(
                    EventMediaInsert(
                        id: id,
                        eventId: eventId,
                        uploadedBy: userId,
                        caption: storedCaption,
                        takenWhen: takenWhen.rawValue,
                        storagePath: storagePath,
                        mimeType: "image/jpeg",
                        byteSize: jpegBytes.count,
                        width: width,
                        height: height
                    )
                )
                .select(eventMediaSelect)
                .single()
                .execute()
                .value
        } catch {
            _ = try? await client.storage.from("event-media").remove(paths: [storagePath])
            return .error(mapEventMediaError((error as NSError).localizedDescription))
        }
        switch await replaceMediaPlates(mediaId: id, plateIds: treatedPlateIds) {
        case .error(let message):
            _ = try? await client.from("event_media").delete().eq("id", value: id).execute()
            _ = try? await client.storage.from("event-media").remove(paths: [storagePath])
            return .error(message)
        default:
            break
        }
        let signed = await signedUrlFor(storagePath)
        return .uploaded(
            inserted.toDomain(
                signedUrl: signed,
                treatedPlateIds: uniquePlateIds(treatedPlateIds)
            )
        )
    }

    func updateEventMedia(
        id: String,
        takenWhen: EventMediaTakenWhen,
        treatedPlateIds: [String],
        caption: String?
    ) async -> EventMediaWriteResult {
        let trimmed = caption?.trimmingCharacters(in: .whitespacesAndNewlines)
        let storedCaption = (trimmed?.isEmpty == false) ? trimmed : nil
        if let issue = captionError(storedCaption ?? "") {
            return .error(issue)
        }
        do {
            try await client
                .from("event_media")
                .update(EventMediaUpdate(takenWhen: takenWhen.rawValue, caption: storedCaption))
                .eq("id", value: id)
                .execute()
        } catch {
            return .error(mapEventMediaError(error.localizedDescription))
        }
        return await replaceMediaPlates(mediaId: id, plateIds: treatedPlateIds)
    }

    func deleteEventMedia(id: String, storagePath: String) async -> EventMediaWriteResult {
        do {
            try await client.from("event_media").delete().eq("id", value: id).execute()
            _ = try? await client.storage.from("event-media").remove(paths: [storagePath])
            return .done
        } catch {
            return .error(mapEventMediaError(error.localizedDescription))
        }
    }

    private func replaceMediaPlates(mediaId: String, plateIds: [String]) async -> EventMediaWriteResult {
        let unique = uniquePlateIds(plateIds)
        do {
            try await client.from("event_media_plates").delete().eq("media_id", value: mediaId).execute()
            if !unique.isEmpty {
                try await client
                    .from("event_media_plates")
                    .insert(unique.map { EventMediaPlateWrite(mediaId: mediaId, treatedPlateId: $0) })
                    .execute()
            }
            return .done
        } catch {
            return .error(mapEventMediaError(error.localizedDescription))
        }
    }

    private func signedUrlFor(_ storagePath: String) async -> String? {
        do {
            let url = try await client.storage.from("event-media").createSignedURL(
                path: storagePath,
                expiresIn: 3600
            )
            return url.absoluteString
        } catch {
            return nil
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

    func fetchMyVehicles() async throws -> [ProfileVehicle] {
        guard let userId = await sessionUserId() else { return [] }
        let rows: [VehicleOption] = try await client
            .from("vehicles")
            .select("id, plate_number, model, archived, is_default")
            .eq("user_id", value: userId)
            .execute()
            .value
        return managedProfileVehicles(
            rows.map {
                VehicleRowInput(
                    plateRaw: $0.plateNumber,
                    modelRaw: $0.model,
                    archived: $0.archived,
                    id: $0.rowId,
                    isDefault: $0.isDefault
                )
            }
        )
    }

    func createOwnVehicle(plateNumber: String, model: String) async -> String? {
        guard let userId = await sessionUserId() else { return SAVE_VEHICLES_FAILED }
        switch vehicleFieldsForSave(plateNumber: plateNumber, model: model) {
        case .error(let message):
            return message
        case let .ok(plate, savedModel):
            do {
                try await client
                    .from("vehicles")
                    .insert(
                        OwnVehicleInsert(
                            userId: userId,
                            plateNumber: plate,
                            model: savedModel,
                            archived: false
                        )
                    )
                    .execute()
                return nil
            } catch {
                return isUniqueViolation(error) ? DUPLICATE_PLATE_ERROR : SAVE_VEHICLES_FAILED
            }
        }
    }

    func updateOwnVehicle(vehicleId: String, plateNumber: String, model: String) async -> String? {
        switch vehicleFieldsForSave(plateNumber: plateNumber, model: model) {
        case .error(let message):
            return message
        case let .ok(plate, savedModel):
            do {
                try await client
                    .from("vehicles")
                    .update(OwnVehiclePlateWrite(plateNumber: plate, model: savedModel, archived: false))
                    .eq("id", value: vehicleId)
                    .execute()
                return nil
            } catch {
                return isUniqueViolation(error) ? DUPLICATE_PLATE_ERROR : SAVE_VEHICLES_FAILED
            }
        }
    }

    func setDefaultVehicle(vehicleId: String) async -> String? {
        do {
            try await client
                .rpc("set_default_vehicle", params: SetDefaultVehicleCall(vehicleId: vehicleId))
                .execute()
            return nil
        } catch {
            return SET_DEFAULT_VEHICLE_FAILED
        }
    }

    func deleteOwnVehicle(vehicleId: String) async -> String? {
        do {
            try await client.from("vehicles").delete().eq("id", value: vehicleId).execute()
            return nil
        } catch {
            return VEHICLE_DELETE_FAILED
        }
    }

    func archiveOwnVehicle(vehicleId: String) async -> String? {
        do {
            try await client
                .from("vehicles")
                .update(VehicleArchivedWrite(archived: true))
                .eq("id", value: vehicleId)
                .execute()
            return nil
        } catch {
            return VEHICLE_ARCHIVE_FAILED
        }
    }

    func unarchiveOwnVehicle(vehicleId: String) async -> String? {
        do {
            try await client
                .from("vehicles")
                .update(VehicleArchivedWrite(archived: false))
                .eq("id", value: vehicleId)
                .execute()
            return nil
        } catch {
            return VEHICLE_UNARCHIVE_FAILED
        }
    }

    func isVehicleAttachedToEvents(userId: String, vehicleId: String, plateNumber: String) async -> Bool {
        let digits = plateDigits(plateNumber)
        do {
            let participations: [VehiclePlateRef] = try await client
                .from("event_responders")
                .select("vehicle_plate")
                .eq("responder_id", value: userId)
                .execute()
                .value
            if !digits.isEmpty, participations.contains(where: { plateDigits($0.vehiclePlate ?? "") == digits }) {
                return true
            }
        } catch {
            return false
        }
        do {
            let shifts: [IdRow] = try await client
                .from("shifts")
                .select("id")
                .eq("personal_vehicle_id", value: vehicleId)
                .limit(1)
                .execute()
                .value
            return !shifts.isEmpty
        } catch {
            return false
        }
    }

    func fetchAdminUsers() async throws -> [AdminUserListItem] {
        async let profilesReq: [AdminProfileRow] = client
            .from("profiles")
            .select(
                "id, full_name, email, callsign, phone, active, invite_pending, otp_login_enabled, otp_users_page_enabled, availability, available_from, volunteer_status"
            )
            .order("full_name", ascending: true)
            .execute()
            .value
        async let rolesReq: [AdminUserRoleRow] = client
            .from("user_roles")
            .select("user_id, role")
            .execute()
            .value
        async let vehiclesReq: [CrewVehicleRow] = client
            .from("vehicles")
            .select("id, user_id, plate_number, model, archived")
            .execute()
            .value
        async let addressesReq: [AdminAddressRow] = client
            .from("user_addresses")
            .select("user_id, kind, label, formatted_address")
            .execute()
            .value
        let profiles = try await profilesReq
        let rolesByUser = Dictionary(grouping: try await rolesReq, by: \.userId)
        let vehiclesByUser = Dictionary(grouping: try await vehiclesReq, by: \.userId)
        let addressesByUser = Dictionary(grouping: try await addressesReq, by: \.userId)
        return profiles.map { row in
            AdminUserListItem(
                id: row.id,
                fullName: row.fullName,
                email: row.email,
                callsign: row.callsign,
                phone: row.phone,
                active: row.active,
                invitePending: row.invitePending,
                otpLoginEnabled: row.otpLoginEnabled,
                otpUsersPageEnabled: row.otpUsersPageEnabled,
                availability: row.availability,
                availableFrom: row.availableFrom,
                volunteerStatus: row.volunteerStatus,
                roles: rolesByUser[row.id]?.map(\.role) ?? [],
                vehicles: (vehiclesByUser[row.id] ?? []).map {
                    AdminVehicleItem(
                        id: $0.id,
                        plateNumber: $0.plateNumber,
                        model: $0.model ?? "",
                        archived: $0.archived == true
                    )
                },
                addresses: (addressesByUser[row.id] ?? []).map {
                    AdminAddressItem(
                        kind: $0.kind,
                        label: $0.label,
                        formattedAddress: $0.formattedAddress
                    )
                }
            )
        }
        .sorted { compareAdminUsers($0.sortKey, $1.sortKey) < 0 }
    }

    func inviteAdminUser(_ draft: InviteDraft) async -> AdminUsersActionResult {
        let errors = validateInviteDraft(draft)
        if !errors.isEmpty {
            return AdminUsersActionResult(error: errors.formMessage ?? INVITE_IDENTITY_ERROR)
        }
        let call = AdminInviteCall(
            fullName: draft.fullName.trimmingCharacters(in: .whitespacesAndNewlines),
            email: draft.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            callsign: draft.callsign.trimmingCharacters(in: .whitespacesAndNewlines),
            phone: {
                let digits = phoneDigits(draft.phone)
                return digits.isEmpty ? nil : digits
            }(),
            volunteerStatus: draft.volunteerStatus.rawValue,
            roles: {
                var seen = Set<String>()
                return draft.roles.filter { seen.insert($0).inserted }
            }(),
            vehicles: draft.vehicles
                .filter { !$0.archived && !$0.plateNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .map {
                    AdminInviteVehicle(
                        plateNumber: plateNumberForSave($0.plateNumber) ?? $0.plateNumber.trimmingCharacters(in: .whitespacesAndNewlines),
                        model: $0.model.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                }
        )
        let result = await invokeAdminUsersAction(call, fallback: INVITE_SAVE_FAILED)
        if result.ok, let userId = result.userId {
            _ = try? await client
                .from("profiles")
                .update(VolunteerStatusWrite(volunteerStatus: draft.volunteerStatus.rawValue, updatedAt: nowIso()))
                .eq("id", value: userId)
                .execute()
        }
        return result
    }

    func setAdminUserActive(userId: String, active: Bool) async -> String? {
        await invokeAdminUsersAction(
            AdminUserIdActionCall(action: active ? "reactivate" : "deactivate", userId: userId),
            fallback: SET_ACTIVE_FAILED
        ).error
    }

    func deleteAdminUser(userId: String) async -> String? {
        await invokeAdminUsersAction(
            AdminUserIdActionCall(action: "delete", userId: userId),
            fallback: DELETE_USER_FAILED
        ).error
    }

    func resendAdminInvite(userId: String) async -> AdminUsersActionResult {
        await invokeAdminUsersAction(
            AdminInviteLinkCall(action: "resend_invite", userId: userId, sendEmail: true),
            fallback: RESEND_INVITE_FAILED
        )
    }

    func copyAdminInviteLink(userId: String) async -> AdminUsersActionResult {
        await invokeAdminUsersAction(
            AdminInviteLinkCall(action: "copy_invite_link", userId: userId, sendEmail: false),
            fallback: COPY_INVITE_FAILED
        )
    }

    func setAdminUserOtp(userId: String, kind: String, enabled: Bool) async -> String? {
        do {
            let response: PhoneOtpResponse
            if kind == "users_page" {
                response = try await client.functions.invoke(
                    "phone-otp",
                    options: functionOptions(
                        body: SetOtpUsersPageCall(userId: userId, otpUsersPageEnabled: enabled)
                    )
                )
            } else {
                response = try await client.functions.invoke(
                    "phone-otp",
                    options: functionOptions(
                        body: SetOtpLoginCall(userId: userId, otpLoginEnabled: enabled)
                    )
                )
            }
            return response.error
        } catch {
            return OTP_SET_FAILED
        }
    }

    func saveAdminUser(_ draft: InviteDraft) async -> String? {
        guard let userId = draft.id else { return SAVE_USER_FAILED }
        do {
            try await client
                .from("profiles")
                .update(
                    AdminProfileSaveRow(
                        fullName: draft.fullName.trimmingCharacters(in: .whitespacesAndNewlines),
                        callsign: draft.callsign.trimmingCharacters(in: .whitespacesAndNewlines),
                        phone: {
                            let digits = phoneDigits(draft.phone)
                            return digits.isEmpty ? nil : digits
                        }(),
                        volunteerStatus: draft.volunteerStatus.rawValue,
                        updatedAt: nowIso()
                    )
                )
                .eq("id", value: userId)
                .execute()
            if let error = await syncUserRoles(userId: userId, nextRoles: draft.roles) {
                return error
            }
            return await syncUserVehicles(userId: userId, nextVehicles: draft.vehicles)
        } catch {
            return SAVE_USER_FAILED
        }
    }

    func deleteAdminVehicle(vehicleId: String) async -> String? {
        do {
            try await client.from("vehicles").delete().eq("id", value: vehicleId).execute()
            return nil
        } catch {
            return VEHICLE_DELETE_FAILED
        }
    }

    func archiveAdminVehicle(vehicleId: String) async -> String? {
        do {
            try await client
                .from("vehicles")
                .update(VehicleArchivedWrite(archived: true))
                .eq("id", value: vehicleId)
                .execute()
            return nil
        } catch {
            return VEHICLE_ARCHIVE_FAILED
        }
    }

    func unarchiveAdminVehicle(vehicleId: String) async -> String? {
        do {
            try await client
                .from("vehicles")
                .update(VehicleArchivedWrite(archived: false))
                .eq("id", value: vehicleId)
                .execute()
            return nil
        } catch {
            return VEHICLE_UNARCHIVE_FAILED
        }
    }

    private func syncUserRoles(userId: String, nextRoles: [String]) async -> String? {
        let existing: [String]
        do {
            let rows: [RoleRow] = try await client
                .from("user_roles")
                .select("role")
                .eq("user_id", value: userId)
                .execute()
                .value
            existing = rows.map(\.role)
        } catch {
            return SAVE_ROLES_FAILED
        }
        let diff = syncUserRolesDiff(current: existing, next: nextRoles)
        do {
            if !diff.toRemove.isEmpty {
                try await client
                    .from("user_roles")
                    .delete()
                    .eq("user_id", value: userId)
                    .in("role", values: diff.toRemove)
                    .execute()
            }
            if !diff.toAdd.isEmpty {
                try await client
                    .from("user_roles")
                    .insert(diff.toAdd.map { UserRoleWrite(userId: userId, role: $0) })
                    .execute()
            }
        } catch {
            return SAVE_ROLES_FAILED
        }
        return nil
    }

    private func syncUserVehicles(userId: String, nextVehicles: [AdminVehicleDraft]) async -> String? {
        if findDuplicatePlate(nextVehicles.map(\.plateNumber)) != nil {
            return DUPLICATE_PLATE_ERROR
        }
        let existing: [CrewVehicleRow]
        do {
            existing = try await client
                .from("vehicles")
                .select("id, user_id, plate_number, model, archived")
                .eq("user_id", value: userId)
                .execute()
                .value
        } catch {
            return SAVE_VEHICLES_FAILED
        }
        let nextWithIds = nextVehicles.filter { !($0.id ?? "").isEmpty }
        let nextIds = Set(nextWithIds.compactMap(\.id))
        do {
            for row in existing where !nextIds.contains(row.id) {
                try await client.from("vehicles").delete().eq("id", value: row.id).execute()
            }
            for vehicle in nextWithIds {
                guard let id = vehicle.id else { continue }
                if vehicle.archived {
                    try await client
                        .from("vehicles")
                        .update(VehicleArchivedWrite(archived: true))
                        .eq("id", value: id)
                        .eq("user_id", value: userId)
                        .execute()
                    continue
                }
                let plate = plateNumberForSave(vehicle.plateNumber)
                    ?? vehicle.plateNumber.trimmingCharacters(in: .whitespacesAndNewlines)
                let model = vehicle.model.trimmingCharacters(in: .whitespacesAndNewlines)
                if plate.isEmpty || model.isEmpty { continue }
                try await client
                    .from("vehicles")
                    .update(OwnVehiclePlateWrite(plateNumber: plate, model: model, archived: false))
                    .eq("id", value: id)
                    .eq("user_id", value: userId)
                    .execute()
            }
            let toInsert = nextVehicles.filter {
                ($0.id ?? "").isEmpty
                    && !$0.plateNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && !$0.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            if !toInsert.isEmpty {
                try await client
                    .from("vehicles")
                    .insert(
                        toInsert.map {
                            OwnVehicleInsert(
                                userId: userId,
                                plateNumber: plateNumberForSave($0.plateNumber)
                                    ?? $0.plateNumber.trimmingCharacters(in: .whitespacesAndNewlines),
                                model: $0.model.trimmingCharacters(in: .whitespacesAndNewlines),
                                archived: false
                            )
                        }
                    )
                    .execute()
            }
        } catch {
            return isUniqueViolation(error) ? DUPLICATE_PLATE_ERROR : SAVE_VEHICLES_FAILED
        }
        return nil
    }

    private func impersonationHeaders() -> [String: String] {
        ViewAsStore.isImpersonating() ? ["x-yahpaz-impersonating": "1"] : [:]
    }

    private func functionOptions(body: some Encodable) -> FunctionInvokeOptions {
        FunctionInvokeOptions(headers: impersonationHeaders(), body: body)
    }

    func submitUserFeedback(
        kind: String,
        body: String,
        pagePath: String?,
        audioBytes: Data?,
        audioMime: String?,
        attachments: [FeedbackAttachmentUpload] = []
    ) async -> String? {
        let hasAudio = audioBytes != nil && !(audioBytes?.isEmpty ?? true)
        if let error = feedbackSubmitError(kind: kind, body: body, hasAudio: hasAudio) {
            return error
        }
        guard let userId = await sessionUserId() else { return FEEDBACK_NETWORK }
        if hasAudio, let audioBytes, audioBytes.count > FEEDBACK_AUDIO_MAX_BYTES {
            return FEEDBACK_AUDIO_SIZE_ERROR
        }
        let incomingMeta = attachments.map {
            FeedbackPickedMeta(name: $0.name, mime: $0.mime, size: $0.bytes.count)
        }
        let added = addFeedbackAttachments(current: [], incoming: incomingMeta)
        if let error = added.error { return error }
        let id = UUID().uuidString.lowercased()
        var storagePath: String?
        var mime: String?
        var size: Int?
        var uploadedPaths: [String] = []
        if hasAudio, let audioBytes {
            mime = normalizeFeedbackAudioMime(audioMime ?? "audio/mp4")
            storagePath = feedbackStoragePath(userId: userId, feedbackId: id, mime: mime ?? "audio/mp4")
            size = audioBytes.count
            do {
                try await client.storage.from("user-feedback").upload(
                    storagePath ?? "",
                    data: audioBytes,
                    options: FileOptions(contentType: mime, upsert: false)
                )
                if let storagePath { uploadedPaths.append(storagePath) }
            } catch {
                return FEEDBACK_NETWORK
            }
        }
        var attachmentRows: [UserFeedbackAttachmentJson] = []
        for file in attachments {
            let fileMime = normalizeFeedbackAttachmentMime(mime: file.mime, name: file.name)
            let attachmentId = UUID().uuidString.lowercased()
            let filePath = fileMime.flatMap {
                feedbackAttachmentStoragePath(
                    userId: userId,
                    feedbackId: id,
                    attachmentId: attachmentId,
                    mime: $0,
                    name: file.name
                )
            }
            guard let fileMime, let filePath else {
                for path in uploadedPaths {
                    _ = try? await client.storage.from("user-feedback").remove(paths: [path])
                }
                return FEEDBACK_ATTACH_TYPE_ERROR
            }
            do {
                try await client.storage.from("user-feedback").upload(
                    filePath,
                    data: file.bytes,
                    options: FileOptions(contentType: fileMime, upsert: false)
                )
                uploadedPaths.append(filePath)
                attachmentRows.append(
                    UserFeedbackAttachmentJson(
                        path: filePath,
                        mime: fileMime,
                        size: file.bytes.count,
                        name: sanitizeFeedbackAttachmentName(file.name)
                    )
                )
            } catch {
                for path in uploadedPaths {
                    _ = try? await client.storage.from("user-feedback").remove(paths: [path])
                }
                return FEEDBACK_NETWORK
            }
        }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let storedBody = trimmed.isEmpty ? nil : trimmed
        let storedPath: String? = {
            guard let raw = pagePath?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
                return nil
            }
            return String(raw.prefix(200))
        }()
        do {
            try await client
                .from("user_feedback")
                .insert(
                    UserFeedbackInsert(
                        id: id,
                        userId: userId,
                        kind: kind,
                        body: storedBody,
                        pagePath: storedPath,
                        status: "open",
                        audioStoragePath: storagePath,
                        audioMimeType: mime,
                        audioByteSize: size,
                        attachments: attachmentRows.isEmpty ? nil : attachmentRows
                    )
                )
                .execute()
        } catch {
            for path in uploadedPaths {
                _ = try? await client.storage.from("user-feedback").remove(paths: [path])
            }
            if !attachmentRows.isEmpty && isMissingFeedbackAttachmentsColumn(error.localizedDescription) {
                return FEEDBACK_ATTACH_UNAVAILABLE
            }
            return FEEDBACK_NETWORK
        }
        return nil
    }

    private func invokeAdminUsersAction<T: Encodable>(_ body: T, fallback: String) async -> AdminUsersActionResult {
        do {
            let payload: AdminUsersResponse = try await client.functions.invoke(
                "admin-users",
                options: functionOptions(body: body)
            )
            if let error = payload.error {
                return AdminUsersActionResult(error: error)
            }
            return AdminUsersActionResult(
                message: payload.message,
                userId: payload.userId,
                actionLink: payload.actionLink
            )
        } catch {
            return AdminUsersActionResult(error: fallback)
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
                options: functionOptions(body: body)
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

private struct LeadKmWrite: Encodable {
    var totalKm: Double
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case totalKm = "total_km"
        case updatedAt = "updated_at"
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

private struct FillStatusWrite: Encodable {
    var status: String
    var updatedAt: String
    enum CodingKeys: String, CodingKey {
        case status
        case updatedAt = "updated_at"
    }
}

private struct EventMediaInsert: Encodable {
    var id: String
    var eventId: String
    var uploadedBy: String
    var caption: String?
    var takenWhen: String
    var storagePath: String
    var mimeType: String
    var byteSize: Int
    var width: Int?
    var height: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case eventId = "event_id"
        case uploadedBy = "uploaded_by"
        case caption
        case takenWhen = "taken_when"
        case storagePath = "storage_path"
        case mimeType = "mime_type"
        case byteSize = "byte_size"
        case width
        case height
    }
}

private struct EventMediaUpdate: Encodable {
    var takenWhen: String
    var caption: String?
    enum CodingKeys: String, CodingKey {
        case takenWhen = "taken_when"
        case caption
    }
}

private struct EventMediaPlateWrite: Encodable {
    var mediaId: String
    var treatedPlateId: String
    enum CodingKeys: String, CodingKey {
        case mediaId = "media_id"
        case treatedPlateId = "treated_plate_id"
    }
}

private struct EventMediaPlateLink: Decodable {
    var treatedPlateId: String
    enum CodingKeys: String, CodingKey {
        case treatedPlateId = "treated_plate_id"
    }
}

private struct EventMediaRow: Decodable {
    var id: String
    var eventId: String
    var uploadedBy: String
    var caption: String?
    var takenWhen: String
    var storagePath: String
    var mimeType: String
    var byteSize: Int
    var width: Int?
    var height: Int?
    var createdAt: String
    var uploader: PersonName?
    var plates: [EventMediaPlateLink]

    enum CodingKeys: String, CodingKey {
        case id
        case eventId = "event_id"
        case uploadedBy = "uploaded_by"
        case caption
        case takenWhen = "taken_when"
        case storagePath = "storage_path"
        case mimeType = "mime_type"
        case byteSize = "byte_size"
        case width
        case height
        case createdAt = "created_at"
        case uploader
        case plates
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        eventId = try c.decode(String.self, forKey: .eventId)
        uploadedBy = try c.decode(String.self, forKey: .uploadedBy)
        caption = try c.decodeIfPresent(String.self, forKey: .caption)
        takenWhen = try c.decode(String.self, forKey: .takenWhen)
        storagePath = try c.decode(String.self, forKey: .storagePath)
        mimeType = try c.decodeIfPresent(String.self, forKey: .mimeType) ?? "image/jpeg"
        byteSize = try c.decode(Int.self, forKey: .byteSize)
        width = try c.decodeIfPresent(Int.self, forKey: .width)
        height = try c.decodeIfPresent(Int.self, forKey: .height)
        createdAt = try c.decode(String.self, forKey: .createdAt)
        if let value = try? c.decode(PersonName.self, forKey: .uploader) {
            uploader = value
        } else if let values = try? c.decode([PersonName].self, forKey: .uploader) {
            uploader = values.first
        } else {
            uploader = nil
        }
        plates = (try? c.decode([EventMediaPlateLink].self, forKey: .plates)) ?? []
    }

    func toDomain(signedUrl: String?, treatedPlateIds: [String]? = nil) -> EventMedia {
        let name = uploader?.fullName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return EventMedia(
            id: id,
            eventId: eventId,
            uploadedBy: uploadedBy,
            uploaderName: name.isEmpty ? nil : name,
            treatedPlateIds: treatedPlateIds ?? uniquePlateIds(plates.map(\.treatedPlateId)),
            caption: caption,
            takenWhen: parseEventMediaTakenWhen(takenWhen) ?? .beforeTreatment,
            storagePath: storagePath,
            mimeType: mimeType,
            byteSize: byteSize,
            width: width,
            height: height,
            createdAt: createdAt,
            signedUrl: signedUrl
        )
    }
}

private struct EventMediaPlateOptionRow: Decodable {
    var id: String
    var plateNumber: String?
    var model: String?
    var color: String?
    var logoSlug: String?

    enum CodingKeys: String, CodingKey {
        case id
        case plateNumber = "plate_number"
        case model
        case color
        case logoSlug = "logo_slug"
    }

    var toOption: EventMediaPlateOption? {
        let plate = plateNumber?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if id.isEmpty || plate.isEmpty { return nil }
        return EventMediaPlateOption(
            id: id,
            plateNumber: plate,
            model: model,
            color: color,
            logoSlug: logoSlug
        )
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

private struct OwnVehicleInsert: Encodable {
    var userId: String
    var plateNumber: String
    var model: String
    var archived: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case plateNumber = "plate_number"
        case model
        case archived
    }
}

private struct OwnVehiclePlateWrite: Encodable {
    var plateNumber: String
    var model: String
    var archived: Bool

    enum CodingKeys: String, CodingKey {
        case plateNumber = "plate_number"
        case model
        case archived
    }
}

private struct VehicleArchivedWrite: Encodable {
    var archived: Bool
}

private struct SetDefaultVehicleCall: Encodable {
    var vehicleId: String
    enum CodingKeys: String, CodingKey {
        case vehicleId = "p_vehicle_id"
    }
}

private struct ReportSessionCall: Encodable {
    var versionCode: Int
    var versionName: String
    enum CodingKeys: String, CodingKey {
        case versionCode = "p_version_code"
        case versionName = "p_version_name"
    }
}

private struct AdminInviteVehicle: Encodable {
    var plateNumber: String
    var model: String
    enum CodingKeys: String, CodingKey {
        case plateNumber = "plate_number"
        case model
    }
}

private struct AdminInviteCall: Encodable {
    var action = "invite"
    var fullName: String
    var email: String
    var callsign: String
    var phone: String?
    var volunteerStatus: String
    var roles: [String]
    var vehicles: [AdminInviteVehicle]

    enum CodingKeys: String, CodingKey {
        case action
        case fullName = "full_name"
        case email
        case callsign
        case phone
        case volunteerStatus = "volunteer_status"
        case roles
        case vehicles
    }
}

private struct AdminUserIdActionCall: Encodable {
    var action: String
    var userId: String
    enum CodingKeys: String, CodingKey {
        case action
        case userId = "user_id"
    }
}

private struct AdminInviteLinkCall: Encodable {
    var action: String
    var userId: String
    var sendEmail: Bool
    enum CodingKeys: String, CodingKey {
        case action
        case userId = "user_id"
        case sendEmail = "send_email"
    }
}

private struct AdminProfileSaveRow: Encodable {
    var fullName: String
    var callsign: String
    var phone: String?
    var volunteerStatus: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case callsign
        case phone
        case volunteerStatus = "volunteer_status"
        case updatedAt = "updated_at"
    }
}

private struct UserRoleWrite: Encodable {
    var userId: String
    var role: String
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case role
    }
}

private struct VolunteerStatusWrite: Encodable {
    var volunteerStatus: String
    var updatedAt: String
    enum CodingKeys: String, CodingKey {
        case volunteerStatus = "volunteer_status"
        case updatedAt = "updated_at"
    }
}

private struct SetOtpLoginCall: Encodable {
    var action = "set_otp_flags"
    var userId: String
    var otpLoginEnabled: Bool
    enum CodingKeys: String, CodingKey {
        case action
        case userId = "user_id"
        case otpLoginEnabled = "otp_login_enabled"
    }
}

private struct SetOtpUsersPageCall: Encodable {
    var action = "set_otp_flags"
    var userId: String
    var otpUsersPageEnabled: Bool
    enum CodingKeys: String, CodingKey {
        case action
        case userId = "user_id"
        case otpUsersPageEnabled = "otp_users_page_enabled"
    }
}

private struct SyncShiftBornEventsCall: Encodable {
    var shiftId: String
    enum CodingKeys: String, CodingKey {
        case shiftId = "p_shift_id"
    }
}

private struct ShiftInsert: Encodable {
    var shiftDate: String
    var shiftKind: String
    var vehicleType: String
    var personalVehicleId: String?
    var notes: String?
    var status: String
    var shiftLeadId: String
    var lastSavedBy: String
    var updatedAt: String

    init(
        shiftDate: String,
        shiftKind: String,
        vehicleType: String,
        personalVehicleId: String?,
        notes: String?,
        shiftLeadId: String,
        lastSavedBy: String,
        updatedAt: String
    ) {
        self.shiftDate = shiftDate
        self.shiftKind = shiftKind
        self.vehicleType = vehicleType
        self.personalVehicleId = personalVehicleId
        self.notes = notes
        self.status = ShiftStatus.draft.rawValue
        self.shiftLeadId = shiftLeadId
        self.lastSavedBy = lastSavedBy
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case shiftDate = "shift_date"
        case shiftKind = "shift_kind"
        case vehicleType = "vehicle_type"
        case personalVehicleId = "personal_vehicle_id"
        case notes
        case status
        case shiftLeadId = "shift_lead_id"
        case lastSavedBy = "last_saved_by"
        case updatedAt = "updated_at"
    }
}

private struct MyActiveEventPrefWrite: Encodable {
    var userId: String
    var eventId: String
    var kind: String
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case eventId = "event_id"
        case kind
    }
}

private struct EventInsert: Encodable {
    var eventDate: String
    var policeEventId: String?
    var districtId: String?
    var patrolCallsign: String?
    var eventTypeId: String?
    var roadId: String?
    var location: String?
    var station: String?
    var notes: String?
    var isCancelled = false
    var busLane: Bool
    var status: String
    var shiftLeadId: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case eventDate = "event_date"
        case policeEventId = "police_event_id"
        case districtId = "district_id"
        case patrolCallsign = "patrol_callsign"
        case eventTypeId = "event_type_id"
        case roadId = "road_id"
        case location, station, notes
        case isCancelled = "is_cancelled"
        case busLane = "bus_lane"
        case status
        case shiftLeadId = "shift_lead_id"
        case updatedAt = "updated_at"
    }
}

private struct EventUpdateWrite: Encodable {
    var eventDate: String
    var policeEventId: String?
    var districtId: String?
    var patrolCallsign: String?
    var eventTypeId: String?
    var roadId: String?
    var location: String?
    var station: String?
    var notes: String?
    var isCancelled: Bool
    var busLane: Bool
    var status: String
    var shiftLeadId: String?
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case eventDate = "event_date"
        case policeEventId = "police_event_id"
        case districtId = "district_id"
        case patrolCallsign = "patrol_callsign"
        case eventTypeId = "event_type_id"
        case roadId = "road_id"
        case location, station, notes
        case isCancelled = "is_cancelled"
        case busLane = "bus_lane"
        case status
        case shiftLeadId = "shift_lead_id"
        case updatedAt = "updated_at"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(eventDate, forKey: .eventDate)
        try encodeNull(&c, policeEventId, .policeEventId)
        try encodeNull(&c, districtId, .districtId)
        try encodeNull(&c, patrolCallsign, .patrolCallsign)
        try encodeNull(&c, eventTypeId, .eventTypeId)
        try encodeNull(&c, roadId, .roadId)
        try encodeNull(&c, location, .location)
        try encodeNull(&c, station, .station)
        try encodeNull(&c, notes, .notes)
        try c.encode(isCancelled, forKey: .isCancelled)
        try c.encode(busLane, forKey: .busLane)
        try c.encode(status, forKey: .status)
        try encodeNull(&c, shiftLeadId, .shiftLeadId)
        try c.encode(updatedAt, forKey: .updatedAt)
    }
}

private func encodeNull<K: CodingKey>(
    _ c: inout KeyedEncodingContainer<K>,
    _ value: String?,
    _ key: K
) throws {
    if let value {
        try c.encode(value, forKey: key)
    } else {
        try c.encodeNil(forKey: key)
    }
}

private struct EventSecondaryLeadInsert: Encodable {
    var eventId: String
    var userId: String
    var locked: Bool
    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case userId = "user_id"
        case locked
    }
}

private struct EventSecondaryLeadLockWrite: Encodable {
    var locked: Bool
}

private struct EventResponderInsert: Encodable {
    var eventId: String
    var responderId: String
    var startedAt: String?
    var endedAt: String?
    var totalKm: Double?
    var emergencyMeans: Bool
    var status: String
    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case responderId = "responder_id"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case totalKm = "total_km"
        case emergencyMeans = "emergency_means"
        case status
    }
}

private struct EventResponderLeadWrite: Encodable {
    var startedAt: String?
    var endedAt: String?
    var totalKm: Double?
    var emergencyMeans: Bool
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case totalKm = "total_km"
        case emergencyMeans = "emergency_means"
        case updatedAt = "updated_at"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        if let startedAt { try c.encode(startedAt, forKey: .startedAt) } else { try c.encodeNil(forKey: .startedAt) }
        if let endedAt { try c.encode(endedAt, forKey: .endedAt) } else { try c.encodeNil(forKey: .endedAt) }
        if let totalKm { try c.encode(totalKm, forKey: .totalKm) } else { try c.encodeNil(forKey: .totalKm) }
        try c.encode(emergencyMeans, forKey: .emergencyMeans)
        try c.encode(updatedAt, forKey: .updatedAt)
    }
}

private struct EventTreatedVehicleInsert: Encodable {
    var eventResponderId: String
    var vehicleKindId: String
    var quantity: Int
    enum CodingKeys: String, CodingKey {
        case eventResponderId = "event_responder_id"
        case vehicleKindId = "vehicle_kind_id"
        case quantity
    }
}

private struct NotifyFillReadyCall: Encodable {
    var action = "notify_fill_ready"
    var eventResponderIds: [String]
    enum CodingKeys: String, CodingKey {
        case action
        case eventResponderIds = "event_responder_ids"
    }
}

private struct NotifyFillReadyResponse: Decodable {
    var error: String?
    var sent: [String]?
}

private struct ShiftUpdateWrite: Encodable {
    var shiftDate: String
    var shiftKind: String
    var vehicleType: String
    var personalVehicleId: String?
    var notes: String?
    var lastSavedBy: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case shiftDate = "shift_date"
        case shiftKind = "shift_kind"
        case vehicleType = "vehicle_type"
        case personalVehicleId = "personal_vehicle_id"
        case notes
        case lastSavedBy = "last_saved_by"
        case updatedAt = "updated_at"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(shiftDate, forKey: .shiftDate)
        try c.encode(shiftKind, forKey: .shiftKind)
        try c.encode(vehicleType, forKey: .vehicleType)
        try c.encode(personalVehicleId, forKey: .personalVehicleId)
        try c.encode(notes, forKey: .notes)
        try c.encode(lastSavedBy, forKey: .lastSavedBy)
        try c.encode(updatedAt, forKey: .updatedAt)
    }
}

private struct ShiftResponderInsert: Encodable {
    var shiftId: String
    var responderId: String
    enum CodingKeys: String, CodingKey {
        case shiftId = "shift_id"
        case responderId = "responder_id"
    }
}

private func nowIso() -> String {
    ISO8601DateFormatter().string(from: Date())
}

private struct VehiclePlateRef: Decodable {
    var vehiclePlate: String?
    enum CodingKeys: String, CodingKey {
        case vehiclePlate = "vehicle_plate"
    }
}

private func isUniqueViolation(_ error: Error) -> Bool {
    let raw = String(describing: error)
    return raw.contains("23505")
        || raw.localizedCaseInsensitiveContains("duplicate")
        || raw.localizedCaseInsensitiveContains("unique")
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

private struct ImpersonateCall: Encodable {
    var action: String
    var targetUserId: String
    enum CodingKeys: String, CodingKey {
        case action
        case targetUserId = "target_user_id"
    }
}

private struct UserFeedbackAttachmentJson: Encodable {
    var path: String
    var mime: String
    var size: Int
    var name: String
}

private struct UserFeedbackInsert: Encodable {
    var id: String
    var userId: String
    var kind: String
    var body: String?
    var pagePath: String?
    var status: String
    var audioStoragePath: String?
    var audioMimeType: String?
    var audioByteSize: Int?
    var attachments: [UserFeedbackAttachmentJson]?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case kind
        case body
        case pagePath = "page_path"
        case status
        case audioStoragePath = "audio_storage_path"
        case audioMimeType = "audio_mime_type"
        case audioByteSize = "audio_byte_size"
        case attachments
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
