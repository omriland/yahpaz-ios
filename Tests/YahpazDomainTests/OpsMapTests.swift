import XCTest
@testable import YahpazDomain

final class OpsMapTests: XCTestCase {
    private func pin(
        userId: String = "u1",
        callsign: String = "336",
        kind: AddressKind = .home,
        lat: Double = 32.0,
        lng: Double = 34.8,
        status: VolunteerStatus = .activeVolunteer,
        availability: AvailabilityStatus = .available,
        availableFrom: String? = nil
    ) -> MapPin {
        MapPin(
            userId: userId,
            fullName: "Test",
            callsign: callsign,
            kind: kind,
            name: addressKindLabel(kind),
            label: mapPinLabel(callsign: callsign, kind: kind),
            formattedAddress: "Somewhere",
            lat: lat,
            lng: lng,
            volunteerStatus: status,
            availability: availability,
            availableFrom: availableFrom
        )
    }

    private func row(_ userId: String, _ status: VolunteerStatus, kind: AddressKind = .home) -> UnitMapPinRow {
        UnitMapPinRow(
            userId: userId,
            fullName: userId,
            callsign: userId,
            kind: kind,
            label: nil,
            formattedAddress: "x",
            lat: 32.0,
            lng: 34.8,
            volunteerStatus: status,
            availability: .available,
            availableFrom: nil
        )
    }

    func testMapPinsFromUnitRowsHidesAdminStatuses() {
        let pins = mapPinsFromUnitRows([
            row("a", .administration),
            row("b", .phoneTraining, kind: .work),
            row("c", .basicTraining),
            row("d", .shiftsOnly),
        ])
        XCTAssertEqual(pins.map(\.userId), ["b"])
        XCTAssertEqual(mapUserPinChrome(pins[0]).tone, .phone)
        XCTAssertEqual(pins[0].label, "b · עבודה")
    }

    func testNearbyPicksClosestAddressPerUserWithin30km() {
        let pins = [
            pin(userId: "u1", callsign: "A", lat: 32.0, lng: 34.8),
            pin(userId: "u1", callsign: "A", kind: .work, lat: 32.05, lng: 34.85),
            pin(userId: "u2", callsign: "B", lat: 33.5, lng: 35.5),
        ]
        let nearby = nearbyResponders(pins, originLat: 32.0, originLng: 34.8, maxKm: 30)
        XCTAssertEqual(nearby.map(\.userId), ["u1"])
        XCTAssertEqual(nearby[0].kind, .home)
    }

    func testCatalogClustersAtLowZoomAndShowsPointsWhenZoomedIn() {
        let pins = [
            pin(userId: "1", lat: 32.00, lng: 34.80),
            pin(userId: "2", lat: 32.001, lng: 34.801),
            pin(userId: "3", lat: 33.0, lng: 35.0),
        ]
        let low = catalogViewForViewport(pins, bbox: ISRAEL_VIEW_BBOX, zoom: 8)
        XCTAssertTrue(low.clusters.contains { $0.count >= 2 })
        XCTAssertEqual(low.points.count + low.clusters.reduce(0) { $0 + $1.count }, pins.count)
        let high = catalogViewForViewport(pins, bbox: ISRAEL_VIEW_BBOX, zoom: 11)
        XCTAssertTrue(high.clusters.isEmpty)
        XCTAssertEqual(high.points.count, 3)
        XCTAssertEqual(zoomAfterCatalogClusterClick(8), 11)
        XCTAssertEqual(zoomAfterCatalogClusterClick(10), 12)
    }

    func testMilePostVisibilityGates() {
        XCTAssertFalse(shouldShowMilePosts(layerOn: true, zoom: 13, inViewCount: 10))
        XCTAssertTrue(shouldShowMilePosts(layerOn: true, zoom: 14, inViewCount: 10))
        XCTAssertFalse(shouldShowMilePosts(layerOn: true, zoom: 14, inViewCount: 401))
        XCTAssertTrue(shouldShowMilePosts(layerOn: true, zoom: 15, inViewCount: 401))
        XCTAssertFalse(shouldShowMilePosts(layerOn: false, zoom: 15, inViewCount: 10))
        XCTAssertEqual(milePostTooltip(MilePost(road: "6", km: 120, lat: 0, lng: 0)), "כביש 6 · ק״מ 120")
    }

