import Foundation

/// Who may open a report. Mirrors the web registry `audience` field.
public enum ReportAudience: Sendable, Equatable {
    case managesUnit
    case admin
}

public enum ReportKindId: String, Sendable, Equatable, Hashable, CaseIterable {
    case openDocumentation = "open_documentation"
    case eventsByResponder = "events_by_responder"
    case kmExceptions = "km_exceptions"
    case kmDiscrepancy = "km_discrepancy"
    case duplicateEvents = "duplicate_events"
    case fuelRefund = "fuel_refund"

    public static func fromRaw(_ raw: String?) -> ReportKindId? {
        guard let raw else { return nil }
        return ReportKindId(rawValue: raw)
    }
}

/// A row rendered by the shared report screen. Reports differ only in how their
/// source rows collapse into this shape, so one screen serves all of them.
public struct ReportRow: Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var subtitle: String
    public var detail: String?
    public var trailing: String?
    public var eventId: String?
    public var stampLabel: String?
    public var stampTone: StampTone
    /// Set together when the row offers a write, e.g. replacing lead km with the odometer.
    public var actionId: String?
    public var actionTitle: String?
    public var actionConfirm: String?
    public var searchText: String

    public init(
        id: String,
        title: String,
        subtitle: String = "",
        detail: String? = nil,
        trailing: String? = nil,
        eventId: String? = nil,
        stampLabel: String? = nil,
        stampTone: StampTone = .pending,
        actionId: String? = nil,
        actionTitle: String? = nil,
        actionConfirm: String? = nil,
        searchText: String = ""
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.trailing = trailing
        self.eventId = eventId
        self.stampLabel = stampLabel
        self.stampTone = stampTone
        self.actionId = actionId
        self.actionTitle = actionTitle
        self.actionConfirm = actionConfirm
        self.searchText = searchText
    }
}

public struct ReportSpec: Equatable, Sendable {
    public var id: ReportKindId
    public var title: String
    public var includes: String
    public var audience: ReportAudience
    public var searchPlaceholder: String
    public var emptyTitle: String
    /// Fuel refund counts a calendar month; the event reports use a rolling window.
    public var rangeFromMonthStart: Bool
    public var defaultRangeDays: Int
    /// אירועים כפולים scans the whole history, so it hides the date fields.
    public var hasDateRange: Bool

    public init(
        id: ReportKindId,
        title: String,
        includes: String,
        audience: ReportAudience,
        searchPlaceholder: String,
        emptyTitle: String,
        rangeFromMonthStart: Bool = false,
        defaultRangeDays: Int = OPEN_DOC_DEFAULT_RANGE_DAYS,
        hasDateRange: Bool = true
    ) {
        self.id = id
        self.title = title
        self.includes = includes
        self.audience = audience
        self.searchPlaceholder = searchPlaceholder
        self.emptyTitle = emptyTitle
        self.rangeFromMonthStart = rangeFromMonthStart
        self.defaultRangeDays = defaultRangeDays
        self.hasDateRange = hasDateRange
    }
}

public let REPORT_RANGE_ERROR = "יש להזין תאריך התחלה וסיום תקינים"
public let REPORT_FAILED_TITLE = "טעינת הדוח נכשלה. בדקו את החיבור ונסו שוב."
public let REPORT_LOADING_TITLE = "טוען את הדוח…"
public let REPORT_LOAD_ACTION = "טעינת הדוח"

