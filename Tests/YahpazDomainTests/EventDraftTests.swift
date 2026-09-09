import XCTest
@testable import YahpazDomain

final class EventDraftTests: XCTestCase {
    private let roads = [
        LookupOption(id: "road-6", name: "6"),
        LookupOption(id: "road-101", name: "עירוני (101)"),
    ]
    private let districts = [
        LookupOption(id: "d-north", name: "צפון"),
        LookupOption(id: "d-system", name: "תחנה / אחר / משוכפל", code: SYSTEM_DISTRICT_CODE),
    ]

    private func draft(
        date: String = "2026-02-02",
        typeId: String = "type-1",
        roadId: String = "road-6",
        districtId: String = "",
        location: String = ""
    ) -> EventDraft {
        EventDraft(
            eventDate: date,
            eventTypeId: typeId,
            roadId: roadId,
            districtId: districtId,
            location: location
        )
    }

    func testDistrictLookupsFollowSortOrderNotName() {
        let shuffled = [
            LookupOption(id: "c", name: "צפון", sortOrder: 2),
            LookupOption(id: "a", name: "דרום", sortOrder: 1),
            LookupOption(id: "b", name: "אבן", sortOrder: 3),
        ]
        XCTAssertEqual(sortLookupsBySortOrder(shuffled).map(\.id), ["a", "c", "b"])
    }

    func testDateTypeAndRoadAreTheMinimum() {
        XCTAssertTrue(validateEventDraft(draft()).isEmpty)
        XCTAssertEqual(validateEventDraft(draft(date: "")).eventDate, EVENT_DRAFT_DATE_ERROR)
        XCTAssertEqual(validateEventDraft(draft(typeId: "")).eventType, EVENT_DRAFT_TYPE_ERROR)
        XCTAssertEqual(validateEventDraft(draft(roadId: "")).road, EVENT_DRAFT_ROAD_ERROR)
    }

    func testDdMmYyyyInputIsAcceptedAsADate() {
        XCTAssertTrue(validateEventDraft(draft(date: "02/02/2026")).isEmpty)
        XCTAssertEqual(validateEventDraft(draft(date: "32/02/2026")).eventDate, EVENT_DRAFT_DATE_ERROR)
    }

    func testTheSystemDistrictMakesLocationMandatory() {
        XCTAssertTrue(districtNeedsLocation(districts, districtId: "d-system"))
        XCTAssertFalse(districtNeedsLocation(districts, districtId: "d-north"))
        XCTAssertFalse(districtNeedsLocation(districts, districtId: ""))
        let errors = validateEventDraft(draft(districtId: "d-system"), districts: districts)
        XCTAssertEqual(errors.location, EVENT_DRAFT_LOCATION_ERROR)
        XCTAssertEqual(errors.formMessage, EVENT_DRAFT_FORM_LOCATION_ERROR)
        XCTAssertTrue(
            validateEventDraft(draft(districtId: "d-system", location: "כיכר"), districts: districts).isEmpty
        )
    }

    func testFormMessageFallsBackToTheNonLocationCopy() {
        XCTAssertEqual(validateEventDraft(draft(roadId: "")).formMessage, EVENT_DRAFT_FORM_ERROR)
        XCTAssertNil(validateEventDraft(draft()).formMessage)
    }

    func testCrewlessEventsSaveAsDrafts() {
        XCTAssertEqual(eventDraftStatus(responderCount: 0), .draft)
        XCTAssertEqual(eventDraftStatus(responderCount: 1), .inProgress)
        XCTAssertEqual(eventDraftSummary(responderCount: 0), "טרם הוקצו מתנדבים · אירוע בהזנה")
        XCTAssertEqual(eventDraftSummary(responderCount: 1), "מתנדב אחד משובץ")
        XCTAssertEqual(eventDraftSummary(responderCount: 3), "3 מתנדבים משובצים")
    }

    func testTheSystemDistrictDefaultsToThe101Road() {
        XCTAssertEqual(defaultRoadIdForSystemDistrict(roads), "road-101")
        XCTAssertNil(defaultRoadIdForSystemDistrict([LookupOption(id: "a", name: "6")]))
    }

