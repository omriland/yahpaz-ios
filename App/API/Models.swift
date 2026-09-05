import Foundation
import YahpazDomain

struct Named: Decodable, Hashable, Sendable {
    var name: String?
}

struct PersonName: Decodable, Hashable, Sendable {
    var fullName: String?
    var callsign: String?

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case callsign
    }

    var display: String? {
        let name = fullName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let sign = callsign?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if name.isEmpty && sign.isEmpty { return nil }
        if name.isEmpty { return sign }
        if sign.isEmpty { return name }
        return "\(name) · \(sign)"
    }
}

struct PlateRef: Decodable, Hashable, Sendable {
    var plateNumber: String?
    enum CodingKeys: String, CodingKey { case plateNumber = "plate_number" }
}

struct ShiftSummary: Decodable, Hashable, Sendable {
    var shiftDate: String?
    var shiftKind: String?
    var vehicleType: String?
    var personalVehicle: PlateRef?

    enum CodingKeys: String, CodingKey {
        case shiftDate = "shift_date"
        case shiftKind = "shift_kind"
        case vehicleType = "vehicle_type"
        case personalVehicle = "personal_vehicle"
    }
}

struct EventSecondaryLeadRow: Decodable, Hashable, Sendable {
    var userId: String
    var locked: Bool
    var addedAt: String?
    var profile: PersonName?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case locked
        case addedAt = "added_at"
        case profile
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userId = try c.decode(String.self, forKey: .userId)
        locked = try c.decodeIfPresent(Bool.self, forKey: .locked) ?? false
        addedAt = try c.decodeIfPresent(String.self, forKey: .addedAt)
        if let value = try? c.decode(PersonName.self, forKey: .profile) {
            profile = value
        } else if let values = try? c.decode([PersonName].self, forKey: .profile) {
            profile = values.first
        } else {
            profile = nil
        }
    }

    func asDomain() -> SecondaryLead {
        SecondaryLead(
            userId: userId,
            locked: locked,
            fullName: profile?.fullName ?? "",
            callsign: profile?.callsign ?? "",
            addedAt: addedAt
        )
    }

    var namePair: (String?, String?) { (profile?.fullName, profile?.callsign) }
}

struct ResponderSummary: Decodable, Hashable, Sendable, Identifiable {
    var id: String
    var responderId: String
    var status: ParticipationStatus
    var fillCompletableAt: String?
    var totalKm: Double?
    var startedAt: String?
    var endedAt: String?
    var profile: PersonName?

    enum CodingKeys: String, CodingKey {
        case id
        case responderId = "responder_id"
        case status
        case fillCompletableAt = "fill_completable_at"
        case totalKm = "total_km"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case profile
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        responderId = try c.decode(String.self, forKey: .responderId)
        status = try c.decode(ParticipationStatus.self, forKey: .status)
        fillCompletableAt = try c.decodeIfPresent(String.self, forKey: .fillCompletableAt)
        totalKm = Self.number(c, .totalKm)
        startedAt = try c.decodeIfPresent(String.self, forKey: .startedAt)
        endedAt = try c.decodeIfPresent(String.self, forKey: .endedAt)
        if let value = try? c.decode(PersonName.self, forKey: .profile) {
            profile = value
        } else if let values = try? c.decode([PersonName].self, forKey: .profile) {
            profile = values.first
        } else {
            profile = nil
        }
    }

    private static func number(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Double? {
        if let value = try? c.decodeIfPresent(Double.self, forKey: key) { return value }
        if let value = try? c.decodeIfPresent(Int.self, forKey: key) { return Double(value) }
        if let value = try? c.decodeIfPresent(String.self, forKey: key) { return Double(value) }
        return nil
    }
}

struct EventListItem: Decodable, Hashable, Identifiable, Sendable {
    var id: String
    var eventDate: String
    var policeEventId: String?
    var patrolCallsign: String?
    var location: String?
    var status: EventStatus
    var isCancelled: Bool
    var busLane: Bool
    var origin: String?
    var shiftLeadId: String?
    var shiftId: String?
    var frozenOver60km: Bool
    var frozenSuspiciousDuplicate: Bool
    var district: Named?
    var eventType: Named?
    var road: Named?
    var shiftLead: PersonName?
    var secondaryLeads: [EventSecondaryLeadRow]
    var shift: ShiftSummary?
    var responders: [ResponderSummary]

    enum CodingKeys: String, CodingKey {
        case id
        case eventDate = "event_date"
        case policeEventId = "police_event_id"
        case patrolCallsign = "patrol_callsign"
        case location
        case status
        case isCancelled = "is_cancelled"
        case busLane = "bus_lane"
        case origin
        case shiftLeadId = "shift_lead_id"
        case shiftId = "shift_id"
        case frozenOver60km = "frozen_over_60km"
        case frozenSuspiciousDuplicate = "frozen_suspicious_duplicate"
        case district
        case eventType = "event_type"
        case road
        case shiftLead = "shift_lead"
        case secondaryLeads = "secondary_leads"
        case shift
        case responders
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        eventDate = try c.decode(String.self, forKey: .eventDate)
        policeEventId = try c.decodeIfPresent(String.self, forKey: .policeEventId)
        patrolCallsign = try c.decodeIfPresent(String.self, forKey: .patrolCallsign)
        location = try c.decodeIfPresent(String.self, forKey: .location)
        status = try c.decode(EventStatus.self, forKey: .status)
        isCancelled = try c.decodeIfPresent(Bool.self, forKey: .isCancelled) ?? false
        busLane = try c.decodeIfPresent(Bool.self, forKey: .busLane) ?? false
        origin = try c.decodeIfPresent(String.self, forKey: .origin)
        shiftLeadId = try c.decodeIfPresent(String.self, forKey: .shiftLeadId)
        shiftId = try c.decodeIfPresent(String.self, forKey: .shiftId)
        frozenOver60km = try c.decodeIfPresent(Bool.self, forKey: .frozenOver60km) ?? false
        frozenSuspiciousDuplicate = try c.decodeIfPresent(Bool.self, forKey: .frozenSuspiciousDuplicate) ?? false
        district = Self.decodeOne(Named.self, from: c, key: .district)
        eventType = Self.decodeOne(Named.self, from: c, key: .eventType)
        road = Self.decodeOne(Named.self, from: c, key: .road)
        shiftLead = Self.decodeOne(PersonName.self, from: c, key: .shiftLead)
        secondaryLeads = try c.decodeIfPresent([EventSecondaryLeadRow].self, forKey: .secondaryLeads) ?? []
        shift = Self.decodeOne(ShiftSummary.self, from: c, key: .shift)
        responders = try c.decodeIfPresent([ResponderSummary].self, forKey: .responders) ?? []
    }

