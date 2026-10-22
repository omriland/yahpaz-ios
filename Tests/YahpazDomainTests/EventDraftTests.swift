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
            patrolCallsignNumber: "411",
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

    func testDateAndTypeAreTheMinimum() {
        XCTAssertTrue(validateEventDraft(draft()).isEmpty)
        XCTAssertEqual(validateEventDraft(draft(date: "")).eventDate, EVENT_DRAFT_DATE_ERROR)
        XCTAssertEqual(validateEventDraft(draft(typeId: "")).eventType, EVENT_DRAFT_TYPE_ERROR)
        XCTAssertNil(validateEventDraft(draft(roadId: "")).road)
        var noCallsign = draft()
        noCallsign.patrolCallsignNumber = ""
        XCTAssertTrue(validateEventDraft(noCallsign).isEmpty)
        XCTAssertTrue(validateEventDraftPartial(noCallsign).isEmpty)
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
        XCTAssertEqual(validateEventDraft(draft(typeId: "")).formMessage, EVENT_DRAFT_FORM_ERROR)
        XCTAssertNil(validateEventDraft(draft(roadId: "")).formMessage)
        XCTAssertNil(validateEventDraft(draft()).formMessage)
        XCTAssertEqual(EVENT_DRAFT_FORM_ERROR, "יש למלא תאריך וסוג אירוע כדי ליצור אירוע.")
        XCTAssertEqual(EVENT_DRAFT_FORM_LOCATION_ERROR, "יש למלא תאריך, סוג אירוע ומיקום כדי ליצור אירוע.")
    }

    func testAssignedResponderCaptionTeachesTheTapTargetThenShowsKm() {
        XCTAssertEqual(EVENT_ASSIGN_EDIT_HINT, "ק״מ")
        XCTAssertEqual(assignedResponderCaption(totalKm: "", hasVehicle: true), EVENT_ASSIGN_EDIT_HINT)
        XCTAssertEqual(assignedResponderCaption(totalKm: "18", hasVehicle: true), "18 ק״מ")
        XCTAssertEqual(assignedResponderCaption(totalKm: "12", hasVehicle: false), EVENT_ASSIGN_EDIT_HINT)
    }

    func testRemoveConfirmIsNeededAfterAnyLeadFieldIsFilled() {
        let empty = EventResponderDraft(responderId: "r1", assignmentId: "a1")
        XCTAssertFalse(eventResponderHasFilledFields(empty))
        var km = empty
        km.totalKm = "12"
        XCTAssertTrue(eventResponderHasFilledFields(km))
        var means = empty
        means.emergencyMeans = true
        XCTAssertTrue(eventResponderHasFilledFields(means))
        var treated = empty
        treated.treated = [TreatedVehicleDraft(vehicleKindId: "car", quantity: 1)]
        XCTAssertTrue(eventResponderHasFilledFields(treated))
        var noVehicle = km
        noVehicle.hasVehicle = false
        XCTAssertFalse(eventResponderHasFilledFields(noVehicle))
        var zero = empty
        zero.treated = [TreatedVehicleDraft(vehicleKindId: "car", quantity: 0)]
        XCTAssertFalse(eventResponderHasFilledFields(zero))
        var unsavedDefault = empty
        unsavedDefault.assignmentId = ""
        unsavedDefault.emergencyMeans = NEW_RESPONDER_EMERGENCY_MEANS
        XCTAssertFalse(eventResponderHasFilledFields(unsavedDefault))
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
        XCTAssertEqual(EVENT_CREATE_TITLE, "יצירת אירוע")
        XCTAssertEqual(EVENT_CREATE_DRAFT_TITLE, "שמירה כטיוטה")
        XCTAssertEqual(eventFormPrimaryTitle(editing: false), EVENT_CREATE_TITLE)
        XCTAssertEqual(eventFormDraftTitle(editing: false), EVENT_CREATE_DRAFT_TITLE)
        XCTAssertEqual(EVENT_START_TIME_LABEL, "זמן התחלה")
        XCTAssertEqual(EVENT_END_TIME_LABEL, "זמן סיום")
        XCTAssertEqual(TIME_NOW_LABEL, "עכשיו")
        XCTAssertEqual(eventFormPrimaryTitle(editing: true), EVENT_SAVE_TITLE)
        XCTAssertEqual(eventFormDraftTitle(editing: true), EVENT_SAVE_DRAFT_TITLE)
        XCTAssertEqual(EVENT_FORM_DETAILS_SECTION, "פרטי האירוע")
        XCTAssertEqual(EVENT_FORM_RESPONDERS_SECTION, "מתנדבים")
        XCTAssertEqual(EVENT_TIMES_FIELD_NOTE, "שימו לב! מעתה הזנת זמנים תהיה עבור האירוע כולו ולא לכל מתנדב בנפרד")
        XCTAssertEqual(
            EVENT_TIMES_FIELD_TOOLTIP,
            "זמן ההתחלה יהיה זמן היציאה של המתנדב הראשון וזמן הסיום יהיה זמן העזיבה של המתנדב האחרון"
        )
        XCTAssertEqual(
            PATROL_CALLSIGN_FIELD_NOTE,
            "אתם מתבקשים להזין או\"ק מלא של הניידת כולל קידומת (אביב, חוף וכו')"
        )
        XCTAssertEqual(LOCATION_FIELD_NOTE, "חדש! הזנת כביש באופן אוטומטי מבוסס על המיקום הנבחר")
        XCTAssertEqual(MY_ACTIVE_EVENTS_TITLE, "האירועים הפעילים שלי")
        XCTAssertEqual(EVENT_ASSIGN_OPEN, "מתנדבים")
        XCTAssertEqual(EVENT_ASSIGN_CLOSE, "סגירת הקצאה")
        XCTAssertEqual(EVENT_ASSIGN_REMOVE, "הסרת מתנדב")
        XCTAssertEqual(EVENT_ASSIGN_REMOVE_CANCEL, "ביטול")
        XCTAssertEqual(eventResponderRemoveConfirm("דנה"), "האם אתה בטוח שברצונך להסיר את דנה?")
        XCTAssertEqual(eventResponderRemoveConfirm("  "), "האם אתה בטוח שברצונך להסיר את מתנדב?")
        XCTAssertEqual(EVENT_PATROL_CALLSIGN_LABEL, "אוק - מס")
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

    func testSameDayPoliceEventIdCollidesUnlessCancelledBlankOrAnotherDate() {
        let existing = [
            SameDayPoliceEventRow(id: "evt-1", eventDate: "2026-09-03", policeEventId: "12345"),
            SameDayPoliceEventRow(id: "evt-cancelled", isCancelled: true, eventDate: "2026-09-03", policeEventId: "99999"),
        ]
        XCTAssertTrue(sameDayPoliceEventIdCollides(eventDate: "2026-09-03", policeEventId: "12345", currentEventId: "evt-new", existing: existing))
        XCTAssertFalse(sameDayPoliceEventIdCollides(eventDate: "2026-09-04", policeEventId: "12345", currentEventId: "evt-new", existing: existing))
        XCTAssertFalse(sameDayPoliceEventIdCollides(eventDate: "2026-09-03", policeEventId: "", currentEventId: "evt-new", existing: existing))
        XCTAssertFalse(sameDayPoliceEventIdCollides(eventDate: "2026-09-03", policeEventId: "12345", currentEventId: "evt-1", existing: existing))
        XCTAssertFalse(sameDayPoliceEventIdCollides(eventDate: "2026-09-03", policeEventId: "99999", currentEventId: "evt-new", existing: existing))
        XCTAssertEqual(POLICE_EVENT_ID_DUPLICATE_ERROR, "כבר קיים אירוע עם המספר הזה באותו תאריך.")
    }

    func testDoneStaysOffTheEventRowUntilAssignedKmIsWritten() {
        XCTAssertEqual(eventStatusForRowWriteBeforeResponders(.done), .partial)
        XCTAssertEqual(eventStatusForRowWriteBeforeResponders(.partial), .partial)
        XCTAssertEqual(eventStatusForRowWriteBeforeResponders(.inProgress), .inProgress)
        XCTAssertEqual(eventStatusForRowWriteBeforeResponders(.draft), .draft)
    }

    func testPersistFailureMapsTheHebrewDoneGuardInsteadOfANetworkToast() {
        XCTAssertEqual(eventPersistFailure("P0001: \(EVENT_DONE_NEEDS_KM_ERROR)"), EVENT_DONE_NEEDS_KM_ERROR)
        XCTAssertEqual(eventPersistFailure(EVENT_DONE_NEEDS_END_ERROR), EVENT_DONE_NEEDS_END_ERROR)
        XCTAssertEqual(eventPersistFailure("permission denied"), EVENT_DRAFT_SAVE_FAILED)
        XCTAssertEqual(eventPersistFailure(nil), EVENT_DRAFT_SAVE_FAILED)
        XCTAssertEqual(EVENT_DONE_NEEDS_KM_ERROR, "לא ניתן להשלים אירוע לפני הזנת קילומטרים לכל הכוננים.")
        XCTAssertEqual(EVENT_DONE_NEEDS_END_ERROR, "לא ניתן להשלים אירוע ללא שעת סיום.")
    }

    func testKilometerEditDoesNotRewriteTheRestOfTheEvent() {
        var previous = draft()
        previous.policeEventId = "3207"
        previous.location = "מחלף גלילות"
        previous.notes = "רכב תקוע בנתיב"
        previous.startTime = "14:05"
        previous.shiftLeadId = "lead-1"
        previous.responders = [EventResponderDraft(responderId: "user-1", assignmentId: "a1", totalKm: "", hasVehicle: true)]
        var next = previous
        next.responders[0].totalKm = "42"

        let patch = changedPersistColumns(
            previous: eventPersistColumns(previous, districts: districts, mainLeadId: "lead-1"),
            next: eventPersistColumns(next, districts: districts, mainLeadId: "lead-1")
        )
        XCTAssertTrue(patch.isEmpty)
        XCTAssertEqual(
            responderLeadPatch(
                previous: previous.responders[0],
                next: next.responders[0],
                startedAt: "2026-10-12T14:05:00",
                endedAt: nil,
                previousStartedAt: "2026-10-12T14:05:00",
                previousEndedAt: nil
            ),
            ["total_km": .double(42)]
        )
        XCTAssertFalse(shouldRewriteTreatedVehicles(
            previous: [TreatedVehicleDraft(vehicleKindId: "car", quantity: 2)],
            next: [TreatedVehicleDraft(vehicleKindId: "car", quantity: 2)]
        ))
        XCTAssertFalse(shouldRewriteTreatedVehicles(previous: nil, next: []))
        XCTAssertTrue(shouldRewriteTreatedVehicles(previous: nil, next: [TreatedVehicleDraft(vehicleKindId: "car", quantity: 1)]))

        var emptied = previous
        emptied.location = ""
        emptied.notes = ""
        let cleared = changedPersistColumns(
            previous: eventPersistColumns(previous, districts: districts, mainLeadId: "lead-1"),
            next: eventPersistColumns(emptied, districts: districts, mainLeadId: "lead-1")
        )
        XCTAssertEqual(cleared["location"], .null)
        XCTAssertEqual(cleared["notes"], .null)
        XCTAssertNil(cleared["police_event_id"])
    }

    func testAddingAPendingResponderToADoneEventRewritesTheStatus() {
        var previous = draft()
        previous.responders = [EventResponderDraft(responderId: "r1", assignmentId: "a1", status: .done)]
        var next = previous
        next.responders.append(EventResponderDraft(responderId: "r2"))
        // Both sides persist as `partial`, so the plain column diff misses done → partial.
        let diff = changedPersistColumns(
            previous: eventPersistColumns(previous, districts: districts, mainLeadId: "lead"),
            next: eventPersistColumns(next, districts: districts, mainLeadId: "lead")
        )
        XCTAssertNil(diff["status"])
        XCTAssertEqual(
            eventPatchWithDerivedStatus(diff, previous: previous, next: next)["status"],
            .string(EventStatus.partial.rawValue)
        )
        XCTAssertNil(eventPatchWithDerivedStatus([:], previous: previous, next: previous)["status"])
        XCTAssertNil(eventPatchWithDerivedStatus([:], previous: nil, next: next)["status"])
    }

    func testOnlyAssignmentsThisFormRemovedAreDeleted() {
        let existing = [
            (id: "a1", responderId: "r1"),
            (id: "a2", responderId: "r2"),
            (id: "a3", responderId: "x-added-elsewhere"),
        ]
        XCTAssertEqual(
            assignmentIdsToRemove(existing: existing, keepResponderIds: ["r1"], previousResponderIds: ["r1", "r2"]),
            ["a2"]
        )
        XCTAssertEqual(
            assignmentIdsToRemove(existing: existing, keepResponderIds: ["r1"], previousResponderIds: nil),
            ["a2", "a3"]
        )
    }

    func testNewAssignmentWritesTheEventTimesAndLeadFields() {
        let row = EventResponderDraft(responderId: "r1", totalKm: "7", emergencyMeans: true, hasVehicle: true)
        XCTAssertEqual(
            responderLeadPatch(
                previous: nil,
                next: row,
                startedAt: "2026-10-12T14:05:00",
                endedAt: nil,
                previousStartedAt: nil,
                previousEndedAt: nil
            ),
            ["started_at": .string("2026-10-12T14:05:00"), "total_km": .double(7), "emergency_means": .bool(true)]
        )
    }

    func testSecondaryLeadsCompareByUserAndLock() {
        let a = SecondaryLead(userId: "u1", locked: false)
        XCTAssertTrue(secondaryLeadsUnchanged(previous: [a], next: [a]))
        XCTAssertFalse(secondaryLeadsUnchanged(previous: [a], next: [SecondaryLead(userId: "u1", locked: true)]))
        XCTAssertTrue(secondaryLeadsUnchanged(previous: nil, next: []))
        XCTAssertFalse(secondaryLeadsUnchanged(previous: nil, next: [a]))
    }

    func testOpeningANewEventIsNotDetailWorthSaving() {
        XCTAssertFalse(EventDraft(eventDate: "2026-10-12", startTime: "14:05").hasDetailBeyondOpen())
        XCTAssertTrue(EventDraft(eventDate: "2026-10-12", notes: "x").hasDetailBeyondOpen())
        XCTAssertTrue(EventDraft(eventDate: "2026-10-12", patrolCallsignNumber: "411").hasDetailBeyondOpen())
        XCTAssertTrue(EventDraft(eventDate: "2026-10-12", responders: [EventResponderDraft(responderId: "r")]).hasDetailBeyondOpen())
    }

    func testPersistedDraftKeepsANullEventEndDirtyWhenTheFormFellBackToAResponderTime() {
        var uiDraft = draft()
        uiDraft.eventDate = "16.10.2026"
        uiDraft.policeEventId = "8005"
        uiDraft.startTime = "18:53"
        uiDraft.endTime = "19:37"
        uiDraft.shiftLeadId = "lead-hila"
        let persisted = persistedEventDraftForRow(
            uiDraft: uiDraft,
            storedStartedAt: "2026-10-16T18:53:00",
            storedEndedAt: nil,
            responderStartedAts: ["2026-10-16T18:53:00"],
            shiftLeadId: "lead-hila"
        )
        XCTAssertEqual(persisted.endTime, "")
        XCTAssertNotEqual(persisted.forPersistCompare(), uiDraft.forPersistCompare())
        let patch = changedPersistColumns(
            previous: eventPersistColumns(persisted, districts: districts, mainLeadId: "lead-hila"),
            next: eventPersistColumns(uiDraft, districts: districts, mainLeadId: "lead-hila")
        )
        XCTAssertEqual(patch["ended_at"], .string("2026-10-16T19:37:00"))
    }

    func testPersistColumnsCarryTheSplitCallsignAndOvernightEnd() {
        var row = draft()
        row.patrolCallsignPrefix = " אביב "
        row.patrolCallsignNumber = "411"
        row.startTime = "23:30"
        row.endTime = "01:10"
        row.shiftLeadId = "lead-1"
        let columns = eventPersistColumns(row, districts: districts, mainLeadId: "lead-1")
        XCTAssertEqual(columns["patrol_callsign"], .string("אביב 411"))
        XCTAssertEqual(columns["patrol_callsign_prefix"], .string("אביב"))
        XCTAssertEqual(columns["patrol_callsign_number"], .string("411"))
        XCTAssertEqual(columns["started_at"], .string("2026-02-02T23:30:00"))
        XCTAssertEqual(columns["ended_at"], .string("2026-02-03T01:10:00"))
        XCTAssertEqual(columns["shift_lead_id"], .string("lead-1"))
        XCTAssertEqual(columns["road_id"], .string("road-6"))
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
