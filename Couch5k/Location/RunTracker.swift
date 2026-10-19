import CoreLocation

/// Thin CLLocationManager wrapper configured for outdoor running with screen off.
@MainActor
final class RunTracker: NSObject, CLLocationManagerDelegate {
    var onPoint: ((RoutePointValue) -> Void)?
    private(set) var authorizationDenied = false
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.activityType = .fitness
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
        #if os(iOS)
        manager.pausesLocationUpdatesAutomatically = false
        #endif
    }

    static var authorizationStatus: CLAuthorizationStatus { CLLocationManager().authorizationStatus }

    func requestAuthorization() {
        if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
    }

    func start() {
        guard !ProcessInfo.processInfo.arguments.contains("-noprompts") else { return }   // see HealthStore.isDisabledForTest
        requestAuthorization()
        manager.allowsBackgroundLocationUpdates = true
        #if os(iOS)
        manager.showsBackgroundLocationIndicator = true
        #endif
        manager.startUpdatingLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
    }

    nonisolated func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        let values = locs.map {
            RoutePointValue(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude,
                            timestamp: $0.timestamp, horizontalAccuracy: $0.horizontalAccuracy,
                            altitude: $0.altitude, verticalAccuracy: $0.verticalAccuracy)
        }
        Task { @MainActor in for v in values { self.onPoint?(v) } }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        let denied = m.authorizationStatus == .denied || m.authorizationStatus == .restricted
        Task { @MainActor in self.authorizationDenied = denied }
    }
}