    func ownParticipation(userId: String) -> ParticipationStatus? {
        responders.first(where: { $0.responderId == userId })?.status
    }

    func ownTotalKm(userId: String) -> Double? {
        responders.first(where: { $0.responderId == userId })?.totalKm
    }

    func ownFillCompletableAt(userId: String) -> String? {
        responders.first(where: { $0.responderId == userId })?.fillCompletableAt
    }

    var typeLabel: String {
        let name = eventType?.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if origin == "shift" {
            return name.isEmpty ? "(משמרת)" : "\(name) (משמרת)"
        }
        return name
    }

    var shiftGroupTitle: String {
        guard let shift else { return "משמרת" }
        var parts = ["משמרת"]
        if let date = shift.shiftDate { parts.append(formatDate(date)) }
        if let kind = shift.shiftKind, let label = SHIFT_KIND_LABELS[kind] { parts.append(label) }
        if let vehicle = shift.vehicleType {
            let label = VEHICLE_TYPE_LABELS[vehicle] ?? vehicle
            if vehicle == "personal", let plate = shift.personalVehicle?.plateNumber, !plate.isEmpty {
                parts.append("\(label) \(formatPlate(plate))")
            } else {
                parts.append(label)
            }
        }
        return parts.joined(separator: " · ")
    }

    var searchFields: MineSearchFields {
        MineSearchFields(policeEventId: policeEventId, roadName: road?.name, location: location)
    }

    var freeze: EventFreezeFlags {
        EventFreezeFlags(frozenOver60km: frozenOver60km, frozenSuspiciousDuplicate: frozenSuspiciousDuplicate)
    }

    var unitSearchFields: [String?] {
        [
            policeEventId,
            road?.name,
            location,
            eventType?.name,
            {
                let caption = formatLeadsCaption(
                    mainFullName: shiftLead?.fullName,
                    mainCallsign: shiftLead?.callsign,
                    secondaries: secondaryLeads.map(\.namePair)
                )
                return caption.isEmpty ? shiftLead?.display : caption
            }(),
            formatDate(eventDate),
        ]
    }

    func leadsCaption() -> String {
        eventLeadsCaption(
            origin: origin,
            mainFullName: shiftLead?.fullName,
            mainCallsign: shiftLead?.callsign,
            secondaries: secondaryLeads.map(\.namePair)
        )
    }

    func asIncompleteSnapshot() -> IncompleteEventSnapshot {
        IncompleteEventSnapshot(
            policeEventId: policeEventId,
            patrolCallsign: patrolCallsign,
            hasDistrict: district != nil,
            hasEventType: eventType != nil,
            hasRoad: road != nil,
            location: location,
            responders: responders.map {
                IncompleteResponderSnapshot(totalKm: $0.totalKm, startedAt: $0.startedAt, endedAt: $0.endedAt)
            }
        )
    }

    func blocksAssignedVolunteerEdit(viewerId: String?) -> Bool {
        isAssignedVolunteerEventEditBlocked(
            viewerId: viewerId,
            responderIds: responders.map(\.responderId),
            secondaryLeadIds: secondaryLeads.map(\.userId)
        )
    }

    private static func decodeOne<T: Decodable>(
        _ type: T.Type,
        from c: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) -> T? {
        if let value = try? c.decode(T.self, forKey: key) { return value }
        if let values = try? c.decode([T].self, forKey: key) { return values.first }
        return nil
    }
}

struct VehicleOption: Decodable, Hashable, Identifiable, Sendable {
    var rowId: String?
    var plateNumber: String
    var model: String?
    var archived: Bool?
    var isDefault: Bool?

    var id: String { rowId ?? plateDigits(plateNumber) }

    enum CodingKeys: String, CodingKey {
        case rowId = "id"
        case plateNumber = "plate_number"
        case model
        case archived
        case isDefault = "is_default"
    }
}

struct FillAssignmentRow: Decodable, Sendable {
    var id: String
    var responderId: String
    var vehiclePlate: String?
    var odometerStart: Double?
    var odometerEnd: Double?
    var totalKm: Double?
    var route: String?
    var treatmentDetail: String?
    var treatmentNotes: String?
    var status: ParticipationStatus
    var updatedAt: String?
    var endedAt: String?
    var treatedPlates: [EventTreatedPlateRow]

    enum CodingKeys: String, CodingKey {
        case id
        case responderId = "responder_id"
        case vehiclePlate = "vehicle_plate"
        case odometerStart = "odometer_start"
        case odometerEnd = "odometer_end"
        case totalKm = "total_km"
        case route
        case treatmentDetail = "treatment_detail"
        case treatmentNotes = "treatment_notes"
        case status
        case updatedAt = "updated_at"
        case endedAt = "ended_at"
        case treatedPlates = "treated_plates"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        responderId = try c.decode(String.self, forKey: .responderId)
        vehiclePlate = try c.decodeIfPresent(String.self, forKey: .vehiclePlate)
        odometerStart = Self.number(c, .odometerStart)
        odometerEnd = Self.number(c, .odometerEnd)
        totalKm = Self.number(c, .totalKm)
        route = try c.decodeIfPresent(String.self, forKey: .route)
        treatmentDetail = try c.decodeIfPresent(String.self, forKey: .treatmentDetail)
        treatmentNotes = try c.decodeIfPresent(String.self, forKey: .treatmentNotes)
        status = try c.decode(ParticipationStatus.self, forKey: .status)
        updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt)
        endedAt = try c.decodeIfPresent(String.self, forKey: .endedAt)
        treatedPlates = try c.decodeIfPresent([EventTreatedPlateRow].self, forKey: .treatedPlates) ?? []
    }

    private static func number(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Double? {
        if let value = try? c.decodeIfPresent(Double.self, forKey: key) { return value }
        if let value = try? c.decodeIfPresent(Int.self, forKey: key) { return Double(value) }
        if let value = try? c.decodeIfPresent(String.self, forKey: key) { return Double(value) }
        return nil
    }
}

struct FillEventRow: Decodable, Sendable {
    var id: String
    var status: EventStatus
    var eventDate: String
    var policeEventId: String?
    var location: String?
    var isCancelled: Bool
    var eventType: Named?
    var road: Named?
    var shiftLead: PersonName?
    var responders: [FillAssignmentRow]

