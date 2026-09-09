import Foundation

public let LOCATION_PIN_SOURCES = ["places", "geocode", "shift_lead", "responder", "junction"]

public struct LocationPinFields: Equatable, Sendable {
    public var location: String
    public var locationPlaceId: String?
    public var locationLat: Double?
    public var locationLng: Double?
    public var locationPinSource: String?
    public var locationPinnedAt: String?
    public var locationPinnedBy: String?

    public init(
        location: String = "",
        locationPlaceId: String? = nil,
        locationLat: Double? = nil,
        locationLng: Double? = nil,
        locationPinSource: String? = nil,
        locationPinnedAt: String? = nil,
        locationPinnedBy: String? = nil
    ) {
        self.location = location
        self.locationPlaceId = locationPlaceId
        self.locationLat = locationLat
        self.locationLng = locationLng
        self.locationPinSource = locationPinSource
        self.locationPinnedAt = locationPinnedAt
        self.locationPinnedBy = locationPinnedBy
    }
}

public struct LocationFieldChange: Equatable, Sendable {
    public var location: String
    public var locationPlaceId: String?
    public var locationLat: Double?
    public var locationLng: Double?

    public init(
        location: String,
        locationPlaceId: String? = nil,
        locationLat: Double? = nil,
        locationLng: Double? = nil
    ) {
        self.location = location
        self.locationPlaceId = locationPlaceId
        self.locationLat = locationLat
        self.locationLng = locationLng
    }
}

public struct LocationPersistPayload: Equatable, Sendable {
    public var location: String?
    public var locationPlaceId: String?
    public var locationLat: Double?
    public var locationLng: Double?
    public var locationPinSource: String?
    public var locationPinnedAt: String?
    public var locationPinnedBy: String?
}

private let lockedSources: Set<String> = ["shift_lead", "responder", "junction"]

public func locationPinIsLocked(_ source: String?) -> Bool {
    guard let source else { return false }
    return lockedSources.contains(source)
}

public func formatLocationCoords(lat: Double, lng: Double) -> String {
    String(format: "%.5f, %.5f", lat, lng)
}

public func emptyLocationPinMeta() -> (locationPinSource: String?, locationPinnedAt: String?, locationPinnedBy: String?) {
    (nil, nil, nil)
}

public func applyLeadMapPin(
    _ current: LocationPinFields,
    lat: Double,
    lng: Double,
    userId: String,
    at: String
) -> LocationPinFields {
    LocationPinFields(
        location: current.location,
        locationPlaceId: nil,
        locationLat: lat,
        locationLng: lng,
        locationPinSource: "shift_lead",
        locationPinnedAt: at,
        locationPinnedBy: userId
    )
}

public func clearLockedLocationPin(_ current: LocationPinFields) -> LocationPinFields {
    LocationPinFields(location: current.location)
}

public func applyLocationFieldChange(
    _ current: LocationPinFields,
    next: LocationFieldChange
) -> LocationPinFields {
    let pickedJunction =
        (next.locationPlaceId?.hasPrefix(JUNCTION_PLACE_ID_PREFIX) ?? false)
        && next.locationLat != nil
        && next.locationLng != nil
    if pickedJunction {
        return LocationPinFields(
            location: next.location,
            locationPlaceId: next.locationPlaceId,
            locationLat: next.locationLat,
            locationLng: next.locationLng,
            locationPinSource: "junction"
        )
    }
    let pickedPlace =
        !(next.locationPlaceId ?? "").isEmpty
        && next.locationLat != nil
        && next.locationLng != nil
    if pickedPlace {
        return LocationPinFields(
            location: next.location,
            locationPlaceId: next.locationPlaceId,
            locationLat: next.locationLat,
            locationLng: next.locationLng,
            locationPinSource: "places"
        )
    }
    if locationPinIsLocked(current.locationPinSource) {
        var kept = current
        kept.location = next.location
        kept.locationPlaceId = nil
        return kept
    }
    return LocationPinFields(
        location: next.location,
        locationPlaceId: next.locationPlaceId,
        locationLat: next.locationLat,
        locationLng: next.locationLng
    )
}

public func buildLocationPayload(_ draft: EventDraft) -> LocationPersistPayload {
    let location = draft.location.trimmingCharacters(in: .whitespacesAndNewlines)
    let locationOrNil = location.isEmpty ? nil : location
    let locked = locationPinIsLocked(draft.locationPinSource)
    let hasCoords = draft.locationLat != nil && draft.locationLng != nil

    if locationOrNil == nil && !locked {
        return LocationPersistPayload(
            location: nil,
            locationPlaceId: nil,
            locationLat: nil,
            locationLng: nil,
            locationPinSource: nil,
            locationPinnedAt: nil,
            locationPinnedBy: nil
        )
    }

    if locked && hasCoords {
        return LocationPersistPayload(
            location: locationOrNil,
            locationPlaceId: nil,
            locationLat: draft.locationLat,
            locationLng: draft.locationLng,
            locationPinSource: draft.locationPinSource,
            locationPinnedAt: draft.locationPinnedAt,
            locationPinnedBy: draft.locationPinnedBy
        )
    }

    let hasPlace = !(draft.locationPlaceId ?? "").isEmpty && hasCoords
    if hasPlace {
        return LocationPersistPayload(
            location: locationOrNil,
            locationPlaceId: draft.locationPlaceId,
            locationLat: draft.locationLat,
            locationLng: draft.locationLng,
            locationPinSource: "places",
            locationPinnedAt: nil,
            locationPinnedBy: nil
        )
    }

    if draft.locationPinSource == "geocode" && hasCoords {
        return LocationPersistPayload(
            location: locationOrNil,
            locationPlaceId: nil,
            locationLat: draft.locationLat,
            locationLng: draft.locationLng,
            locationPinSource: "geocode",
            locationPinnedAt: nil,
            locationPinnedBy: nil
        )
    }

    return LocationPersistPayload(
        location: locationOrNil,
        locationPlaceId: nil,
        locationLat: nil,
        locationLng: nil,
        locationPinSource: nil,
        locationPinnedAt: nil,
        locationPinnedBy: nil
    )
}
