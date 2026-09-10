import Foundation

public enum VolunteerStatus: String, CaseIterable, Sendable, Hashable {
    case administration
    case basicTraining = "basic_training"
    case phoneTraining = "phone_training"
    case personalVehicleTraining = "personal_vehicle_training"
    case shiftsOnly = "shifts_only"
    case activeVolunteer = "active_volunteer"

    public static let `default` = VolunteerStatus.activeVolunteer

    public static func fromRaw(_ raw: String?) -> VolunteerStatus {
        guard let raw, let value = VolunteerStatus(rawValue: raw) else { return .default }
        return value
    }
}

public let VOLUNTEER_STATUS_LABELS: [VolunteerStatus: String] = [
    .administration: "מנהלה",
    .basicTraining: "חניכה בסיסית",
    .phoneTraining: "חניכה טלפונית",
    .personalVehicleTraining: "חניכה ברכב פרטי",
    .shiftsOnly: "משמרות בלבד",
    .activeVolunteer: "מתנדב פעיל",
]

public func volunteerStatusLabel(_ raw: String?) -> String {
    VOLUNTEER_STATUS_LABELS[VolunteerStatus.fromRaw(raw)] ?? VOLUNTEER_STATUS_LABELS[.activeVolunteer]!
}
