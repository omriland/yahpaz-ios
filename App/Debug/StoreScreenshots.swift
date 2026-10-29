#if DEBUG
import Foundation
import YahpazDomain

/// Demo data for App Store screenshots, DEBUG builds only. Launch with `-StoreScreenshots`
/// (add `-StoreSignedOut` for the login screen). In this mode the Supabase client points at a
/// dead local port, so nothing reaches production; the volunteer screens read from here.
enum StoreScreenshots {
    static let isOn = ProcessInfo.processInfo.arguments.contains("-StoreScreenshots")
    static let signedOut = ProcessInfo.processInfo.arguments.contains("-StoreSignedOut")
    static let supabaseURL = URL(string: "http://127.0.0.1:9")!

    static let userId = "00000000-0000-4000-8000-0000000000d1"
    static let pendingEventId = id(4127)

    static var profile: (ProfileRecord, [String]) {
        (decode([
            "id": userId,
            "full_name": "כונן דמו",
            "email": "demo@example.com",
            "callsign": "דמו 7",
            "phone": "0500000000",
            "availability": "available",
            "lifetime_event_count": 42,
            "lifetime_km": 1380,
        ]), ["responder"])
    }

    static var myEvents: [EventListItem] {
        let today = israelToday()
        return decode([
            event(pendingEventId, date: today, police: "4127", type: "רכב תקוע", road: "כביש 1",
                  location: "מחלף דמו", status: "in_progress", mine: "in_progress"),
            event(id(2), date: addCalendarDays(ymd: today, days: -1), police: "4093", type: "פינוי מכשול",
                  road: "כביש 20", location: "צומת דמו", status: "in_progress", mine: "pending"),
            event(id(3), date: addCalendarDays(ymd: today, days: -3), police: "4011", type: "רכב תקוע",
                  road: "כביש 4", location: "גשר דמו", status: "done", mine: "done", km: 26),
            event(id(4), date: addCalendarDays(ymd: today, days: -6), police: "3988", type: "פינוי מכשול",
                  road: "כביש 2", location: "מחלף דמו צפון", status: "done", mine: "done", km: 41),
            event(id(5), date: addCalendarDays(ymd: today, days: -11), police: "3920", type: "רכב תקוע",
                  road: "כביש 5", location: "יציאת דמו", status: "done", mine: "done", km: 18),
        ])
    }

    static var myShifts: [ShiftListItem] {
        let today = israelToday()
        return decode([
            shift(id(11), date: today, kind: "morning", status: "in_progress"),
            shift(id(12), date: addCalendarDays(ymd: today, days: 2), kind: "midday", status: "draft"),
            shift(id(13), date: addCalendarDays(ymd: today, days: -4), kind: "morning", status: "closed",
                  odometer: (48_010, 48_092)),
            shift(id(14), date: addCalendarDays(ymd: today, days: -9), kind: "reinforcement", status: "closed",
                  odometer: (47_702, 47_768)),
        ])
    }

    static var myVehicles: [ProfileVehicle] {
        managedProfileVehicles([
            // A neutral model keeps manufacturer logos out of store screenshots.
            VehicleRowInput(plateRaw: "1234567", modelRaw: "רכב דמו", archived: false, id: id(21), isDefault: true),
        ])
    }

    static var contacts: [UnitContact] {
        let names = ["אחמ״ש דמו", "כונן דמו", "כוננת דמו א", "כונן דמו ב", "כוננת דמו ג", "כונן דמו ד"]
        return decode(names.enumerated().map { index, name in
            [
                "id": id(30 + index),
                "full_name": name,
                "callsign": "דמו \(index + 1)",
                "phone": "050000000\(index)",
                "email": "demo\(index + 1)@example.com",
            ]
        })
    }

