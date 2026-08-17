import Foundation

public enum AvailabilityStatus: String, Codable, Hashable, Sendable {
    case available
    case unavailable
}

public let AVAILABILITY_LABELS: [AvailabilityStatus: String] = [
    .available: "זמין",
    .unavailable: "לא זמין",
]

public let AVAILABILITY_DATE_ERROR = "בחרו תאריך מהמחר או השאירו ריק."

public func availabilityLabel(_ status: AvailabilityStatus) -> String {
    AVAILABILITY_LABELS[status] ?? AVAILABILITY_LABELS[.available]!
}

public func israelToday(_ now: Date = Date()) -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_CA")
    formatter.timeZone = TimeZone(identifier: "Asia/Jerusalem")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: now)
}

public func effectiveAvailability(
    _ status: AvailabilityStatus,
    availableFrom: String?,
    today: String
) -> AvailabilityStatus {
    if status == .available { return .available }
    if let availableFrom, availableFrom <= today { return .available }
    return .unavailable
}

public func availabilityReturnCaption(_ availableFrom: String?) -> String? {
    guard let availableFrom, !availableFrom.isEmpty else { return nil }
    return "חזרה ב־\(formatDate(availableFrom))"
}

public enum AvailabilityWrite: Equatable, Sendable {
    case ok(availability: AvailabilityStatus, availableFrom: String?)
    case error(String)
}

public func buildAvailabilityWrite(
    status: AvailabilityStatus,
    availableFrom: String?,
    today: String
) -> AvailabilityWrite {
    if status == .available {
        return .ok(availability: .available, availableFrom: nil)
    }
    let date = availableFrom?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if date.isEmpty {
        return .ok(availability: .unavailable, availableFrom: nil)
    }
    if !isValidReturnDate(date, today: today) {
        return .error(AVAILABILITY_DATE_ERROR)
    }
    return .ok(availability: .unavailable, availableFrom: date)
}

public func isValidReturnDate(_ availableFrom: String, today: String) -> Bool {
    availableFrom.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil
        && availableFrom > today
}

public func tomorrowJerusalem(today: String = israelToday()) -> String {
    addCalendarDays(ymd: today, days: 1)
}