    enum CodingKeys: String, CodingKey {
        case id, status, location, responders
        case eventDate = "event_date"
        case policeEventId = "police_event_id"
        case isCancelled = "is_cancelled"
        case eventType = "event_type"
        case road
        case shiftLead = "shift_lead"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        status = try c.decode(EventStatus.self, forKey: .status)
        eventDate = try c.decode(String.self, forKey: .eventDate)
        policeEventId = try c.decodeIfPresent(String.self, forKey: .policeEventId)
        location = try c.decodeIfPresent(String.self, forKey: .location)
        isCancelled = try c.decodeIfPresent(Bool.self, forKey: .isCancelled) ?? false
        if let value = try? c.decode(Named.self, forKey: .eventType) { eventType = value }
        else { eventType = (try? c.decode([Named].self, forKey: .eventType))?.first }
        if let value = try? c.decode(Named.self, forKey: .road) { road = value }
        else { road = (try? c.decode([Named].self, forKey: .road))?.first }
        if let value = try? c.decode(PersonName.self, forKey: .shiftLead) { shiftLead = value }
        else { shiftLead = (try? c.decode([PersonName].self, forKey: .shiftLead))?.first }
        responders = try c.decodeIfPresent([FillAssignmentRow].self, forKey: .responders) ?? []
    }
}

struct FillContext: Sendable {
    var eventId: String
    var assignmentId: String
    var eventStatus: EventStatus
    var eventDate: String
    var policeEventId: String?
    var eventTypeName: String?
    var isCancelled: Bool
    var roadName: String?
    var location: String?
    var shiftLeadName: String?
    var totalKm: Double?
    var participationStatus: ParticipationStatus
    var updatedAt: String?
    var draft: ResponderFillDraft
    var vehicles: [ResponderVehicle]
    var endedAt: String?
}

struct ResponderVehicle: Identifiable, Hashable, Sendable {
    var plate: String
    var model: String
    var id: String { plate }

    var label: String {
        let modelText = model.trimmingCharacters(in: .whitespacesAndNewlines)
        return modelText.isEmpty ? formatPlate(plate) : "\(formatPlate(plate)) · \(modelText)"
    }
}

struct ProfileRecord: Decodable, Sendable {
    var id: String
    var fullName: String
    var email: String
    var callsign: String
    var phone: String?
    var active: Bool
    var mustChangePassword: Bool
    var availability: AvailabilityStatus
    var availableFrom: String?
    var lifetimeEventCount: Int
    var lifetimeKm: Double
    var lifetimeStatsUpdatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case email
        case callsign
        case phone
        case active
        case mustChangePassword = "must_change_password"
        case availability
        case availableFrom = "available_from"
        case lifetimeEventCount = "lifetime_event_count"
        case lifetimeKm = "lifetime_km"
        case lifetimeStatsUpdatedAt = "lifetime_stats_updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        fullName = try c.decodeIfPresent(String.self, forKey: .fullName) ?? ""
        email = try c.decodeIfPresent(String.self, forKey: .email) ?? ""
        callsign = try c.decodeIfPresent(String.self, forKey: .callsign) ?? ""
        phone = try c.decodeIfPresent(String.self, forKey: .phone)
        active = try c.decodeIfPresent(Bool.self, forKey: .active) ?? true
        mustChangePassword = try c.decodeIfPresent(Bool.self, forKey: .mustChangePassword) ?? false
        if let raw = try c.decodeIfPresent(String.self, forKey: .availability),
           let parsed = AvailabilityStatus(rawValue: raw)
        {
            availability = parsed
        } else {
            availability = .available
        }
        availableFrom = try c.decodeIfPresent(String.self, forKey: .availableFrom)
        if let count = try? c.decodeIfPresent(Int.self, forKey: .lifetimeEventCount) {
            lifetimeEventCount = count
        } else if let count = try? c.decodeIfPresent(Double.self, forKey: .lifetimeEventCount) {
            lifetimeEventCount = Int(count)
        } else {
            lifetimeEventCount = 0
        }
        if let km = try? c.decodeIfPresent(Double.self, forKey: .lifetimeKm) {
            lifetimeKm = km
        } else if let km = try? c.decodeIfPresent(Int.self, forKey: .lifetimeKm) {
            lifetimeKm = Double(km)
        } else {
            lifetimeKm = 0
        }
        lifetimeStatsUpdatedAt = try c.decodeIfPresent(String.self, forKey: .lifetimeStatsUpdatedAt)
    }
}

struct UnitContact: Decodable, Hashable, Sendable, Identifiable {
    var id: String
    var fullName: String
    var callsign: String
    var phone: String?
    var email: String

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case callsign
        case phone
        case email
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let value = try? c.decode(String.self, forKey: .id) {
            id = value
        } else if let value = try? c.decode(UUID.self, forKey: .id) {
            id = value.uuidString.lowercased()
        } else {
            id = try c.decode(String.self, forKey: .id)
        }
        fullName = try c.decodeIfPresent(String.self, forKey: .fullName) ?? ""
        callsign = try c.decodeIfPresent(String.self, forKey: .callsign) ?? ""
        phone = try c.decodeIfPresent(String.self, forKey: .phone)
        email = try c.decodeIfPresent(String.self, forKey: .email) ?? ""
    }

    var searchFields: ContactSearchFields {
        ContactSearchFields(fullName: fullName, callsign: callsign, email: email, phone: phone)
    }
}

struct RoleRow: Decodable, Sendable {
    var role: String
}

struct AssignmentIdRow: Decodable, Sendable {
    var eventId: String
    enum CodingKeys: String, CodingKey { case eventId = "event_id" }
}

struct ShiftAssignmentIdRow: Decodable, Sendable {
    var shiftId: String
    enum CodingKeys: String, CodingKey { case shiftId = "shift_id" }
}

struct ShiftCrewRow: Decodable, Hashable, Sendable, Identifiable {
    var id: String
    var responderId: String
    enum CodingKeys: String, CodingKey {
        case id
        case responderId = "responder_id"
    }
}

struct ShiftBornEvent: Decodable, Hashable, Sendable, Identifiable {
    var id: String
    var eventDate: String
    var policeEventId: String?
    var status: EventStatus
    var eventType: Named?

    enum CodingKeys: String, CodingKey {
        case id
        case eventDate = "event_date"
        case policeEventId = "police_event_id"
        case status
        case eventType = "event_type"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        eventDate = try c.decode(String.self, forKey: .eventDate)
        policeEventId = try c.decodeIfPresent(String.self, forKey: .policeEventId)
        status = try c.decode(EventStatus.self, forKey: .status)
        if let value = try? c.decode(Named.self, forKey: .eventType) {
            eventType = value
        } else {
            eventType = (try? c.decode([Named].self, forKey: .eventType))?.first
        }
    }
}

struct ShiftListItem: Decodable, Hashable, Identifiable, Sendable {
    var id: String
    var shiftDate: String
    var shiftKind: String
    var vehicleType: String
    var status: ShiftStatus
    var odometerStart: Double?
    var odometerEnd: Double?
    var personalVehicle: PlateRef?
    var shiftLead: PersonName?
    var responders: [ShiftCrewRow]
    var bornEvents: [ShiftBornEvent]

