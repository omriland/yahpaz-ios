import Foundation

public struct LatLngAt: Equatable, Sendable {
    public var lat: Double
    public var lng: Double
    public var atMs: Int64

    public init(lat: Double, lng: Double, atMs: Int64) {
        self.lat = lat
        self.lng = lng
        self.atMs = atMs
    }
}

public let LIVE_PING_MIN_INTERVAL_MS: Int64 = 10_000
public let LIVE_PING_MIN_MOVE_M = 50.0

public func shouldEmitPing(last: LatLngAt?, next: LatLngAt) -> Bool {
    guard let last else { return true }
    if next.atMs - last.atMs >= LIVE_PING_MIN_INTERVAL_MS { return true }
    return metersBetween(last, next) >= LIVE_PING_MIN_MOVE_M
}

public func parseTrackToken(from raw: String) -> String? {
    guard let url = URL(string: raw) else { return nil }
    let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    if let token = items.first(where: { $0.name == "track_token" })?.value?.trimmingCharacters(in: .whitespacesAndNewlines),
       !token.isEmpty
    {
        return token
    }
    if let token = items.first(where: { $0.name == "token" })?.value?.trimmingCharacters(in: .whitespacesAndNewlines),
       !token.isEmpty
    {
        return token
    }
    return nil
}

private func metersBetween(_ a: LatLngAt, _ b: LatLngAt) -> Double {
    let toRad = { (deg: Double) in deg * .pi / 180 }
    let earthM = 6_371_000.0
    let dLat = toRad(b.lat - a.lat)
    let dLng = toRad(b.lng - a.lng)
    let lat1 = toRad(a.lat)
    let lat2 = toRad(b.lat)
    let h = sin(dLat / 2) * sin(dLat / 2)
        + cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2)
    return 2 * earthM * asin(min(1, sqrt(h)))
}