    func testEnteringTheSystemDistrictPreselectsThe101Road() {
        XCTAssertEqual(
            applyDistrictRoadDefault(
                previousDistrictId: "",
                nextDistrictId: "d-system",
                districts: districts,
                roads: roads,
                currentRoadId: ""
            ),
            "road-101"
        )
        XCTAssertEqual(
            applyDistrictRoadDefault(
                previousDistrictId: "",
                nextDistrictId: "d-north",
                districts: districts,
                roads: roads,
                currentRoadId: "road-6"
            ),
            "road-6"
        )
        XCTAssertEqual(
            applyDistrictRoadDefault(
                previousDistrictId: "d-system",
                nextDistrictId: "d-system",
                districts: districts,
                roads: roads,
                currentRoadId: "road-6"
            ),
            "road-6"
        )
    }

    func testEventCrewTogglesWithoutACeiling() {
        var crew = toggleEventResponder([], responderId: "a")
        crew = toggleEventResponder(crew, responderId: "b")
        crew = toggleEventResponder(crew, responderId: "c")
        crew = toggleEventResponder(crew, responderId: "d")
        XCTAssertEqual(crew.map(\.responderId), ["a", "b", "c", "d"])
        XCTAssertTrue(crew.allSatisfy { $0.emergencyMeans == NEW_RESPONDER_EMERGENCY_MEANS })
        XCTAssertEqual(toggleEventResponder(crew, responderId: "b").map(\.responderId), ["a", "c", "d"])
    }

    func testCreateBlocksTheLeadFromAssigningThemselves() {
        let crew = [EventResponderDraft(responderId: "lead"), EventResponderDraft(responderId: "r2")]
        XCTAssertTrue(createIncludesSelfAssign(shiftLeadId: "lead", responders: crew))
        XCTAssertFalse(createIncludesSelfAssign(shiftLeadId: "lead", responders: [EventResponderDraft(responderId: "r2")]))
        XCTAssertTrue(isSelfAssignDisabledOnCreate(isCreate: true, currentUserId: "me", profileId: "me"))
        XCTAssertFalse(isSelfAssignDisabledOnCreate(isCreate: false, currentUserId: "me", profileId: "me"))
        XCTAssertFalse(isSelfAssignDisabledOnCreate(isCreate: true, currentUserId: "me", profileId: "other"))
        XCTAssertEqual(EVENT_SELF_ASSIGN_ON_CREATE_ERROR, "לא ניתן לשבץ את יוצר האירוע כמתנדב.")
        XCTAssertEqual(EVENT_SELF_ASSIGN_DISABLED_HINT, "לא ניתן לשבץ")
    }

    func testAssignableProfilesFilterByNameAndCallsign() {
        let profiles = [
            AssignableProfile(id: "r1", fullName: "דנה כהן", callsign: "12"),
            AssignableProfile(id: "r2", fullName: "יוסי לוי", callsign: "44"),
        ]
        XCTAssertEqual(filterAssignableProfiles(profiles, query: "דנה").map(\.id), ["r1"])
        XCTAssertEqual(filterAssignableProfiles(profiles, query: "44").map(\.id), ["r2"])
        XCTAssertEqual(filterAssignableProfiles(profiles, query: " ").count, 2)
        XCTAssertEqual(profiles[0].display, "דנה כהן · 12")
    }

    func testClearingTheCancelledFlagIsAllowedForUnitManagers() {
        XCTAssertNil(canToggleEventCancelled(next: true, canClearCancelled: false))
        XCTAssertNil(canToggleEventCancelled(next: false, canClearCancelled: true))
        XCTAssertEqual(canToggleEventCancelled(next: false, canClearCancelled: false), EVENT_CANCEL_ADMIN_ONLY)
    }

    func testCancelCopyIsTheWebCheckboxLabel() {
        XCTAssertEqual(EVENT_CANCELLED_LABEL, "בוטל")
        XCTAssertEqual(eventCancelToggleLabel(isCancelled: false), "בוטל")
        XCTAssertEqual(eventCancelToggleLabel(isCancelled: true), "בוטל")
        XCTAssertEqual(eventCancelToast(isCancelled: true), "האירוע סומן כבוטל.")
        XCTAssertEqual(eventCancelToast(isCancelled: false), "סימון הביטול הוסר.")
        XCTAssertEqual(EVENT_CANCEL_ADMIN_ONLY, "רק מנהל או אחמ״ש יכולים לבטל סימון בוטל.")
    }