    enum CodingKeys: String, CodingKey {
        case id
        case shiftDate = "shift_date"
        case shiftKind = "shift_kind"
        case vehicleType = "vehicle_type"
        case status
        case odometerStart = "odometer_start"
        case odometerEnd = "odometer_end"
        case personalVehicle = "personal_vehicle"
        case shiftLead = "shift_lead"
        case responders
        case bornEvents = "born_events"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        shiftDate = try c.decode(String.self, forKey: .shiftDate)
        shiftKind = try c.decode(String.self, forKey: .shiftKind)
        vehicleType = try c.decode(String.self, forKey: .vehicleType)
        if let raw = try c.decodeIfPresent(String.self, forKey: .status),
           let parsed = ShiftStatus(rawValue: raw)
        {
            status = parsed
        } else {
            status = .draft
        }
        odometerStart = Self.number(c, .odometerStart)
        odometerEnd = Self.number(c, .odometerEnd)
        if let value = try? c.decode(PlateRef.self, forKey: .personalVehicle) {
            personalVehicle = value
        } else {
            personalVehicle = (try? c.decode([PlateRef].self, forKey: .personalVehicle))?.first
        }
        if let value = try? c.decode(PersonName.self, forKey: .shiftLead) {
            shiftLead = value
        } else {
            shiftLead = (try? c.decode([PersonName].self, forKey: .shiftLead))?.first
        }
        responders = try c.decodeIfPresent([ShiftCrewRow].self, forKey: .responders) ?? []
        bornEvents = try c.decodeIfPresent([ShiftBornEvent].self, forKey: .bornEvents) ?? []
    }

    var title: String {
        let kind = SHIFT_KIND_LABELS[shiftKind] ?? shiftKind
        let vehicle = VEHICLE_TYPE_LABELS[vehicleType] ?? vehicleType
        if vehicleType == "personal",
           let plate = personalVehicle?.plateNumber,
           !plate.isEmpty
        {
            return "\(kind) · \(vehicle) · \(formatPlate(plate))"
        }
        return "\(kind) · \(vehicle)"
    }

    var mineItem: MineShiftItem {
        MineShiftItem(id: id, date: shiftDate, odometerStart: odometerStart, odometerEnd: odometerEnd)
    }

    var unitSearchFields: [String?] {
        [
            formatDate(shiftDate),
            SHIFT_KIND_LABELS[shiftKind],
            VEHICLE_TYPE_LABELS[vehicleType],
            shiftLead?.display,
            personalVehicle?.plateNumber,
        ]
    }

    private static func number(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Double? {
        if let value = try? c.decodeIfPresent(Double.self, forKey: key) { return value }
        if let value = try? c.decodeIfPresent(Int.self, forKey: key) { return Double(value) }
        if let value = try? c.decodeIfPresent(String.self, forKey: key) { return Double(value) }
        return nil
    }
}

struct IdRow: Decodable, Sendable {
    var id: String
}

struct CrewVehicleRow: Decodable, Hashable, Identifiable, Sendable {
    var id: String
    var userId: String
    var plateNumber: String
    var model: String?
    var archived: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case plateNumber = "plate_number"
        case model
        case archived
    }
}

struct ShiftFormDetail: Decodable, Sendable {
    var id: String
    var shiftDate: String
    var shiftKind: String
    var vehicleType: String
    var notes: String?
    var personalVehicleId: String?
    var responders: [ShiftCrewRow] = []

    enum CodingKeys: String, CodingKey {
        case id
        case shiftDate = "shift_date"
        case shiftKind = "shift_kind"
        case vehicleType = "vehicle_type"
        case notes
        case personalVehicleId = "personal_vehicle_id"
        case responders
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        shiftDate = try c.decode(String.self, forKey: .shiftDate)
        shiftKind = try c.decode(String.self, forKey: .shiftKind)
        vehicleType = try c.decode(String.self, forKey: .vehicleType)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        personalVehicleId = try c.decodeIfPresent(String.self, forKey: .personalVehicleId)
        responders = try c.decodeIfPresent([ShiftCrewRow].self, forKey: .responders) ?? []
    }

    func toDraft() -> ShiftDraft {
        ShiftDraft(
            shiftDate: returnDateToInput(shiftDate),
            shiftKind: shiftKind,
            vehicleType: vehicleType,
            notes: notes ?? "",
            responderIds: responders.map(\.responderId),
            personalVehicleId: personalVehicleId
        )
    }
}

struct AssignableProfileRow: Decodable, Sendable {
    var id: String
    var fullName: String
    var callsign: String

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case callsign
    }

    var asProfile: AssignableProfile {
        AssignableProfile(id: id, fullName: fullName, callsign: callsign)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        fullName = try c.decodeIfPresent(String.self, forKey: .fullName) ?? ""
        callsign = try c.decodeIfPresent(String.self, forKey: .callsign) ?? ""
    }
}

struct TrackLoadResponse: Decodable, Sendable {
    var ok: Bool?
    var error: String?
    var ended: Bool?
    var eventType: String?
    var road: String?
    var location: String?

    enum CodingKeys: String, CodingKey {
        case ok, error, ended
        case eventType = "event_type"
        case road, location
    }
}

struct MyActiveEventPrefRow: Decodable, Hashable, Sendable {
    var userId: String
    var eventId: String
    var kind: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case eventId = "event_id"
        case kind
    }

    init(userId: String, eventId: String, kind: String) {
        self.userId = userId
        self.eventId = eventId
        self.kind = kind
    }
}

struct LookupRow: Decodable, Sendable {
    var id: String
    var name: String
    var code: String?
    var sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id, name, code
        case sortOrder = "sort_order"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        code = try c.decodeIfPresent(String.self, forKey: .code)
        if let value = try c.decodeIfPresent(Int.self, forKey: .sortOrder) {
            sortOrder = value
        } else if let value = try c.decodeIfPresent(Double.self, forKey: .sortOrder) {
            sortOrder = Int(value)
        } else {
            sortOrder = 0
        }
    }

    var asOption: LookupOption {
        LookupOption(id: id, name: name, code: code, sortOrder: sortOrder)
    }
}

struct EventLookups: Equatable, Sendable {
    var districts: [LookupOption] = []
    var eventTypes: [LookupOption] = []
    var roads: [LookupOption] = []
    var vehicleKinds: [LookupOption] = []

    var isEmpty: Bool { eventTypes.isEmpty && roads.isEmpty }
}

struct EventFormTreatedRow: Decodable, Sendable {
    var vehicleKindId: String
    var quantity: Int

    enum CodingKeys: String, CodingKey {
        case vehicleKindId = "vehicle_kind_id"
        case quantity
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        vehicleKindId = try c.decode(String.self, forKey: .vehicleKindId)
        quantity = try c.decodeIfPresent(Int.self, forKey: .quantity) ?? 0
    }
}

