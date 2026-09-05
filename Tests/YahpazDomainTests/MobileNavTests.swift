import XCTest
@testable import YahpazDomain

final class MobileNavTests: XCTestCase {
    private func views(_ list: [MobileNavEntry]) -> [String] {
        list.map(\.view)
    }

    func testResponderSetOfThreeStaysInTheTabBarWithNoOverflow() {
        let split = splitMobileNav([
            MobileNavEntry(view: "mine", label: "האירועים שלי"),
            MobileNavEntry(view: "my_shifts", label: "המשמרות שלי"),
            MobileNavEntry(view: "contacts", label: "אנשי קשר"),
        ])
        XCTAssertEqual(views(split.tabs), ["mine", "my_shifts", "contacts"])
        XCTAssertTrue(split.more.isEmpty)
    }

    func testShiftLeadDailyWorkStaysInTheBarAndTheRestGoesBehindMore() {
        let split = splitMobileNav([
            MobileNavEntry(view: "contacts", label: "אנשי קשר"),
            MobileNavEntry(view: "reports", label: "דוחות"),
            MobileNavEntry(view: "shifts", label: "משמרות"),
            MobileNavEntry(view: "events", label: "אירועים"),
            MobileNavEntry(view: "my_shifts", label: "המשמרות שלי"),
            MobileNavEntry(view: "mine", label: "האירועים שלי"),
        ])
        XCTAssertEqual(views(split.tabs), ["events", "mine", "my_shifts"])
        XCTAssertEqual(views(split.more), ["shifts", "contacts", "reports"])
    }

    func testAdminKeepsManagementInTheBarAndDemotesPersonalShifts() {
        let split = splitMobileNav([
            MobileNavEntry(view: "mine", label: "האירועים שלי"),
            MobileNavEntry(view: "my_shifts", label: "המשמרות שלי"),
            MobileNavEntry(view: "contacts", label: "אנשי קשר"),
            MobileNavEntry(view: "events", label: "אירועים"),
            MobileNavEntry(view: "shifts", label: "משמרות"),
            MobileNavEntry(view: "users", label: "ניהול"),
        ])
        XCTAssertEqual(views(split.tabs), ["events", "mine", "users"])
        XCTAssertEqual(views(split.more), ["my_shifts", "shifts", "contacts"])
    }

    func testMobileNavEntriesUsesWebLabelsAndSkipsMapAndCockpit() {
        let lead = mobileNavEntries(["shift_lead", "responder"])
        XCTAssertEqual(
            views(lead),
            ["mine", "my_shifts", "contacts", "events", "shifts", "reports", "profile"]
        )
        XCTAssertEqual(lead.first { $0.view == "events" }?.label, "אירועים")
        XCTAssertFalse(lead.contains { $0.view == "map" || $0.view == "cockpit" })

        let admin = mobileNavEntries(["admin"])
        XCTAssertEqual(admin.first { $0.view == "users" }?.label, "ניהול")
        XCTAssertFalse(admin.contains { $0.view == "reports" })
    }

    func testLeadsLandOnUnitEventsRespondersOnMine() {
        XCTAssertEqual(defaultMobileView(["shift_lead"]), "events")
        XCTAssertEqual(defaultMobileView(["admin"]), "events")
        XCTAssertEqual(defaultMobileView(["responder"]), "mine")
    }

    func testOverflowLabelIsTheWebMore() {
        XCTAssertEqual(MOBILE_MORE_LABEL, "עוד")
    }

    func testResponderSignedInChromeUsesHebrewTabTitlesWithNoOverflow() {
        let chrome = splitMobileNav(mobileNavEntries(["responder"]))
        XCTAssertEqual(
            chrome.tabs.map(\.label),
            ["האירועים שלי", "המשמרות שלי", "אנשי קשר", "פרופיל"]
        )
        XCTAssertTrue(chrome.more.isEmpty, "responder has four destinations — no עוד list")
        XCTAssertFalse(chrome.tabs.map(\.label).contains(MOBILE_MORE_LABEL))
    }

    func testShiftLeadSignedInChromeHebrewTitlesAndMoreOverflow() {
        let chrome = splitMobileNav(mobileNavEntries(["shift_lead"]))
        XCTAssertEqual(
            chrome.tabs.map(\.label),
            ["אירועים", "האירועים שלי", "המשמרות שלי"]
        )
        XCTAssertEqual(
            chrome.more.map(\.label),
            ["משמרות", "אנשי קשר", "דוחות", "פרופיל"]
        )
        XCTAssertEqual(barLabels(chrome), ["אירועים", "האירועים שלי", "המשמרות שלי", "עוד"])
        XCTAssertEqual(chrome.more.first?.label.isEmpty, false)
    }

    func testAdminSignedInChromeKeepsManagementAndOverflowsToMoreList() {
        let chrome = splitMobileNav(mobileNavEntries(["admin"]))
        XCTAssertEqual(
            chrome.tabs.map(\.label),
            ["אירועים", "האירועים שלי", "ניהול"]
        )
        XCTAssertEqual(
            chrome.more.map(\.label),
            ["המשמרות שלי", "משמרות", "אנשי קשר", "פרופיל"]
        )
        XCTAssertEqual(barLabels(chrome), ["אירועים", "האירועים שלי", "ניהול", "עוד"])
    }

    func testMoreOverflowIsAnInContentListTitledMoreNotASheetDestination() {
        let lead = splitMobileNav(mobileNavEntries(["shift_lead"]))
        XCTAssertEqual(lead.more.map(\.view), ["shifts", "contacts", "reports", "profile"])
        XCTAssertFalse(lead.tabs.contains { $0.view == "more" || $0.label == MOBILE_MORE_LABEL })
        XCTAssertEqual(MOBILE_MORE_LABEL, "עוד")

        let responder = splitMobileNav(mobileNavEntries(["responder"]))
        XCTAssertTrue(responder.more.isEmpty, "no עוד list when nothing overflows")
    }

    private func barLabels(_ split: SplitMobileNav) -> [String] {
        let tabs = split.tabs.map(\.label)
        return split.more.isEmpty ? tabs : tabs + [MOBILE_MORE_LABEL]
    }
}