    func testEventFormCopyMatchesTheWeb() {
        XCTAssertEqual(EVENT_NEW_TITLE, "אירוע חדש")
        XCTAssertEqual(EVENT_EDIT_TITLE, "עריכת אירוע")
        XCTAssertEqual(EVENT_SAVE_TITLE, "שמירת אירוע")
        XCTAssertEqual(EVENT_SAVE_DRAFT_TITLE, "שמירת טיוטה")
        XCTAssertEqual(MY_ACTIVE_EVENTS_TITLE, "האירועים הפעילים שלי")
        XCTAssertEqual(EVENT_ASSIGN_OPEN, "מתנדבים")
        XCTAssertEqual(EVENT_ASSIGN_CLOSE, "סגירת הקצאה")
        XCTAssertEqual(EVENT_ASSIGN_REMOVE, "הסרת מתנדב")
        XCTAssertEqual(EVENT_PATROL_CALLSIGN_LABEL, "או״ק ניידת")
        XCTAssertEqual(EVENT_LOCATION_PLACEHOLDER, "למשל: מחלף שורק")
        XCTAssertEqual(UNIT_EVENTS_LOAD_FAILED, "טעינת האירועים נכשלה. בדקו את החיבור ונסו שוב.")
    }

    func testDraftSaveOnlyRequiresADate() {
        XCTAssertTrue(validateEventDraftPartial(EventDraft(eventDate: "2026-02-02")).isEmpty)
        XCTAssertEqual(validateEventDraftPartial(EventDraft(eventDate: "")).eventDate, EVENT_DRAFT_DATE_ERROR)
    }

    func testFillReadyNotifyFiresOnAssignmentEvenWithoutKm() {
        XCTAssertEqual(
            fillReadyNotifyIds(previous: [], next: [FillReadyNextRow(assignmentId: "new", totalKm: nil)]),
            ["new"]
        )
    }

    func testOwnSameDayPoliceIdIsResumedWhenCreateHasNoIdYet() {
        let mine = SameDayPoliceEventRow(id: "evt-mine", shiftLeadId: "lead-1")
        XCTAssertEqual(
            ownResumableEventId(currentEventId: nil, viewerLeadId: "lead-1", existing: [mine]),
            "evt-mine"
        )
        XCTAssertNil(
            ownResumableEventId(
                currentEventId: nil,
                viewerLeadId: "lead-1",
                existing: [SameDayPoliceEventRow(id: "evt-mine", shiftLeadId: "other")]
            )
        )
        XCTAssertNil(
            ownResumableEventId(currentEventId: "evt-mine", viewerLeadId: "lead-1", existing: [mine])
        )
    }

    func testFillReadyNotifyStillFiresWhenAnExistingAssignmentFirstGetsKm() {
        XCTAssertEqual(
            fillReadyNotifyIds(
                previous: [FillReadyPreviousRow(id: "a", totalKm: nil)],
                next: [FillReadyNextRow(assignmentId: "a", totalKm: 8.0)]
            ),
            ["a"]
        )
    }

    func testStationSavesOnlyOnTheSystemDistrict() {
        XCTAssertEqual(stationForSave(districts, districtId: "d-system", station: "  איילון  "), "איילון")
        XCTAssertNil(stationForSave(districts, districtId: "d-system", station: "   "))
        XCTAssertNil(stationForSave(districts, districtId: "d-north", station: "איילון"))
        XCTAssertEqual(stationAfterDistrictChange(districts, nextDistrictId: "d-north", currentStation: "איילון"), "")
        XCTAssertEqual(stationAfterDistrictChange(districts, nextDistrictId: "d-system", currentStation: "איילון"), "איילון")
        let long = String(repeating: "א", count: STATION_MAX_LENGTH + 10)
        XCTAssertEqual(stationForSave(districts, districtId: "d-system", station: long)?.count, STATION_MAX_LENGTH)
    }
}
