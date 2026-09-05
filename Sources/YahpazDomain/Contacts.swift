import Foundation

public let CONTACTS_TITLE = "אנשי קשר"
public let CONTACTS_SEARCH_PLACEHOLDER = "שם, או״ק, טלפון או דוא״ל"
public let CONTACTS_EMPTY_TITLE = "אין אנשי קשר להצגה"
public let CONTACTS_NO_RESULTS_TITLE = "לא נמצאו אנשי קשר תואמים"
public let CONTACTS_FAILED_TITLE = "טעינת אנשי הקשר נכשלה. בדקו את החיבור ונסו שוב."
public let CONTACTS_LOADING_TITLE = "טוען אנשי קשר…"
public let CONTACTS_REFRESH_ACTION = "רענון"
public let CONTACTS_CLEAR_SEARCH_ACTION = "ניקוי חיפוש"
public let CONTACTS_FALLBACK_NAME = "מתנדב"
public let CONTACTS_NO_PHONE_TOAST = "אין מספר טלפון זמין לאיש הקשר הזה."
public let CONTACTS_NO_APP_TOAST = "לא נמצאה אפליקציה שיכולה לפתוח את הקישור."
public let CONTACTS_CALL_LABEL = "התקשרות"
public let CONTACTS_WHATSAPP_LABEL = "וואטסאפ"

public func phoneDigits(_ raw: String?) -> String {
    String(digitsOnly(raw ?? "").prefix(10))
}

/// 0501234567 → 050-1234567.
public func formatPhone(_ raw: String?) -> String {
    let digits = phoneDigits(raw)
    if digits.count <= 3 { return digits }
    return "\(digits.prefix(3))-\(digits.dropFirst(3))"
}

/// True when raw is an Israeli mobile: 10 digits starting with 05.
public func isValidIlMobile(_ raw: String?) -> Bool {
    let digits = phoneDigits(raw)
    return digits.count == 10 && digits.hasPrefix("05")
}

/// 0501234567 → tel:+972501234567. Null unless 10 digits.
public func telHref(_ raw: String?) -> String? {
    let digits = phoneDigits(raw)
    guard digits.count == 10 else { return nil }
    return "tel:+972\(digits.dropFirst())"
}

/// Israeli mobile only → https://wa.me/972…
public func whatsAppHref(_ raw: String?) -> String? {
    guard isValidIlMobile(raw) else { return nil }
    return "https://wa.me/972\(phoneDigits(raw).dropFirst())"
}

public struct ContactSearchFields: Equatable, Sendable {
    public var fullName: String
    public var callsign: String
    public var email: String
    public var phone: String?

    public init(fullName: String, callsign: String, email: String, phone: String?) {
        self.fullName = fullName
        self.callsign = callsign
        self.email = email
        self.phone = phone
    }
}

public func contactMatchesQuery(_ fields: ContactSearchFields, query: String) -> Bool {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return true }
    let matched = fieldsMatchQuery(
        [
            fields.fullName,
            fields.callsign,
            fields.email,
            fields.phone,
            fields.phone.map { formatPhone($0) },
        ],
        query: trimmed
    )
    if matched { return true }
    let queryDigits = phoneDigits(trimmed)
    let phone = fields.phone ?? ""
    return queryDigits.count >= 3
        && !phone.isEmpty
        && phoneDigits(fields.phone).contains(queryDigits)
}

public func filterContacts<T>(
    _ contacts: [T],
    query: String,
    fields: (T) -> ContactSearchFields
) -> [T] {
    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return contacts
    }
    return contacts.filter { contactMatchesQuery(fields($0), query: query) }
}
