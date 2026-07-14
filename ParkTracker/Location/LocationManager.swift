import CoreLocation

/// Thin wrapper around `CLLocationManager`. Configured for continuous, in-pocket
/// tracking: "Always" authorization, background updates, fitness activity type.
final class LocationManager: NSObject, CLLocationManagerDelegate {

    private let manager = CLLocationManager()

    /// Called for every accepted location fix (on the main thread).
    var onLocation: ((CLLocation) -> Void)?
    /// Called whenever authorization status changes.
    var onAuthChange: ((CLAuthorizationStatus) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.activityType = .fitness
        manager.distanceFilter = 5           // meters between updates
        manager.pausesLocationUpdatesAutomatically = false
    }

    var authorizationStatus: CLAuthorizationStatus { manager.authorizationStatus }

    /// Prompts for "Always" access. Safe to call repeatedly.
    func requestAuthorization() {
        manager.requestAlwaysAuthorization()
    }

    /// Begins continuous updates. Enables background updates only once we hold a
    /// usable authorization, which avoids a crash on misconfiguration.
    func start() {
        let status = manager.authorizationStatus
        guard status == .authorizedAlways || status == .authorizedWhenInUse else { return }
        if status == .authorizedAlways {
            manager.allowsBackgroundLocationUpdates = true
        }
        manager.startUpdatingLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        for location in locations { onLocation?(location) }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        onAuthChange?(manager.authorizationStatus)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Transient failures (e.g. no fix yet) are expected; nothing to do.
    }
}
