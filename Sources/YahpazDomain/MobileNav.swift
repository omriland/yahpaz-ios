import Foundation

/// Port of web `mobileNav.ts`. Same ranks, same overflow rule, same Hebrew labels.
/// Native skips `map` (Google Maps JS) and desktop-only `cockpit`.

public let MOBILE_MORE_LABEL = "עוד"

/// Daily destinations — keep these in the tab bar when they exist.
private let MOBILE_TAB_PRIMARY = ["events", "mine", "users", "my_shifts"]

/// Reachable on mobile, but not every-session. Overflow into עוד.
private let MOBILE_TAB_SECONDARY = ["shifts", "contacts", "reports"]

/// Five is the hard limit; the last slot is reserved for עוד when anything overflows.
private let MOBILE_TAB_MAX = 4

public struct MobileNavEntry: Equatable, Sendable {
    public let view: String
    public let label: String

    public init(view: String, label: String) {
        self.view = view
        self.label = label
    }
}

public struct SplitMobileNav: Equatable, Sendable {
    public let tabs: [MobileNavEntry]
    public let more: [MobileNavEntry]

    public init(tabs: [MobileNavEntry], more: [MobileNavEntry]) {
        self.tabs = tabs
        self.more = more
    }
}

private func rank(_ view: String) -> Int {
    if let primary = MOBILE_TAB_PRIMARY.firstIndex(of: view) {
        return primary
    }
    if let secondary = MOBILE_TAB_SECONDARY.firstIndex(of: view) {
        return MOBILE_TAB_PRIMARY.count + secondary
    }
    return MOBILE_TAB_PRIMARY.count + MOBILE_TAB_SECONDARY.count
}

public func splitMobileNav(_ entries: [MobileNavEntry]) -> SplitMobileNav {
    let ordered = entries.sorted { rank($0.view) < rank($1.view) }
    if ordered.count <= MOBILE_TAB_MAX {
        return SplitMobileNav(tabs: ordered, more: [])
    }
    return SplitMobileNav(
        tabs: Array(ordered.prefix(MOBILE_TAB_MAX - 1)),
        more: Array(ordered.dropFirst(MOBILE_TAB_MAX - 1))
    )
}

/// Destinations a signed-in user can open on the phone.
/// Matches web `App.tsx` entries for mobile, minus מפה and הקוקפיט.
public func mobileNavEntries(_ roles: [String]) -> [MobileNavEntry] {
    var list: [MobileNavEntry] = []
    let hasMineList = isResponder(roles) || roleSet(roles).contains(.shiftLead)
    let manages = managesUnit(roles)
    let admin = isAdmin(roles)

    if hasMineList {
        list.append(MobileNavEntry(view: "mine", label: "האירועים שלי"))
        list.append(MobileNavEntry(view: "my_shifts", label: "המשמרות שלי"))
    }
    list.append(MobileNavEntry(view: "contacts", label: "אנשי קשר"))
    if manages {
        list.append(MobileNavEntry(view: "events", label: "אירועים"))
        list.append(MobileNavEntry(view: "shifts", label: "משמרות"))
        if !admin {
            list.append(MobileNavEntry(view: "reports", label: "דוחות"))
        }
    }
    if admin {
        list.append(MobileNavEntry(view: "users", label: "ניהול"))
    }
    list.append(MobileNavEntry(view: "profile", label: "פרופיל"))
    return list
}

/// First screen after login. Leads and admins land on unit אירועים so
/// creating and assigning is the first job; responders land on האירועים שלי.
public func defaultMobileView(_ roles: [String]) -> String {
    managesUnit(roles) ? "events" : "mine"
}
