import XCTest
@testable import YahpazDomain

final class EventShiftLeadsTests: XCTestCase {
    private func lead(
        userId: String,
        locked: Bool = false,
        name: String? = nil,
        callsign: String? = nil
    ) -> SecondaryLead {
        SecondaryLead(
            userId: userId,
            locked: locked,
            fullName: name ?? userId,
            callsign: callsign ?? userId
        )
    }

    func testManagesSecondariesForLeadAdminSuperAdmin() {
        XCTAssertTrue(canManageSecondaryLeads(["shift_lead"]))
        XCTAssertTrue(canManageSecondaryLeads(["admin"]))
        XCTAssertTrue(canManageSecondaryLeads(["super_admin"]))
        XCTAssertFalse(canManageSecondaryLeads(["responder"]))
    }

    func testCreatingLeadMayPickMainBeforeSecondariesExist() {
        XCTAssertTrue(
            canChangeEventMainLead(
                roles: ["shift_lead"],
                eventExists: false,
                viewerIsCurrentMain: true,
                hasSecondaries: false
            )
        )
        XCTAssertTrue(
            canChangeEventMainLead(
                roles: ["shift_lead"],
                eventExists: true,
                viewerIsCurrentMain: true,
                hasSecondaries: false
            )
        )
        XCTAssertFalse(
            canChangeEventMainLead(
                roles: ["shift_lead"],
                eventExists: true,
                viewerIsCurrentMain: true,
                hasSecondaries: true
            )
        )
        XCTAssertTrue(
            canChangeEventMainLead(
                roles: ["admin"],
                eventExists: true,
                viewerIsCurrentMain: false,
                hasSecondaries: true
            )
        )
    }

    func testNobodyRemovesLockedSecondaries() {
        XCTAssertTrue(canRemoveSecondaryLead(roles: ["shift_lead"], locked: false))
        XCTAssertFalse(canRemoveSecondaryLead(roles: ["super_admin"], locked: true))
        XCTAssertFalse(canRemoveSecondaryLead(roles: ["responder"], locked: false))
    }

    func testForeignEditPopupSkipsOnlyMain() {
        XCTAssertFalse(isForeignShiftLeadEvent(viewerId: "main", shiftLeadId: "main"))
        XCTAssertTrue(isForeignShiftLeadEvent(viewerId: "secondary", shiftLeadId: "main"))
        XCTAssertTrue(isForeignShiftLeadEvent(viewerId: "other-lead", shiftLeadId: "main"))
    }

    func testAutoLockOnlyAfterRealPersistByNonMainShiftLead() {
        XCTAssertTrue(
            shouldAutoLockSecondary(
                viewerId: "dana",
                mainLeadId: "omri",
                persistedFieldChange: true,
                viewerHasShiftLead: true
            )
        )
        XCTAssertFalse(
            shouldAutoLockSecondary(
                viewerId: "dana",
                mainLeadId: "omri",
                persistedFieldChange: false,
                viewerHasShiftLead: true
            )
        )
        XCTAssertFalse(
            shouldAutoLockSecondary(
                viewerId: "omri",
                mainLeadId: "omri",
                persistedFieldChange: true,
                viewerHasShiftLead: true
            )
        )
        XCTAssertFalse(
            shouldAutoLockSecondary(
                viewerId: "admin-only",
                mainLeadId: "omri",
                persistedFieldChange: true,
                viewerHasShiftLead: false
            )
        )
    }

    func testCreateTimeTransferAddsCreatorAsRemovableSecondary() {
        XCTAssertEqual(
            createTimeCreatorSecondary(creatorId: "omri", mainLeadId: "dana"),
            SecondaryLead(userId: "omri", locked: false, fullName: "", callsign: "")
        )
        XCTAssertNil(createTimeCreatorSecondary(creatorId: "omri", mainLeadId: "omri"))
    }

    func testReassignMovesNewMainOutAndDemotesOldMain() {
        let next = reassignMainLeads(
            previousMainId: "omri",
            nextMainId: "dana",
            previousMainName: "עמרי",
            previousMainCallsign: "Admin",
            secondaries: [lead(userId: "dana", name: "דנה", callsign: "D1"), lead(userId: "gil")]
        )
        XCTAssertEqual(next.mainId, "dana")
        XCTAssertEqual(next.secondaries.map(\.userId), ["gil", "omri"])
        XCTAssertEqual(next.secondaries.first(where: { $0.userId == "omri" })?.locked, false)
    }

    func testLeadCopyAndCaption() {
        XCTAssertEqual(EVENT_FORM_LEADS_SECTION, "אחמ״ש/ים")
        XCTAssertEqual(eventLeadFieldLabel(hasSecondaries: false), MAIN_LEAD_LABEL_SHORT)
        XCTAssertEqual(eventLeadFieldLabel(hasSecondaries: true), MAIN_LEAD_LABEL)
        XCTAssertEqual(formatLeadPerson("דנה כהן", callsign: "D1"), "דנה כהן · D1")
        XCTAssertEqual(
            formatLeadsCaption(mainFullName: "דנה כהן", mainCallsign: "D1", secondaries: [("עמרי", "Admin")]),
            "דנה כהן · D1 · עמרי · Admin"
        )
        XCTAssertEqual(
            formatListLeadCaption(
                mainFullName: "דנה כהן",
                mainCallsign: "D1",
                secondaries: [("עמרי", "Admin"), ("גיא", "G1")]
            ),
            "דנה כהן · D1 +2"
        )
        XCTAssertEqual(
            eventLeadsCaption(origin: "shift", mainFullName: "דנה", mainCallsign: "D1", secondaries: [("עמרי", "Admin")]),
            ""
        )
        XCTAssertEqual(
            eventLeadsCaption(origin: "manual", mainFullName: "דנה", mainCallsign: "D1", secondaries: [("עמרי", "Admin")]),
            "דנה · D1 +1"
        )
    }
}
