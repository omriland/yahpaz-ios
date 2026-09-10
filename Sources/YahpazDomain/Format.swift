import Foundation

public func digitsOnly(_ value: String) -> String {
    value.filter(\.isNumber)
}

public func plateDigits(_ value: String) -> String {
    digitsOnly(value)
}

public func formatPlate(_ raw: String) -> String {
    let digits = digitsOnly(raw)
    if digits.count == 7 {
        return "\(digits.prefix(2))-\(digits.dropFirst(2).prefix(3))-\(digits.suffix(2))"
    }
    if digits.count == 8 {
        return "\(digits.prefix(3))-\(digits.dropFirst(3).prefix(2))-\(digits.suffix(3))"
    }
    return raw
}

public func plateNumberForSave(_ raw: String?) -> String? {
    let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if trimmed.isEmpty { return nil }
    return formatPlate(trimmed)
}

/// Returns duplicated plate digits, or nil when every non-empty plate is unique.
public func findDuplicatePlate(_ plates: [String]) -> String? {
    var seen = Set<String>()
    for plate in plates {
        let digits = plateDigits(plate)
        if digits.isEmpty { continue }
        if !seen.insert(digits).inserted { return digits }
    }
    return nil
}

public func hebrewWeekdayLetter(_ value: String) -> String {
    let ymd = String(value.prefix(10))
    let parts = ymd.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else { return "" }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    guard let date = calendar.date(from: DateComponents(
        calendar: calendar,
        timeZone: calendar.timeZone,
        year: parts[0],
        month: parts[1],
        day: parts[2]
    )) else { return "" }
    let weekday = calendar.component(.weekday, from: date)
    let letters = ["", "א", "ב", "ג", "ד", "ה", "ו", "ש"]
    guard weekday >= 1, weekday <= 7 else { return "" }
    return letters[weekday]
}

public func formatDate(_ value: String) -> String {
    let ymd = String(value.prefix(10))
    let parts = ymd.split(separator: "-")
    guard parts.count == 3 else { return value }
    return "\(parts[2]).\(parts[1]).\(parts[0])"
}

/// Current clock in Asia/Jerusalem as `HH:mm` (24-hour).
public func nowTimeJerusalem(_ now: Date = Date()) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_GB")
    formatter.timeZone = TimeZone(identifier: "Asia/Jerusalem")
    formatter.dateFormat = "HH:mm"
    return formatter.string(from: now)
}

/// `HH:mm` off a wall `timestamp` or ISO string, without shifting the zone.
public func formatTime(_ value: String?) -> String? {
    let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if raw.isEmpty { return nil }
    let timePart: String
    if let t = raw.split(separator: "T", maxSplits: 1).dropFirst().first {
        timePart = String(t)
    } else if let s = raw.split(separator: " ", maxSplits: 1).dropFirst().first {
        timePart = String(s)
    } else {
        timePart = raw
    }
    let hhmm = String(timePart.prefix(5))
    return hhmm.count == 5 ? hhmm : nil
}

/// Digits → `HH:mm` as the user types (colon after the hour).
public func formatTimeInput(_ digits: String) -> String {
    let cleaned = String(digitsOnly(digits).prefix(4))
    let hour = String(cleaned.prefix(2))
    let minute = String(cleaned.dropFirst(2))
    return [hour, minute].filter { !$0.isEmpty }.joined(separator: ":")
}

/// Same backspace semantics as the return-date field: deleting over `:` removes a digit.
public func applyTimeKeystroke(previous: String, incoming: String) -> String {
    let previousDigits = digitsOnly(previous)
    var nextDigits = String(digitsOnly(incoming).prefix(4))
    if nextDigits == previousDigits && incoming.count < previous.count && !previousDigits.isEmpty {
        nextDigits = String(previousDigits.dropLast())
    }
    return formatTimeInput(nextDigits)
}