    func testLivePinFreshness() {
        let at: Int64 = 1_788_670_800_000 // 2026-09-06T05:00:00Z
        XCTAssertTrue(isLivePinFresh(recordedAt: "2026-09-06T05:00:00Z", nowMs: at + LIVE_PIN_STALE_AFTER_MS))
        XCTAssertFalse(isLivePinFresh(recordedAt: "2026-09-06T05:00:00Z", nowMs: at + LIVE_PIN_STALE_AFTER_MS + 1))
        XCTAssertTrue(isLivePinFresh(recordedAt: "2026-09-06T05:00:00.250+00:00", nowMs: at + 1_000))
        XCTAssertFalse(isLivePinFresh(recordedAt: "garbage", nowMs: at))
    }

    func testUnavailableChrome() {
        let chrome = mapUserPinChrome(
            pin(availability: .unavailable, availableFrom: "2026-09-10"),
            today: "2026-09-06"
        )
        XCTAssertTrue(chrome.unavailable)
        XCTAssertEqual(chrome.tooltip, "לא זמין עד 10.09.2026")
        XCTAssertNil(mapAvailabilityHoverLabel(.available, availableFrom: nil, today: "2026-09-06"))
        XCTAssertEqual(mapUserPinChrome(pin(), today: "2026-09-06").tooltip, "מתנדב פעיל")
    }

    func testLegendCopyMatchesVolunteerStatuses() {
        XCTAssertEqual(MAP_LEGEND_ACTIVE, "מתנדב פעיל / חניכה ברכב פרטי")
        XCTAssertEqual(MAP_LEGEND_PHONE, "חניכה טלפונית")
        XCTAssertEqual(MAP_LEGEND_UNAVAILABLE, "לא זמין")
    }

    func testResponderPinLabelAndZoomGate() {
        XCTAssertEqual(mapResponderPinLabel(callsign: "336", fullName: "עמרי"), "336 · עמרי")
        XCTAssertEqual(mapResponderPinLabel(callsign: "336", fullName: "  "), "336")
        XCTAssertEqual(mapResponderPinLabel(callsign: "", fullName: ""), "מתנדב")
        XCTAssertFalse(shouldShowMapPinLabels(zoom: 11.9))
        XCTAssertTrue(shouldShowMapPinLabels(zoom: 12))
    }

    func testDistanceCopyAndRadiusBounds() {
        XCTAssertEqual(formatMapDistanceKm(0.42), "420 מ׳")
        XCTAssertEqual(formatMapDistanceKm(12.34), "12.3 ק״מ")
        let bounds = mapBoundsForRadiusKm(lat: 32.0, lng: 34.8, radiusKm: SEARCH_VIEW_RADIUS_KM)
        XCTAssertEqual(bounds.north - bounds.south, 2 * 30 / 111.32, accuracy: 1e-9)
        XCTAssertGreaterThan(bounds.east - bounds.west, bounds.north - bounds.south)
        XCTAssertEqual(haversineKm(lat1: 32, lng1: 34.8, lat2: 32, lng2: 34.8), 0, accuracy: 1e-9)
    }

    func testLiveLabelsAndEventLine() {
        XCTAssertEqual(livePinLabel(callsign: "336", fullName: "עמרי"), "336 · בדרך")
        XCTAssertEqual(livePinLabel(callsign: nil, fullName: "עמרי"), "עמרי · בדרך")
        XCTAssertEqual(liveEventLine(eventType: "תקר", road: "כביש 6 (6)", location: "מחלף גלילות"), "תקר · 6 מחלף גלילות")
        XCTAssertEqual(liveEventLine(eventType: nil, road: nil, location: nil), nil)
        XCTAssertEqual(livePinTooltip(eventLine: "תקר", recordedAtClock: "08:10"), "תקר · 08:10")
        XCTAssertEqual(livePinTooltip(eventLine: nil, recordedAtClock: "08:10"), "08:10")
    }
}
