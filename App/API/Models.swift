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

struct ResponderSummary: Decodable, Hashable, Sendable, Identifiable {
    var id: String
    var responderId: String
    var status: ParticipationStatus

    enum CodingKeys: String, CodingKey {
        case id
        case responderId = "responder_id"
        case status
    }
}

struct EventListItem: Decodable, Hashable, Identifiable, Sendable {
    var id: String
    var eventDate: String
    var policeEventId: String?
    var location: String?
    var status: EventStatus
    var isCancelled: Bool
    var origin: String?
    var shiftId: String?
    var eventType: Named?
    var road: Named?
    var shiftLead: PersonName?
    var shift: ShiftSummary?
    var responders: [ResponderSummary]

    enum CodingKeys: String, CodingKey {
        case id
        case eventDate = "event_date"
        case policeEventId = "police_event_id"
        case location
        case status
        case isCancelled = "is_cancelled"
        case origin
        case shiftId = "shift_id"
        case eventType = "event_type"
        case road
        case shiftLead = "shift_lead"
        case shift
        case responders
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        eventDate = try c.decode(String.self, forKey: .eventDate)
        policeEventId = try c.decodeIfPresent(String.self, forKey: .policeEventId)
        location = try c.decodeIfPresent(String.self, forKey: .location)
        status = try c.decode(EventStatus.self, forKey: .status)
        isCancelled = try c.decodeIfPresent(Bool.self, forKey: .isCancelled) ?? false
        origin = try c.decodeIfPresent(String.self, forKey: .origin)
        shiftId = try c.decodeIfPresent(String.self, forKey: .shiftId)
        eventType = Self.decodeOne(Named.self, from: c, key: .eventType)
        road = Self.decodeOne(Named.self, from: c, key: .road)
        shiftLead = Self.decodeOne(PersonName.self, from: c, key: .shiftLead)
        shift = Self.decodeOne(ShiftSummary.self, from: c, key: .shift)
        responders = try c.decodeIfPresent([ResponderSummary].self, forKey: .responders) ?? []
    }

    func ownParticipation(userId: String) -> ParticipationStatus? {
        responders.first(where: { $0.responderId == userId })?.status
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
    var plateNumber: String
    var model: String?
    var archived: Bool?

    var id: String { plateDigits(plateNumber) }

    enum CodingKeys: String, CodingKey {
        case plateNumber = "plate_number"
        case model
        case archived
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

struct RoleRow: Decodable, Sendable {
    var role: String
}

struct AssignmentIdRow: Decodable, Sendable {
    var eventId: String
    enum CodingKeys: String, CodingKey { case eventId = "event_id" }
}

struct IdRow: Decodable, Sendable {
    var id: String
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