/// Grouped decimal like the web `Intl.NumberFormat('he-IL')`: whole numbers lose the fraction.
public func formatNumber(_ value: Double) -> String {
    let rounded = (value * 10).rounded() / 10
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: "en_US")
    formatter.numberStyle = .decimal
    formatter.usesGroupingSeparator = true
    if rounded == floor(rounded) {
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: rounded)) ?? "\(Int(rounded))"
    }
    formatter.minimumFractionDigits = 1
    formatter.maximumFractionDigits = 1
    return formatter.string(from: NSNumber(value: rounded)) ?? String(format: "%.1f", rounded)
}

public func formatNumber(_ value: Int) -> String {
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.numberStyle = .decimal
    formatter.usesGroupingSeparator = true
    formatter.maximumFractionDigits = 0
    return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
}

/// Road names: עירוני first, then pure numbers ascending, then the rest by name.
public func compareRoadNames(_ left: String, _ right: String) -> ComparisonResult {
    let leftUrban = left.contains("עירוני")
    let rightUrban = right.contains("עירוני")
    if leftUrban != rightUrban { return leftUrban ? .orderedAscending : .orderedDescending }
    let leftNumber = Int(left.trimmingCharacters(in: .whitespacesAndNewlines))
    let rightNumber = Int(right.trimmingCharacters(in: .whitespacesAndNewlines))
    if let ln = leftNumber, let rn = rightNumber {
        if ln == rn { return .orderedSame }
        return ln < rn ? .orderedAscending : .orderedDescending
    }
    if (leftNumber == nil) != (rightNumber == nil) {
        return leftNumber != nil ? .orderedAscending : .orderedDescending
    }
    let l = left.trimmingCharacters(in: .whitespacesAndNewlines)
    let r = right.trimmingCharacters(in: .whitespacesAndNewlines)
    if l == r { return .orderedSame }
    return l < r ? .orderedAscending : .orderedDescending
}

public func sortByRoadName<T>(_ items: [T], name: (T) -> String) -> [T] {
    items.sorted { compareRoadNames(name($0), name($1)) == .orderedAscending }
}

public func formatDateTime(_ iso: String) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    var date = formatter.date(from: iso)
    if date == nil {
        formatter.formatOptions = [.withInternetDateTime]
        date = formatter.date(from: iso)
    }
    guard let date else { return iso }
    let out = DateFormatter()
    out.locale = Locale(identifier: "he_IL")
    out.timeZone = TimeZone(identifier: "Asia/Jerusalem")
    out.dateFormat = "dd.MM.yyyy, HH:mm"
    return out.string(from: date)
}

public func firstName(from fullName: String) -> String {
    fullName.split(separator: " ").first.map(String.init) ?? fullName
}

public enum PasswordRule: String, Sendable {
    case minLength
    case uppercase
    case symbol
}

public func passwordStrengthError(_ password: String) -> String? {
    var missing: [String] = []
    if password.count < 8 { missing.append("8 תווים לפחות") }
    if password.range(of: "[A-Z]", options: .regularExpression) == nil {
        missing.append("אות גדולה")
    }
    if password.range(of: "[^A-Za-z0-9]", options: .regularExpression) == nil {
        missing.append("תו מיוחד (למשל !)")
    }
    if missing.isEmpty { return nil }
    return "הסיסמה אינה עומדת בדרישות. יש לכלול: \(formatHebrewList(missing))."
}

func formatHebrewList(_ items: [String]) -> String {
    if items.count == 1 { return items[0] }
    if items.count == 2 { return "\(items[0]) ו\(items[1])" }
    return "\(items.dropLast().joined(separator: ", ")) ו\(items.last!)"
}

/// `name · callsign`, dropping blanks, with a Hebrew fallback.
public func personDisplay(_ name: String?, callsign: String?, fallback: String = "מתנדב") -> String {
    let parts = [name, callsign].compactMap { value -> String? in
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
    return parts.isEmpty ? fallback : parts.joined(separator: " · ")
}

public let SHIFT_KIND_LABELS: [String: String] = [
    "morning": "בוקר",
    "midday": "צהריים",
    "reinforcement": "תגבור",
    "escort": "ליווי",
    "other": "אחר",
]

public let VEHICLE_TYPE_LABELS: [String: String] = [
    "patrol_north": "ניידת צפון",
    "patrol_center": "ניידת מרכז",
    "personal": "רכב פרטי",
]