public let REPORT_SPECS: [ReportSpec] = [
    ReportSpec(
        id: .openDocumentation,
        title: OPEN_DOC_TITLE,
        includes: "אירועים שהוזנו על ידי אחמ״ש ומתנדב טרם השלים את התיעוד שלהם",
        audience: .managesUnit,
        searchPlaceholder: "מתנדב, אירוע או מיקום",
        emptyTitle: OPEN_DOC_EMPTY_TITLE
    ),
    ReportSpec(
        id: .eventsByResponder,
        title: "אירועים לפי מתנדב",
        includes: "כל האירועים של כל מתנדב בטווח התאריכים שנבחר",
        audience: .managesUnit,
        searchPlaceholder: "מתנדב, אירוע או מיקום",
        emptyTitle: "אין אירועים בתקופה זו"
    ),
    ReportSpec(
        id: .kmExceptions,
        title: "חריגי ק״מ",
        includes: "אירועים עם \(KM_EXCEPTION_THRESHOLD) ק״מ ומעלה",
        audience: .managesUnit,
        searchPlaceholder: "מתנדב, אירוע או מיקום",
        emptyTitle: "אין חריגי ק״מ בתקופה זו"
    ),
    ReportSpec(
        id: .kmDiscrepancy,
        title: "אירועים עם פערי דיווח ק״מ",
        includes: "אירועים בהם יש פער בין דיווח האחמ״ש לבין הק״מ שהזין המתנדב",
        audience: .admin,
        searchPlaceholder: "מתנדב, אירוע או מיקום",
        emptyTitle: "אין פערי דיווח בתקופה זו"
    ),
    ReportSpec(
        id: .duplicateEvents,
        title: "אירועים כפולים",
        includes: "אירועים עם אותו המתנדב, באותו מקום בחלון זמן של חצי שעה",
        audience: .managesUnit,
        searchPlaceholder: "מתנדב, אירוע או מיקום",
        emptyTitle: "לא נמצאו אירועים כפולים",
        hasDateRange: false
    ),
    ReportSpec(
        id: .fuelRefund,
        title: "טבלה מסכמת",
        includes: "סיכום הק״מ שדווחו לכל מתנדב בטווח התאריכים שנבחר",
        audience: .admin,
        searchPlaceholder: "חיפוש לפי שם או או״ק",
        emptyTitle: "אין ק״מ לדיווח בתקופה זו",
        rangeFromMonthStart: true
    ),
]

public func reportSpec(_ id: ReportKindId) -> ReportSpec {
    REPORT_SPECS.first { $0.id == id }!
}

public func visibleReportSpecs(_ roles: [String]) -> [ReportSpec] {
    let admin = isAdmin(roles)
    let unit = managesUnit(roles)
    return REPORT_SPECS.filter { spec in
        switch spec.audience {
        case .admin: return admin
        case .managesUnit: return unit
        }
    }
}

/// From/to for a report's default window, both inclusive ISO days.
public func defaultReportRange(spec: ReportSpec, today: String) -> (String, String) {
    if spec.rangeFromMonthStart {
        return ("\(today.prefix(7))-01", today)
    }
    return (addCalendarDays(ymd: today, days: -spec.defaultRangeDays), today)
}

public func isValidReportRange(_ from: String, _ to: String) -> Bool {
    !from.isEmpty && !to.isEmpty && from <= to
}

public func filterReportRows(_ rows: [ReportRow], query: String) -> [ReportRow] {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return rows }
    return rows.filter { row in
        fieldsMatchQuery([row.searchText, row.title, row.subtitle, row.detail], query: trimmed)
    }
}

public func reportRowSummary(_ count: Int) -> String {
    switch count {
    case 0: return "אין שורות בדוח"
    case 1: return "שורה אחת בדוח"
    default: return "\(count) שורות בדוח"
    }
}

/// `road · location`, dropping blanks.
public func placeDisplay(_ roadName: String?, _ location: String?) -> String {
    [roadName, location].compactMap { value -> String? in
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }.joined(separator: " · ")
}

/// Cancelled events keep their police number but are labelled first, like the web.
public func policeEventLabel(_ policeEventId: String?, isCancelled: Bool) -> String {
    let number = policeEventId?.trimmingCharacters(in: .whitespacesAndNewlines)
    let hasNumber = !(number ?? "").isEmpty
    switch (isCancelled, hasNumber) {
    case (true, true): return "בוטל · \(number!)"
    case (true, false): return "בוטל"
    case (false, true): return number!
    case (false, false): return "—"
    }
}
