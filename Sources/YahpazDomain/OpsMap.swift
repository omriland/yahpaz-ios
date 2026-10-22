import Foundation

/// Port of Android `OpsMap.kt` (web `opsMap`): unit address pins, nearby search,
/// clustering, mile posts, and live en-route pins for the מפה tab.

public enum AddressKind: String, Sendable, Hashable {
    case home
    case work
    case other

    public static func fromRaw(_ raw: String?) -> AddressKind {
        raw.flatMap(AddressKind.init(rawValue:)) ?? .other
    }
}

public let ADDRESS_KIND_LABELS: [AddressKind: String] = [
    .home: "בית",
    .work: "עבודה",
    .other: "אחר",
]

public func addressKindLabel(_ kind: AddressKind, customLabel: String? = nil) -> String {
    if kind == .other {
        let trimmed = customLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty { return trimmed }
    }
    return ADDRESS_KIND_LABELS[kind] ?? ""
}

public struct UnitMapPinRow: Equatable, Sendable {
    public var userId: String
    public var fullName: String
    public var callsign: String
    public var kind: AddressKind
    public var label: String?
    public var formattedAddress: String
    public var lat: Double
    public var lng: Double
    public var volunteerStatus: VolunteerStatus
    public var availability: AvailabilityStatus
    public var availableFrom: String?

    public init(
        userId: String,
        fullName: String,
        callsign: String,
        kind: AddressKind,
        label: String?,
        formattedAddress: String,
        lat: Double,
        lng: Double,
        volunteerStatus: VolunteerStatus,
        availability: AvailabilityStatus,
        availableFrom: String?
    ) {
        self.userId = userId
        self.fullName = fullName
        self.callsign = callsign
        self.kind = kind
        self.label = label
        self.formattedAddress = formattedAddress
        self.lat = lat
        self.lng = lng
        self.volunteerStatus = volunteerStatus
        self.availability = availability
        self.availableFrom = availableFrom
    }
}

public struct MapPin: Equatable, Sendable, Identifiable {
    public var userId: String
    public var fullName: String
    public var callsign: String
    public var kind: AddressKind
    public var name: String
    public var label: String
    public var formattedAddress: String
    public var lat: Double
    public var lng: Double
    public var volunteerStatus: VolunteerStatus
    public var availability: AvailabilityStatus
    public var availableFrom: String?

    public var id: String { "\(userId):\(kind.rawValue):\(lat):\(lng)" }

    public init(
        userId: String,
        fullName: String,
        callsign: String,
        kind: AddressKind,
        name: String,
        label: String,
        formattedAddress: String,
        lat: Double,
        lng: Double,
        volunteerStatus: VolunteerStatus,
        availability: AvailabilityStatus,
        availableFrom: String?
    ) {
        self.userId = userId
        self.fullName = fullName
        self.callsign = callsign
        self.kind = kind
        self.name = name
        self.label = label
        self.formattedAddress = formattedAddress
        self.lat = lat
        self.lng = lng
        self.volunteerStatus = volunteerStatus
        self.availability = availability
        self.availableFrom = availableFrom
    }
}

public func mapPinLabel(callsign: String, kind: AddressKind, customLabel: String? = nil) -> String {
    "\(callsign) · \(addressKindLabel(kind, customLabel: customLabel))"
}

/// Visible map chrome: אבן דרך (או״ק) + responder name.
public func mapResponderPinLabel(callsign: String, fullName: String) -> String {
    let cs = callsign.trimmingCharacters(in: .whitespacesAndNewlines)
    let name = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
    switch (cs.isEmpty, name.isEmpty) {
    case (false, false): return "\(cs) · \(name)"
    case (false, true): return cs
    case (true, false): return name
    case (true, true): return "מתנדב"
    }
}

/// Show name/או״ק chips once pins are unclustered and readable.
public let MAP_PIN_LABEL_MIN_ZOOM = 12.0

public func shouldShowMapPinLabels(zoom: Double) -> Bool {
    zoom >= MAP_PIN_LABEL_MIN_ZOOM
}

public func isMapVisibleVolunteerStatus(_ status: VolunteerStatus) -> Bool {
    status != .administration && status != .basicTraining && status != .shiftsOnly
}

public func mapAvailabilityHoverLabel(
    _ status: AvailabilityStatus,
    availableFrom: String?,
    today: String = israelToday()
) -> String? {
    if effectiveAvailability(status, availableFrom: availableFrom, today: today) != .unavailable {
        return nil
    }
    if let availableFrom, !availableFrom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return "לא זמין עד \(formatDate(availableFrom))"
    }
    return AVAILABILITY_LABELS[.unavailable]
}

