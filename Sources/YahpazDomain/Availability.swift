import Foundation

public enum AvailabilityStatus: String, Codable, Hashable, Sendable {
    case available
    case unavailable
}

public let AVAILABILITY_LABELS: [AvailabilityStatus: String] = [
    .available: "זמין",
    .unavailable: "לא זמין",
]

public let AVAILABILITY_DATE_ERROR = "יש לבחור תאריך עתידי"

public func availabilityLabel(_ status: AvailabilityStatus) -> String {
    AVAILABILITY_LABELS[status] ?? AVAILABILITY_LABELS[.available]!
}

public func availabilitySearchLabel(
    _ status: AvailabilityStatus,
    availableFrom: String?,
    today: String
) -> String {
    availabilityLabel(effectiveAvailability(status, availableFrom: availableFrom, today: today))
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
    guard let iso = normalizeReturnDate(date), iso > today else {
        return .error(AVAILABILITY_DATE_ERROR)
    }
    return .ok(availability: .unavailable, availableFrom: iso)
}

public func formatReturnDateInput(_ raw: String) -> String {
    let digits = String(digitsOnly(raw).prefix(8))
    let day = String(digits.prefix(2))
    let month = String(digits.dropFirst(2).prefix(2))
    let year = String(digits.dropFirst(4).prefix(4))
    return [day, month, year].filter { !$0.isEmpty }.joined(separator: "/")
}

public func applyReturnDateKeystroke(previous: String, incoming: String) -> String {
    let previousDigits = digitsOnly(previous)
    var nextDigits = String(digitsOnly(incoming).prefix(8))
    if nextDigits == previousDigits && incoming.count < previous.count && !previousDigits.isEmpty {
        nextDigits = String(previousDigits.dropLast())
    }
    return formatReturnDateInput(nextDigits)
}

public func returnDateToInput(_ stored: String) -> String {
    let trimmed = stored.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return "" }
    let parts = trimmed.split(separator: "-")
    if parts.count == 3,
       parts[0].count == 4,
       parts[1].count == 2,
       parts[2].count == 2,
       parts.allSatisfy({ $0.allSatisfy(\.isNumber) }) {
        return "\(parts[2])/\(parts[1])/\(parts[0])"
    }
    return formatReturnDateInput(trimmed)
}

public func parseReturnDateInput(_ raw: String) -> String? {
    let digits = digitsOnly(raw)
    guard digits.count == 8,
          let day = Int(digits.prefix(2)),
          let month = Int(digits.dropFirst(2).prefix(2)),
          let year = Int(digits.suffix(4)) else { return nil }
    let calendar = Calendar(identifier: .gregorian)
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    guard components.isValidDate(in: calendar) else { return nil }
    return String(format: "%04d-%02d-%02d", year, month, day)
}

public func normalizeReturnDate(_ raw: String) -> String? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil {
        let parts = trimmed.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        guard components.isValidDate(in: Calendar(identifier: .gregorian)) else { return nil }
        return trimmed
    }
    return parseReturnDateInput(trimmed)
}

public func isValidReturnDate(_ availableFrom: String, today: String) -> Bool {
    guard let iso = normalizeReturnDate(availableFrom) else { return false }
    return iso > today
}

public func tomorrowJerusalem(today: String = israelToday()) -> String {
    addCalendarDays(ymd: today, days: 1)
}