struct EventFormResponderRow: Decodable, Sendable {
    var id: String
    var responderId: String
    var startedAt: String?
    var endedAt: String?
    var totalKm: Double?
    var emergencyMeans: Bool
    var status: ParticipationStatus
    var treated: [EventFormTreatedRow]

    enum CodingKeys: String, CodingKey {
        case id
        case responderId = "responder_id"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case totalKm = "total_km"
        case emergencyMeans = "emergency_means"
        case status
        case treated
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        responderId = try c.decode(String.self, forKey: .responderId)
        startedAt = try c.decodeIfPresent(String.self, forKey: .startedAt)
        endedAt = try c.decodeIfPresent(String.self, forKey: .endedAt)
        if let value = try? c.decodeIfPresent(Double.self, forKey: .totalKm) {
            totalKm = value
        } else if let value = try? c.decodeIfPresent(Int.self, forKey: .totalKm) {
            totalKm = Double(value)
        } else if let value = try? c.decodeIfPresent(String.self, forKey: .totalKm) {
            totalKm = Double(value)
        } else {
            totalKm = nil
        }
        emergencyMeans = try c.decodeIfPresent(Bool.self, forKey: .emergencyMeans) ?? false
        status = try c.decodeIfPresent(ParticipationStatus.self, forKey: .status) ?? .pending
        treated = try c.decodeIfPresent([EventFormTreatedRow].self, forKey: .treated) ?? []
    }

    func toDraft(hasVehicle: Bool) -> EventResponderDraft {
        EventResponderDraft(
            responderId: responderId,
            assignmentId: id,
            startTime: toTimeInput(startedAt),
            endTime: toTimeInput(endedAt),
            totalKm: totalKm.map { formatNumber($0) } ?? "",
            emergencyMeans: emergencyMeans,
            treated: treated.map { TreatedVehicleDraft(vehicleKindId: $0.vehicleKindId, quantity: $0.quantity) },
            status: status,
            hasVehicle: hasVehicle
        )
    }
}

struct EventFormDetail: Decodable, Sendable {
    var id: String
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
    var shiftLeadId: String?
    var shiftLead: PersonName?
    var secondaryLeads: [EventSecondaryLeadRow]
    var status: EventStatus
    var responders: [EventFormResponderRow]

    enum CodingKeys: String, CodingKey {
        case id
        case eventDate = "event_date"
        case policeEventId = "police_event_id"
        case districtId = "district_id"
        case patrolCallsign = "patrol_callsign"
        case eventTypeId = "event_type_id"
        case roadId = "road_id"
        case location
        case station
        case notes
        case isCancelled = "is_cancelled"
        case busLane = "bus_lane"
        case shiftLeadId = "shift_lead_id"
        case shiftLead = "shift_lead"
        case secondaryLeads = "secondary_leads"
        case status
        case responders
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        eventDate = try c.decode(String.self, forKey: .eventDate)
        policeEventId = try c.decodeIfPresent(String.self, forKey: .policeEventId)
        districtId = try c.decodeIfPresent(String.self, forKey: .districtId)
        patrolCallsign = try c.decodeIfPresent(String.self, forKey: .patrolCallsign)
        eventTypeId = try c.decodeIfPresent(String.self, forKey: .eventTypeId)
        roadId = try c.decodeIfPresent(String.self, forKey: .roadId)
        location = try c.decodeIfPresent(String.self, forKey: .location)
        station = try c.decodeIfPresent(String.self, forKey: .station)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        isCancelled = try c.decodeIfPresent(Bool.self, forKey: .isCancelled) ?? false
        busLane = try c.decodeIfPresent(Bool.self, forKey: .busLane) ?? false
        shiftLeadId = try c.decodeIfPresent(String.self, forKey: .shiftLeadId)
        if let value = try? c.decode(PersonName.self, forKey: .shiftLead) {
            shiftLead = value
        } else {
            shiftLead = (try? c.decode([PersonName].self, forKey: .shiftLead))?.first
        }
        secondaryLeads = try c.decodeIfPresent([EventSecondaryLeadRow].self, forKey: .secondaryLeads) ?? []
        status = try c.decodeIfPresent(EventStatus.self, forKey: .status) ?? .draft
        responders = try c.decodeIfPresent([EventFormResponderRow].self, forKey: .responders) ?? []
    }

    func toDraft(vehicleOwnerIds: Set<String>) -> EventDraft {
        EventDraft(
            eventDate: returnDateToInput(eventDate),
            policeEventId: policeEventId ?? "",
            patrolCallsign: patrolCallsign ?? "",
            eventTypeId: eventTypeId ?? "",
            roadId: roadId ?? "",
            districtId: districtId ?? "",
            location: location ?? "",
            station: station ?? "",
            notes: notes ?? "",
            responders: responders.map { $0.toDraft(hasVehicle: vehicleOwnerIds.contains($0.responderId)) },
            isCancelled: isCancelled,
            busLane: busLane,
            shiftLeadId: shiftLeadId ?? "",
            secondaryLeads: secondaryLeads.map { $0.asDomain() }
        )
    }
}

struct TreatedVehicleKindRow: Decodable, Sendable {
    var quantity: Int?
    var kind: Named?

    enum CodingKeys: String, CodingKey {
        case quantity, kind
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let value = try? c.decodeIfPresent(Int.self, forKey: .quantity) {
            quantity = value
        } else if let value = try? c.decodeIfPresent(Double.self, forKey: .quantity) {
            quantity = Int(value)
        } else {
            quantity = nil
        }
        if let value = try? c.decode(Named.self, forKey: .kind) {
            kind = value
        } else {
            kind = (try? c.decode([Named].self, forKey: .kind))?.first
        }
    }
}

struct UnitEventDetailResponderRow: Decodable, Identifiable, Sendable {
    var id: String
    var responderId: String
    var startedAt: String?
    var endedAt: String?
    var vehiclePlate: String?
    var odometerStart: Double?
    var odometerEnd: Double?
    var totalKm: Double?
    var route: String?
    var treatmentDetail: String?
    var treatmentNotes: String?
    var emergencyMeans: Bool
    var status: ParticipationStatus
    var profile: PersonName?
    var treated: [TreatedVehicleKindRow]
    var treatedPlates: [EventTreatedPlateRow]