public enum MapUserPinTone: Sendable {
    case volunteer
    case phone
}

public struct MapUserPinChrome: Equatable, Sendable {
    public var unavailable: Bool
    public var tone: MapUserPinTone
    public var tooltip: String
}

public func mapUserPinChrome(_ pin: MapPin, today: String = israelToday()) -> MapUserPinChrome {
    let tone: MapUserPinTone = pin.volunteerStatus == .phoneTraining ? .phone : .volunteer
    if let hover = mapAvailabilityHoverLabel(pin.availability, availableFrom: pin.availableFrom, today: today) {
        return MapUserPinChrome(unavailable: true, tone: tone, tooltip: hover)
    }
    return MapUserPinChrome(
        unavailable: false,
        tone: tone,
        tooltip: VOLUNTEER_STATUS_LABELS[pin.volunteerStatus] ?? ""
    )
}

public func mapPinsFromUnitRows(_ rows: [UnitMapPinRow]) -> [MapPin] {
    rows.compactMap { row in
        guard isMapVisibleVolunteerStatus(row.volunteerStatus) else { return nil }
        return MapPin(
            userId: row.userId,
            fullName: row.fullName,
            callsign: row.callsign,
            kind: row.kind,
            name: addressKindLabel(row.kind, customLabel: row.label),
            label: mapPinLabel(callsign: row.callsign, kind: row.kind, customLabel: row.label),
            formattedAddress: row.formattedAddress,
            lat: row.lat,
            lng: row.lng,
            volunteerStatus: row.volunteerStatus,
            availability: row.availability,
            availableFrom: row.availableFrom
        )
    }
}

public struct NearbyResponder: Equatable, Sendable, Identifiable {
    public var userId: String
    public var fullName: String
    public var callsign: String
    public var kind: AddressKind
    public var name: String
    public var formattedAddress: String
    public var lat: Double
    public var lng: Double
    public var km: Double

    public var id: String { userId }
}

public let SEARCH_VIEW_RADIUS_KM = 30.0
private let KM_PER_DEG_LAT = 111.32

public func haversineKm(lat1: Double, lng1: Double, lat2: Double, lng2: Double) -> Double {
    func toRad(_ deg: Double) -> Double { deg * .pi / 180 }
    let dLat = toRad(lat2 - lat1)
    let dLng = toRad(lng2 - lng1)
    let a = sin(dLat / 2) * sin(dLat / 2)
        + cos(toRad(lat1)) * cos(toRad(lat2)) * sin(dLng / 2) * sin(dLng / 2)
    return 6371 * 2 * atan2(sqrt(a), sqrt(1 - a))
}

public func formatMapDistanceKm(_ km: Double) -> String {
    if km < 1 {
        return "\(formatNumber(Int((km * 1000).rounded()))) מ׳"
    }
    return "\(formatNumber((km * 10).rounded() / 10)) ק״מ"
}

public struct LatLngBbox: Equatable, Sendable {
    public var south: Double
    public var west: Double
    public var north: Double
    public var east: Double

    public init(south: Double, west: Double, north: Double, east: Double) {
        self.south = south
        self.west = west
        self.north = north
        self.east = east
    }
}

public func mapBoundsForRadiusKm(lat: Double, lng: Double, radiusKm: Double) -> LatLngBbox {
    let dLat = radiusKm / KM_PER_DEG_LAT
    let cosLat = cos(lat * .pi / 180)
    let dLng = radiusKm / (KM_PER_DEG_LAT * max(abs(cosLat), 0.01))
    return LatLngBbox(south: lat - dLat, west: lng - dLng, north: lat + dLat, east: lng + dLng)
}

public func nearbyResponders(
    _ pins: [MapPin],
    originLat: Double,
    originLng: Double,
    maxKm: Double = SEARCH_VIEW_RADIUS_KM
) -> [NearbyResponder] {
    var best: [String: NearbyResponder] = [:]
    for pin in pins {
        let km = haversineKm(lat1: originLat, lng1: originLng, lat2: pin.lat, lng2: pin.lng)
        if km > maxKm { continue }
        if let current = best[pin.userId], current.km <= km { continue }
        best[pin.userId] = NearbyResponder(
            userId: pin.userId,
            fullName: pin.fullName,
            callsign: pin.callsign,
            kind: pin.kind,
            name: pin.name,
            formattedAddress: pin.formattedAddress,
            lat: pin.lat,
            lng: pin.lng,
            km: km
        )
    }
    return best.values.sorted { lhs, rhs in
        lhs.km != rhs.km ? lhs.km < rhs.km : lhs.callsign < rhs.callsign
    }
}

