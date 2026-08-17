import Combine
import CoreLocation
import Foundation
import YahpazDomain

@MainActor
final class LocationTracker: NSObject, ObservableObject {
    @Published var statusText = "ממתינים לאישור מיקום…"
    @Published var ended = false
    @Published var failed: String?
    @Published var sharing = false

    private let manager = CLLocationManager()
    private var token: String?
    private var last: LatLngAt?
    private var started = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 25
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = true
    }

    func start(token: String) {
        self.token = token
        ended = false
        failed = nil
        sharing = false
        last = nil
        started = true
        statusText = "ממתינים לאישור מיקום…"
        manager.requestAlwaysAuthorization()
        manager.startUpdatingLocation()
        Task { await load() }
    }

    func stop() {
        started = false
        manager.stopUpdatingLocation()
        sharing = false
    }

    private func load() async {
        guard let token else { return }
        let result = await YahpazAPI.shared.loadTrack(token: token)
        if result.ended == true || result.error == "ended" {
            ended = true
            statusText = "המעקב הסתיים."
            stop()
            return
        }
        if result.ok == false, let error = result.error {
            failed = error
            statusText = error
        }
    }

    fileprivate func handle(location: CLLocation) {
        guard started, let token, !ended else { return }
        let next = LatLngAt(
            lat: location.coordinate.latitude,
            lng: location.coordinate.longitude,
            atMs: Int64(location.timestamp.timeIntervalSince1970 * 1000)
        )
        guard shouldEmitPing(last: last, next: next) else { return }
        last = next
        Task {
            let result = await YahpazAPI.shared.pingTrack(
                token: token,
                lat: next.lat,
                lng: next.lng,
                accuracy: location.horizontalAccuracy
            )
            if result.ended == true || result.error == "ended" {
                ended = true
                statusText = "המעקב הסתיים."
                stop()
                return
            }
            if result.ok == false, let error = result.error, error != "ok" {
                if error == "invalid" || error == "expired" {
                    failed = "קישור המעקב אינו תקף."
                    statusText = "קישור המעקב אינו תקף."
                    stop()
                    return
                }
            }
            sharing = true
            statusText = "המיקום משותף עם האחמ״ש."
        }
    }
}

extension LocationTracker: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .denied, .restricted:
                self.failed = "יש לאשר מיקום בהגדרות כדי לשתף מיקום בזמן אירוע."
                self.statusText = self.failed ?? ""
            case .authorizedAlways, .authorizedWhenInUse:
                if self.started { manager.startUpdatingLocation() }
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.handle(location: location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.failed = "לא הצלחנו לקבל מיקום. בדקו את ההרשאות ונסו שוב."
            self.statusText = self.failed ?? ""
        }
    }
}
