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

public func formatDate(_ value: String) -> String {
    let ymd = String(value.prefix(10))
    let parts = ymd.split(separator: "-")
    guard parts.count == 3 else { return value }
    return "\(parts[2]).\(parts[1]).\(parts[0])"
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
