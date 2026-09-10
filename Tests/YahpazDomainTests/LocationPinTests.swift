import XCTest
@testable import YahpazDomain

final class LocationPinTests: XCTestCase {
    func testHumanAndJunctionPinsAreLocked() {
        XCTAssertTrue(locationPinIsLocked("shift_lead"))
        XCTAssertTrue(locationPinIsLocked("responder"))
        XCTAssertTrue(locationPinIsLocked("junction"))
        XCTAssertFalse(locationPinIsLocked("places"))
        XCTAssertFalse(locationPinIsLocked("geocode"))
        XCTAssertFalse(locationPinIsLocked(nil))
    }

    func testFormatLocationCoords() {
        XCTAssertEqual(formatLocationCoords(lat: 32.0741234, lng: 34.7920199), "32.07412, 34.79202")
    }

    func testApplyLeadMapPinKeepsLocationText() {
        let next = applyLeadMapPin(
            LocationPinFields(
                location: "מחלף השלום",
                locationPlaceId: "ChIJx",
                locationLat: 32.1,
                locationLng: 34.8,
                locationPinSource: "places"
            ),
            lat: 32.07,
            lng: 34.79,
            userId: "lead-1",
            at: "2026-08-24T07:00:00.000Z"
        )
        XCTAssertEqual(next.location, "מחלף השלום")
        XCTAssertNil(next.locationPlaceId)
        XCTAssertEqual(next.locationLat, 32.07)
        XCTAssertEqual(next.locationLng, 34.79)
        XCTAssertEqual(next.locationPinSource, "shift_lead")
        XCTAssertEqual(next.locationPinnedAt, "2026-08-24T07:00:00.000Z")
        XCTAssertEqual(next.locationPinnedBy, "lead-1")
    }

    func testLockedPinSurvivesTextEdit() {
        let locked = LocationPinFields(
            location: "מחלף",
            locationLat: 32.07,
            locationLng: 34.79,
            locationPinSource: "shift_lead",
            locationPinnedAt: "2026-08-24T07:00:00.000Z",
            locationPinnedBy: "lead-1"
        )
        let next = applyLocationFieldChange(
            locked,
            next: LocationFieldChange(location: "מחלף השלום צפון")
        )
        XCTAssertEqual(next.location, "מחלף השלום צפון")
        XCTAssertEqual(next.locationLat, 32.07)
        XCTAssertEqual(next.locationLng, 34.79)
        XCTAssertEqual(next.locationPinSource, "shift_lead")
        XCTAssertNil(next.locationPlaceId)
    }

    func testGooglePlaceReplacesALockedPin() {
        let next = applyLocationFieldChange(
            LocationPinFields(
                location: "מחלף",
                locationLat: 32.07,
                locationLng: 34.79,
                locationPinSource: "shift_lead",
                locationPinnedAt: "2026-08-24T07:00:00.000Z",
                locationPinnedBy: "lead-1"
            ),
            next: LocationFieldChange(
                location: "צומת גלילות",
                locationPlaceId: "ChIJx",
                locationLat: 32.14,
                locationLng: 34.81
            )
        )
        XCTAssertEqual(next.locationPinSource, "places")
        XCTAssertEqual(next.locationPlaceId, "ChIJx")
        XCTAssertEqual(next.locationLat, 32.14)
        XCTAssertNil(next.locationPinnedAt)
    }

    func testJunctionPickIsTaggedDistinctly() {
        let next = applyLocationFieldChange(
            LocationPinFields(),
            next: LocationFieldChange(
                location: "צומת מסובים",
                locationPlaceId: "junction:11111111-1111-1111-1111-111111111111",
                locationLat: 31.6,
                locationLng: 34.7
            )
        )
        XCTAssertEqual(next.locationPinSource, "junction")
        XCTAssertEqual(next.locationPlaceId, "junction:11111111-1111-1111-1111-111111111111")
        XCTAssertEqual(next.locationLat, 31.6)
        XCTAssertEqual(next.locationLng, 34.7)
    }

    func testClearLockedLocationPin() {
        let next = clearLockedLocationPin(
            LocationPinFields(
                location: "מחלף השלום",
                locationLat: 32.07,
                locationLng: 34.79,
                locationPinSource: "shift_lead",
                locationPinnedAt: "2026-08-24T07:00:00.000Z",
                locationPinnedBy: "lead-1"
            )
        )
        XCTAssertEqual(next.location, "מחלף השלום")
        XCTAssertNil(next.locationLat)
        XCTAssertNil(next.locationPinSource)
    }

    func testBuildLocationPayloadNullsJunctionPlaceId() {
        let payload = buildLocationPayload(
            EventDraft(
                eventDate: "2026-02-02",
                eventTypeId: "t1",
                roadId: "r1",
                location: "צומת מסובים",
                locationPlaceId: "junction:11111111-1111-1111-1111-111111111111",
                locationLat: 31.6,
                locationLng: 34.7,
                locationPinSource: "junction"
            )
        )
        XCTAssertEqual(payload.location, "צומת מסובים")
        XCTAssertNil(payload.locationPlaceId)
        XCTAssertEqual(payload.locationLat, 31.6)
        XCTAssertEqual(payload.locationLng, 34.7)
        XCTAssertEqual(payload.locationPinSource, "junction")
    }

    func testBuildLocationPayloadKeepsGooglePlace() {
        let payload = buildLocationPayload(
            EventDraft(
                eventDate: "2026-02-02",
                location: "צומת גלילות",
                locationPlaceId: "ChIJx",
                locationLat: 32.1,
                locationLng: 34.8
            )
        )
        XCTAssertEqual(payload.locationPlaceId, "ChIJx")
        XCTAssertEqual(payload.locationPinSource, "places")
    }

    func testBuildLocationPayloadClearsFreeTextCoords() {
        let payload = buildLocationPayload(
            EventDraft(eventDate: "2026-02-02", location: "משהו לא רשמי")
        )
        XCTAssertEqual(payload.location, "משהו לא רשמי")
        XCTAssertNil(payload.locationPlaceId)
        XCTAssertNil(payload.locationLat)
        XCTAssertNil(payload.locationPinSource)
    }

    func testBuildLocationPayloadKeepsLockedPinWithoutText() {
        let payload = buildLocationPayload(
            EventDraft(
                eventDate: "2026-02-02",
                location: "  ",
                locationLat: 32.07,
                locationLng: 34.79,
                locationPinSource: "shift_lead",
                locationPinnedAt: "2026-08-24T07:00:00.000Z",
                locationPinnedBy: "lead-1"
            )
        )
        XCTAssertNil(payload.location)
        XCTAssertEqual(payload.locationLat, 32.07)
        XCTAssertEqual(payload.locationPinSource, "shift_lead")
    }
}