public let CATALOG_CLUSTER_MAX_ZOOM = 10.0
public let VIEWPORT_PAD = 0.25

public struct CatalogCluster: Equatable, Sendable, Identifiable {
    public var key: String
    public var lat: Double
    public var lng: Double
    public var count: Int

    public var id: String { key }
}

public func padBbox(_ bbox: LatLngBbox, pad: Double = VIEWPORT_PAD) -> LatLngBbox {
    let latSpan = bbox.north - bbox.south
    let lngSpan = bbox.east - bbox.west
    return LatLngBbox(
        south: bbox.south - latSpan * pad,
        west: bbox.west - lngSpan * pad,
        north: bbox.north + latSpan * pad,
        east: bbox.east + lngSpan * pad
    )
}

public func pointInBbox(lat: Double, lng: Double, bbox: LatLngBbox) -> Bool {
    lat >= bbox.south && lat <= bbox.north && lng >= bbox.west && lng <= bbox.east
}

public func shouldClusterCatalog(zoom: Double) -> Bool {
    zoom <= CATALOG_CLUSTER_MAX_ZOOM
}

public func zoomAfterCatalogClusterClick(_ currentZoom: Double) -> Double {
    max(CATALOG_CLUSTER_MAX_ZOOM + 1, currentZoom + 2)
}

public func catalogCellDegrees(zoom: Double) -> Double {
    (360.0 / 256.0 / pow(2.0, zoom)) * 64.0
}

public func catalogViewForViewport(
    _ pins: [MapPin],
    bbox: LatLngBbox,
    zoom: Double
) -> (clusters: [CatalogCluster], points: [MapPin]) {
    let padded = padBbox(bbox)
    let inView = pins.filter { pointInBbox(lat: $0.lat, lng: $0.lng, bbox: padded) }
    if !shouldClusterCatalog(zoom: zoom) { return ([], inView) }
    let cell = catalogCellDegrees(zoom: zoom)
    var order: [String] = []
    var buckets: [String: [MapPin]] = [:]
    for pin in inView {
        let key = "\(Int(floor(pin.lat / cell))):\(Int(floor(pin.lng / cell)))"
        if buckets[key] == nil { order.append(key) }
        buckets[key, default: []].append(pin)
    }
    var clusters: [CatalogCluster] = []
    var points: [MapPin] = []
    for key in order {
        let group = buckets[key] ?? []
        if group.count == 1 {
            points.append(group[0])
        } else {
            clusters.append(CatalogCluster(
                key: key,
                lat: group.map(\.lat).reduce(0, +) / Double(group.count),
                lng: group.map(\.lng).reduce(0, +) / Double(group.count),
                count: group.count
            ))
        }
    }
    return (clusters, points)
}

public let ISRAEL_VIEW_BBOX = LatLngBbox(south: 29.4, west: 34.2, north: 33.4, east: 35.9)
public let ISRAEL_MAP_LAT = 31.5
public let ISRAEL_MAP_LNG = 34.85
public let ISRAEL_MAP_ZOOM = 8.0

public struct MilePost: Equatable, Sendable, Decodable {
    public var road: String
    public var km: Int
    public var lat: Double
    public var lng: Double

    public init(road: String, km: Int, lat: Double, lng: Double) {
        self.road = road
        self.km = km
        self.lat = lat
        self.lng = lng
    }
}

public let MILE_POST_MIN_ZOOM = 14.0
public let MILE_POST_DENSE_ZOOM = 15.0
public let MILE_POST_VIEW_CAP = 400
public let MILE_POST_LAYER_LOAD_ERROR = "טעינת השכבה נכשלה. בדקו את החיבור ונסו שוב."

public func milePostTooltip(_ post: MilePost) -> String {
    "כביש \(post.road) · ק״מ \(formatNumber(post.km))"
}

public func shouldShowMilePosts(layerOn: Bool, zoom: Double, inViewCount: Int) -> Bool {
    if !layerOn || inViewCount <= 0 { return false }
    if zoom < MILE_POST_MIN_ZOOM { return false }
    if inViewCount > MILE_POST_VIEW_CAP && zoom < MILE_POST_DENSE_ZOOM { return false }
    return true
}