    static func fillContext(eventId: String) -> FillContext? {
        guard eventId == pendingEventId else { return nil }
        return FillContext(
            eventId: eventId,
            assignmentId: "\(eventId)-r",
            eventStatus: .inProgress,
            eventDate: israelToday(),
            policeEventId: "4127",
            eventTypeName: "רכב תקוע",
            isCancelled: false,
            roadName: "כביש 1",
            location: "מחלף דמו",
            shiftLeadName: "אחמ״ש דמו · דמו 1",
            totalKm: nil,
            participationStatus: .inProgress,
            updatedAt: nil,
            draft: ResponderFillDraft(
                vehiclePlate: "1234567",
                odometerStart: "48210",
                odometerEnd: "48236",
                route: "בסיס דמו - מחלף דמו - בסיס דמו",
                treatedPlates: [TreatedPlate(plateNumber: "7654321", model: "רכב דמו", color: "לבן")]
            ),
            vehicles: [ResponderVehicle(plate: "1234567", model: "רכב דמו")],
            endedAt: nil
        )
    }

    /// Demo members spread over Gush Dan; no real addresses.
    static var unitMapPins: [MapPin] {
        let spots: [(Double, Double)] = [
            (32.0853, 34.7818), (32.0684, 34.7949), (32.1093, 34.8555), (32.0158, 34.7874),
            (32.0809, 34.8338), (32.1663, 34.8436), (31.9730, 34.7925), (32.0461, 34.8516),
        ]
        return mapPinsFromUnitRows(spots.enumerated().map { index, spot in
            UnitMapPinRow(
                userId: id(40 + index),
                fullName: "כונן דמו \(index + 1)",
                callsign: "דמו \(index + 1)",
                kind: index.isMultiple(of: 3) ? .work : .home,
                label: nil,
                formattedAddress: "רחוב הדמו \(index + 1), שלוחה תל אביב",
                lat: spot.0,
                lng: spot.1,
                volunteerStatus: .activeVolunteer,
                availability: index == 2 ? .unavailable : .available,
                availableFrom: nil
            )
        })
    }

    private static func id(_ n: Int) -> String {
        String(format: "00000000-0000-4000-8000-%012d", n)
    }

    private static var shiftLead: [String: Any] {
        ["full_name": "אחמ״ש דמו", "callsign": "דמו 1"]
    }

    private static func event(
        _ id: String,
        date: String,
        police: String,
        type: String,
        road: String,
        location: String,
        status: String,
        mine: String,
        km: Double? = nil
    ) -> [String: Any] {
        var responder: [String: Any] = ["id": "\(id)-r", "responder_id": userId, "status": mine]
        if let km { responder["total_km"] = km }
        return [
            "id": id,
            "event_date": date,
            "police_event_id": police,
            "patrol_callsign_prefix": "אביב",
            "patrol_callsign_number": "511",
            "started_at": "\(date)T07:40:00+03:00",
            "ended_at": status == "done" ? "\(date)T08:55:00+03:00" : NSNull(),
            "location": location,
            "status": status,
            "origin": "manual",
            "district": ["name": "תל אביב"],
            "event_type": ["name": type],
            "road": ["name": road],
            "shift_lead": shiftLead,
            "responders": [responder],
        ]
    }

    private static func shift(
        _ id: String,
        date: String,
        kind: String,
        status: String,
        odometer: (Double, Double)? = nil
    ) -> [String: Any] {
        var row: [String: Any] = [
            "id": id,
            "shift_date": date,
            "shift_kind": kind,
            "vehicle_type": "patrol_center",
            "status": status,
            "shift_lead": shiftLead,
            "responders": [["id": "\(id)-r", "responder_id": userId]],
        ]
        if let odometer {
            row["odometer_start"] = odometer.0
            row["odometer_end"] = odometer.1
        }
        return row
    }

    /// Runs fixtures through the same decoders as server rows.
    private static func decode<T: Decodable>(_ object: Any) -> T {
        let data = try! JSONSerialization.data(withJSONObject: object)
        return try! JSONDecoder().decode(T.self, from: data)
    }
}
#endif