    enum CodingKeys: String, CodingKey {
        case id
        case responderId = "responder_id"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case vehiclePlate = "vehicle_plate"
        case odometerStart = "odometer_start"
        case odometerEnd = "odometer_end"
        case totalKm = "total_km"
        case route
        case treatmentDetail = "treatment_detail"
        case treatmentNotes = "treatment_notes"
        case emergencyMeans = "emergency_means"
        case status
        case profile
        case treated
        case treatedPlates = "treated_plates"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        responderId = try c.decode(String.self, forKey: .responderId)
        startedAt = try c.decodeIfPresent(String.self, forKey: .startedAt)
        endedAt = try c.decodeIfPresent(String.self, forKey: .endedAt)
        vehiclePlate = try c.decodeIfPresent(String.self, forKey: .vehiclePlate)
        odometerStart = Self.number(c, .odometerStart)
        odometerEnd = Self.number(c, .odometerEnd)
        totalKm = Self.number(c, .totalKm)
        route = try c.decodeIfPresent(String.self, forKey: .route)
        treatmentDetail = try c.decodeIfPresent(String.self, forKey: .treatmentDetail)
        treatmentNotes = try c.decodeIfPresent(String.self, forKey: .treatmentNotes)
        emergencyMeans = try c.decodeIfPresent(Bool.self, forKey: .emergencyMeans) ?? false
        status = try c.decodeIfPresent(ParticipationStatus.self, forKey: .status) ?? .pending
        if let value = try? c.decode(PersonName.self, forKey: .profile) {
            profile = value
        } else {
            profile = (try? c.decode([PersonName].self, forKey: .profile))?.first
        }
        treated = try c.decodeIfPresent([TreatedVehicleKindRow].self, forKey: .treated) ?? []
        treatedPlates = try c.decodeIfPresent([EventTreatedPlateRow].self, forKey: .treatedPlates) ?? []
    }

    private static func number(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Double? {
        if let value = try? c.decodeIfPresent(Double.self, forKey: key) { return value }
        if let value = try? c.decodeIfPresent(Int.self, forKey: key) { return Double(value) }
        if let value = try? c.decodeIfPresent(String.self, forKey: key) { return Double(value) }
        return nil
    }
}

struct UnitEventDetailRespondersWrap: Decodable {
    var responders: [UnitEventDetailResponderRow]
}

struct SameDayPoliceEventApiRow: Decodable, Sendable {
    var id: String
    var shiftLeadId: String?
    var isCancelled: Bool
    var policeEventId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case shiftLeadId = "shift_lead_id"
        case isCancelled = "is_cancelled"
        case policeEventId = "police_event_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        shiftLeadId = try c.decodeIfPresent(String.self, forKey: .shiftLeadId)
        isCancelled = try c.decodeIfPresent(Bool.self, forKey: .isCancelled) ?? false
        policeEventId = try c.decodeIfPresent(String.self, forKey: .policeEventId)
    }
}

struct EventOwnerRow: Decodable, Sendable {
    var id: String
    var shiftLeadId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case shiftLeadId = "shift_lead_id"
    }
}

private func decodeNested<T: Decodable, K: CodingKey>(
    _ type: T.Type,
    from c: KeyedDecodingContainer<K>,
    key: K
) -> T? {
    if let value = try? c.decode(T.self, forKey: key) { return value }
    if let values = try? c.decode([T].self, forKey: key) { return values.first }
    return nil
}

private func decodeJSONDouble<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> Double? {
    if let value = try? c.decodeIfPresent(Double.self, forKey: key) { return value }
    if let value = try? c.decodeIfPresent(Int.self, forKey: key) { return Double(value) }
    if let value = try? c.decodeIfPresent(String.self, forKey: key) { return Double(value) }
    return nil
}

struct ReportResponderRow: Decodable, Sendable {
    var responderId: String
    var totalKm: Double?
    var profile: PersonName?

    enum CodingKeys: String, CodingKey {
        case responderId = "responder_id"
        case totalKm = "total_km"
        case profile
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        responderId = try c.decodeIfPresent(String.self, forKey: .responderId) ?? ""
        totalKm = decodeJSONDouble(c, .totalKm)
        profile = decodeNested(PersonName.self, from: c, key: .profile)
    }
}

/// One select serves both the by-responder and the km-exception reports.
struct ReportEventRow: Decodable, Sendable {
    var id: String
    var eventDate: String
    var isCancelled: Bool
    var policeEventId: String?
    var location: String?
    var eventType: Named?
    var district: Named?
    var road: Named?
    var shiftLead: PersonName?
    var responders: [ReportResponderRow]

    enum CodingKeys: String, CodingKey {
        case id
        case eventDate = "event_date"
        case isCancelled = "is_cancelled"
        case policeEventId = "police_event_id"
        case location
        case eventType = "event_type"
        case district
        case road
        case shiftLead = "shift_lead"
        case responders
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        eventDate = try c.decode(String.self, forKey: .eventDate)
        isCancelled = try c.decodeIfPresent(Bool.self, forKey: .isCancelled) ?? false
        policeEventId = try c.decodeIfPresent(String.self, forKey: .policeEventId)
        location = try c.decodeIfPresent(String.self, forKey: .location)
        eventType = decodeNested(Named.self, from: c, key: .eventType)
        district = decodeNested(Named.self, from: c, key: .district)
        road = decodeNested(Named.self, from: c, key: .road)
        shiftLead = decodeNested(PersonName.self, from: c, key: .shiftLead)
        responders = try c.decodeIfPresent([ReportResponderRow].self, forKey: .responders) ?? []
    }

    var asEventsByResponderInput: EventsByResponderEventInput {
        EventsByResponderEventInput(
            id: id,
            eventDate: eventDate,
            isCancelled: isCancelled,
            policeEventId: policeEventId,
            location: location,
            eventTypeName: eventType?.name,
            districtName: district?.name,
            roadName: road?.name,
            leadName: shiftLead?.fullName,
            leadCallsign: shiftLead?.callsign,
            responders: responders.map { row in
                EventsByResponderResponderInput(
                    responderId: row.responderId,
                    totalKm: row.totalKm,
                    name: row.profile?.fullName,
                    callsign: row.profile?.callsign
                )
            }
        )
    }

    var asKmExceptionInput: KmExceptionEventInput {
        KmExceptionEventInput(
            id: id,
            eventDate: eventDate,
            isCancelled: isCancelled,
            policeEventId: policeEventId,
            location: location,
            eventTypeName: eventType?.name,
            roadName: road?.name,
            leadName: shiftLead?.fullName,
            leadCallsign: shiftLead?.callsign,
            responders: responders.map { row in
                KmExceptionResponderInput(
                    totalKm: row.totalKm,
                    name: row.profile?.fullName,
                    callsign: row.profile?.callsign
                )
            }
        )
    }
}

struct KmDiscrepancyResponderRow: Decodable, Sendable {
    var id: String
    var status: ParticipationStatus
    var totalKm: Double?
    var odometerStart: Double?
    var odometerEnd: Double?
    var profile: PersonName?

    enum CodingKeys: String, CodingKey {
        case id
        case status
        case totalKm = "total_km"
        case odometerStart = "odometer_start"
        case odometerEnd = "odometer_end"
        case profile
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        status = try c.decode(ParticipationStatus.self, forKey: .status)
        totalKm = decodeJSONDouble(c, .totalKm)
        odometerStart = decodeJSONDouble(c, .odometerStart)
        odometerEnd = decodeJSONDouble(c, .odometerEnd)
        profile = decodeNested(PersonName.self, from: c, key: .profile)
    }
}