public func milePostsInView(_ posts: [MilePost], bbox: LatLngBbox) -> [MilePost] {
    let padded = padBbox(bbox)
    return posts.filter { pointInBbox(lat: $0.lat, lng: $0.lng, bbox: padded) }
}

public struct OpsMapLayers: Equatable, Sendable {
    public var policeStations: Bool = false
    public var milePosts: Bool = true

    public init(policeStations: Bool = false, milePosts: Bool = true) {
        self.policeStations = policeStations
        self.milePosts = milePosts
    }
}

public let LIVE_PIN_STALE_AFTER_MS: Int64 = 30_000
public let LIVE_MAP_POLL_MS: Int64 = 5_000

public struct LiveMapPin: Equatable, Sendable, Identifiable {
    public var assignmentId: String
    public var lat: Double
    public var lng: Double
    public var label: String
    public var tooltip: String
    public var recordedAt: String

    public var id: String { assignmentId }

    public init(assignmentId: String, lat: Double, lng: Double, label: String, tooltip: String, recordedAt: String) {
        self.assignmentId = assignmentId
        self.lat = lat
        self.lng = lng
        self.label = label
        self.tooltip = tooltip
        self.recordedAt = recordedAt
    }
}

public func isLivePinFresh(recordedAt: String, nowMs: Int64) -> Bool {
    guard let at = parseInstantMs(recordedAt) else { return false }
    return nowMs - at <= LIVE_PIN_STALE_AFTER_MS
}

public func freshLivePins(_ pins: [LiveMapPin], nowMs: Int64) -> [LiveMapPin] {
    pins.filter { isLivePinFresh(recordedAt: $0.recordedAt, nowMs: nowMs) }
}

public func livePinLabel(callsign: String?, fullName: String) -> String {
    let cs = callsign?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let name = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
    let who = !cs.isEmpty ? cs : (name.isEmpty ? "מתנדב" : name)
    return "\(who) · בדרך"
}

public func liveEventLine(eventType: String?, road: String?, location: String?) -> String? {
    let typeName = eventType?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let roadName = road?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let place = location?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    func firstMatch(_ pattern: String, group: Int) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: roadName, range: NSRange(roadName.startIndex..., in: roadName)),
              let range = Range(match.range(at: group), in: roadName)
        else { return nil }
        return String(roadName[range])
    }
    let roadBit = firstMatch(#"\((\d+)\)"#, group: 1) ?? firstMatch(#"\d+"#, group: 0) ?? roadName
    let placePart: String
    if !place.isEmpty && !roadBit.isEmpty && (place.hasPrefix(roadBit) || place.contains(" \(roadBit) ")) {
        placePart = place
    } else {
        placePart = [roadBit, place].filter { !$0.isEmpty }.joined(separator: " ")
    }
    switch (typeName.isEmpty, placePart.isEmpty) {
    case (false, false): return "\(typeName) · \(placePart)"
    case (false, true): return typeName
    case (true, false): return placePart
    case (true, true): return nil
    }
}

public func livePinTooltip(eventLine: String?, recordedAtClock: String) -> String {
    let line = eventLine?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return line.isEmpty ? recordedAtClock : "\(line) · \(recordedAtClock)"
}

public let MAP_UNAVAILABLE_TITLE = "המפה אינה זמינה"
public let MAP_SEARCH_PLACEHOLDER = "חיפוש כתובת"
public let MAP_NEARBY_TITLE = "מתנדבים קרובים"
public let MAP_NEARBY_EMPTY = "אין מתנדבים בטווח 30 ק״מ"
public let MAP_LAYERS_TITLE = "שכבות מפה"
public let MAP_LAYER_POLICE = "תחנות משטרה"
public let MAP_LAYER_MILE_POSTS = "אבני קילומטר"
public let MAP_LEGEND_ACTIVE = "מתנדב פעיל / חניכה ברכב פרטי"
public let MAP_LEGEND_PHONE = "חניכה טלפונית"
public let MAP_LEGEND_UNAVAILABLE = "לא זמין"
public let MAP_TITLE = "מפה"
public let MAP_CAPTION = "חפשו כתובת כדי לראות מי המתנדבים הקרובים. כל סיכה היא כתובת אחת של משתמש פעיל."
/// Android names Google; iOS search runs on Apple Maps, so the copy names the list.
public let MAP_PLACES_ONLY_ERROR = "יש לבחור כתובת מהרשימה."
public let MAP_LOAD_FAILED = "טעינת המפה נכשלה."