struct KmDiscrepancyEventRow: Decodable, Sendable {
    var id: String
    var eventDate: String
    var isCancelled: Bool
    var policeEventId: String?
    var location: String?
    var road: Named?
    var shiftLead: PersonName?
    var responders: [KmDiscrepancyResponderRow]

    enum CodingKeys: String, CodingKey {
        case id
        case eventDate = "event_date"
        case isCancelled = "is_cancelled"
        case policeEventId = "police_event_id"
        case location
        case road
        case shiftLead = "shift_lead"
        case responders
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        eventDate = try c.decode(String.self, forKey: .eventDate)
        isCancelled = try c.decodeIfPresent(Bool.self, forKey: .isCancelled) ?? false
        policeEventId = try c.decodeIfPresent(String.self, forKey: .policeEventId)
        location = try c.decodeIfPresent(String.self, forKey: .location)
        road = decodeNested(Named.self, from: c, key: .road)
        shiftLead = decodeNested(PersonName.self, from: c, key: .shiftLead)
        responders = try c.decodeIfPresent([KmDiscrepancyResponderRow].self, forKey: .responders) ?? []
    }

    var asInput: KmDiscrepancyEventInput {
        KmDiscrepancyEventInput(
            id: id,
            eventDate: eventDate,
            isCancelled: isCancelled,
            policeEventId: policeEventId,
            location: location,
            roadName: road?.name,
            leadName: shiftLead?.fullName,
            leadCallsign: shiftLead?.callsign,
            responders: responders.map { row in
                KmDiscrepancyResponderInput(
                    assignmentId: row.id,
                    status: row.status,
                    totalKm: row.totalKm,
                    odometerStart: row.odometerStart,
                    odometerEnd: row.odometerEnd,
                    name: row.profile?.fullName,
                    callsign: row.profile?.callsign
                )
            }
        )
    }
}

struct LeadKmRow: Decodable, Sendable {
    var id: String
    var totalKm: Double?
    var odometerStart: Double?
    var odometerEnd: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case totalKm = "total_km"
        case odometerStart = "odometer_start"
        case odometerEnd = "odometer_end"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        totalKm = decodeJSONDouble(c, .totalKm)
        odometerStart = decodeJSONDouble(c, .odometerStart)
        odometerEnd = decodeJSONDouble(c, .odometerEnd)
    }
}

struct DuplicateResponderRow: Decodable, Sendable {
    var responderId: String
    var startedAt: String?
    var profile: PersonName?

    enum CodingKeys: String, CodingKey {
        case responderId = "responder_id"
        case startedAt = "started_at"
        case profile
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        responderId = try c.decode(String.self, forKey: .responderId)
        startedAt = try c.decodeIfPresent(String.self, forKey: .startedAt)
        profile = decodeNested(PersonName.self, from: c, key: .profile)
    }
}

struct DuplicateEventRow: Decodable, Sendable {
    var id: String
    var eventDate: String
    var isCancelled: Bool
    var policeEventId: String?
    var location: String?
    var eventType: Named?
    var road: Named?
    var responders: [DuplicateResponderRow]

    enum CodingKeys: String, CodingKey {
        case id
        case eventDate = "event_date"
        case isCancelled = "is_cancelled"
        case policeEventId = "police_event_id"
        case location
        case eventType = "event_type"
        case road
        case responders
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        eventDate = try c.decode(String.self, forKey: .eventDate)
        isCancelled = try c.decodeIfPresent(Bool.self, forKey: .isCancelled) ?? false
        policeEventId = try c.decodeIfPresent(String.self, forKey: .policeEventId)
        location = try c.decodeIfPresent(String.self, forKey: .location)
        eventType = decodeNested(Named.self, from: c, key: .eventType)
        road = decodeNested(Named.self, from: c, key: .road)
        responders = try c.decodeIfPresent([DuplicateResponderRow].self, forKey: .responders) ?? []
    }

    var asParticipations: [DuplicateParticipation] {
        responders.map { row in
            DuplicateParticipation(
                eventId: id,
                responderId: row.responderId,
                eventDate: eventDate,
                location: location,
                startedAt: row.startedAt,
                isCancelled: isCancelled,
                policeEventId: policeEventId,
                eventTypeName: eventType?.name,
                roadName: road?.name,
                name: row.profile?.fullName,
                callsign: row.profile?.callsign
            )
        }
    }
}

struct OpenDocResponderRow: Decodable, Sendable {
    var responderId: String
    var status: ParticipationStatus
    var profile: PersonName?

    enum CodingKeys: String, CodingKey {
        case responderId = "responder_id"
        case status
        case profile
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        responderId = try c.decode(String.self, forKey: .responderId)
        status = try c.decode(ParticipationStatus.self, forKey: .status)
        profile = decodeNested(PersonName.self, from: c, key: .profile)
    }
}

struct OpenDocEventRow: Decodable, Sendable {
    var id: String
    var eventDate: String
    var status: EventStatus
    var isCancelled: Bool
    var policeEventId: String?
    var location: String?
    var shiftLeadId: String?
    var road: Named?
    var shiftLead: PersonName?
    var responders: [OpenDocResponderRow]

    enum CodingKeys: String, CodingKey {
        case id
        case eventDate = "event_date"
        case status
        case isCancelled = "is_cancelled"
        case policeEventId = "police_event_id"
        case location
        case shiftLeadId = "shift_lead_id"
        case road
        case shiftLead = "shift_lead"
        case responders
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        eventDate = try c.decode(String.self, forKey: .eventDate)
        status = try c.decode(EventStatus.self, forKey: .status)
        isCancelled = try c.decodeIfPresent(Bool.self, forKey: .isCancelled) ?? false
        policeEventId = try c.decodeIfPresent(String.self, forKey: .policeEventId)
        location = try c.decodeIfPresent(String.self, forKey: .location)
        shiftLeadId = try c.decodeIfPresent(String.self, forKey: .shiftLeadId)
        road = decodeNested(Named.self, from: c, key: .road)
        shiftLead = decodeNested(PersonName.self, from: c, key: .shiftLead)
        responders = try c.decodeIfPresent([OpenDocResponderRow].self, forKey: .responders) ?? []
    }

    var asInput: OpenDocEventInput {
        OpenDocEventInput(
            id: id,
            eventDate: eventDate,
            status: status,
            isCancelled: isCancelled,
            policeEventId: policeEventId,
            location: location,
            roadName: road?.name,
            shiftLeadId: shiftLeadId,
            leadName: shiftLead?.fullName,
            leadCallsign: shiftLead?.callsign,
            responders: responders.map { row in
                OpenDocResponderInput(
                    responderId: row.responderId,
                    status: row.status,
                    name: row.profile?.fullName,
                    callsign: row.profile?.callsign
                )
            }
        )
    }
}

struct FuelParticipationRow: Decodable, Sendable {
    var responderId: String
    var eventId: String
    var totalKm: Double?

    enum CodingKeys: String, CodingKey {
        case responderId = "responder_id"
        case eventId = "event_id"
        case totalKm = "total_km"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        responderId = try c.decodeIfPresent(String.self, forKey: .responderId) ?? ""
        eventId = try c.decodeIfPresent(String.self, forKey: .eventId) ?? ""
        totalKm = decodeJSONDouble(c, .totalKm)
    }
}

struct FuelEventFreezeRow: Decodable, Sendable {
    var id: String
    var frozenOver60km: Bool
    var frozenSuspiciousDuplicate: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case frozenOver60km = "frozen_over_60km"
        case frozenSuspiciousDuplicate = "frozen_suspicious_duplicate"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        frozenOver60km = try c.decodeIfPresent(Bool.self, forKey: .frozenOver60km) ?? false
        frozenSuspiciousDuplicate = try c.decodeIfPresent(Bool.self, forKey: .frozenSuspiciousDuplicate) ?? false
    }

    var isFrozen: Bool {
        EventFreezeFlags(
            frozenOver60km: frozenOver60km,
            frozenSuspiciousDuplicate: frozenSuspiciousDuplicate
        ).isFrozen
    }
}

struct VehicleOwner: Decodable, Sendable {
    var userId: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
    }
}

struct FuelShiftRow: Decodable, Sendable {
    var totalKm: Double?
    var vehicles: VehicleOwner?

    enum CodingKeys: String, CodingKey {
        case totalKm = "total_km"
        case vehicles
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        totalKm = decodeJSONDouble(c, .totalKm)
        vehicles = decodeNested(VehicleOwner.self, from: c, key: .vehicles)
    }
}

struct AdminProfileRow: Decodable, Sendable {
    var id: String
    var fullName: String
    var email: String
    var callsign: String
    var phone: String?
    var active: Bool
    var invitePending: Bool
    var otpLoginEnabled: Bool
    var otpUsersPageEnabled: Bool
    var availability: AvailabilityStatus
    var availableFrom: String?
    var volunteerStatus: String?

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case email
        case callsign
        case phone
        case active
        case invitePending = "invite_pending"
        case otpLoginEnabled = "otp_login_enabled"
        case otpUsersPageEnabled = "otp_users_page_enabled"
        case availability
        case availableFrom = "available_from"
        case volunteerStatus = "volunteer_status"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        fullName = try c.decodeIfPresent(String.self, forKey: .fullName) ?? ""
        email = try c.decodeIfPresent(String.self, forKey: .email) ?? ""
        callsign = try c.decodeIfPresent(String.self, forKey: .callsign) ?? ""
        phone = try c.decodeIfPresent(String.self, forKey: .phone)
        active = try c.decodeIfPresent(Bool.self, forKey: .active) ?? true
        invitePending = try c.decodeIfPresent(Bool.self, forKey: .invitePending) ?? false
        otpLoginEnabled = try c.decodeIfPresent(Bool.self, forKey: .otpLoginEnabled) ?? false
        otpUsersPageEnabled = try c.decodeIfPresent(Bool.self, forKey: .otpUsersPageEnabled) ?? false
        if let raw = try c.decodeIfPresent(String.self, forKey: .availability),
           let parsed = AvailabilityStatus(rawValue: raw)
        {
            availability = parsed
        } else {
            availability = .available
        }
        availableFrom = try c.decodeIfPresent(String.self, forKey: .availableFrom)
        volunteerStatus = try c.decodeIfPresent(String.self, forKey: .volunteerStatus)
    }
}

struct AdminUserRoleRow: Decodable, Sendable {
    var userId: String
    var role: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case role
    }
}

struct AdminAddressRow: Decodable, Sendable {
    var userId: String
    var kind: String
    var label: String?
    var formattedAddress: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case kind
        case label
        case formattedAddress = "formatted_address"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userId = try c.decode(String.self, forKey: .userId)
        kind = try c.decodeIfPresent(String.self, forKey: .kind) ?? ""
        label = try c.decodeIfPresent(String.self, forKey: .label)
        formattedAddress = try c.decodeIfPresent(String.self, forKey: .formattedAddress) ?? ""
    }
}

struct AdminVehicleItem: Hashable, Identifiable, Sendable {
    var id: String
    var plateNumber: String
    var model: String
    var archived: Bool
}

struct AdminAddressItem: Hashable, Sendable {
    var kind: String
    var label: String?
    var formattedAddress: String
}

struct AdminUserListItem: Identifiable, Hashable, Sendable {
    var id: String
    var fullName: String
    var email: String
    var callsign: String
    var phone: String?
    var active: Bool
    var invitePending: Bool
    var otpLoginEnabled: Bool
    var otpUsersPageEnabled: Bool
    var availability: AvailabilityStatus
    var availableFrom: String?
    var volunteerStatus: String?
    var roles: [String]
    var vehicles: [AdminVehicleItem]
    var addresses: [AdminAddressItem]

    var vehicleCount: Int { vehicles.filter { !$0.archived }.count }

    var searchInput: AdminUserSearchInput {
        AdminUserSearchInput(
            fullName: fullName,
            callsign: callsign,
            email: email,
            volunteerStatus: volunteerStatus,
            availability: availability,
            availableFrom: availableFrom,
            active: active,
            invitePending: invitePending
        )
    }

    var sortKey: AdminUserSortKey {
        AdminUserSortKey(fullName: fullName, active: active, invitePending: invitePending)
    }
}

struct AdminUsersActionResult: Sendable {
    var error: String?
    var message: String?
    var userId: String?
    var actionLink: String?

    var ok: Bool { error == nil }
}

struct FeedbackAttachmentUpload: Sendable {
    var name: String
    var mime: String
    var bytes: Data
}

struct ImpersonationTargetSummary: Decodable, Sendable {
    var id: String
    var fullName: String
    var callsign: String

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case callsign
    }
}

struct AdminUsersResponse: Decodable, Sendable {
    var ok: Bool?
    var error: String?
    var message: String?
    var userId: String?
    var actionLink: String?
    var accessToken: String?
    var refreshToken: String?
    var target: ImpersonationTargetSummary?

    enum CodingKeys: String, CodingKey {
        case ok
        case error
        case message
        case userId = "user_id"
        case actionLink = "action_link"
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case target
    }
}

struct PhoneOtpResponse: Decodable, Sendable {
    var error: String?
    var message: String?
}
