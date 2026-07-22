import CoreLocation

/// Thin wrapper around `CLLocationManager`. Configured for continuous, in-pocket
/// tracking during an active session: "When In Use" authorization plus background
/// updates (iOS shows a blue status pill while a walk is running), fitness type.
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

    /// Prompts for "When In Use" access — enough for background tracking during an
    /// active session. Safe to call repeatedly.
    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    /// Begins continuous updates. Background updates work with either "When In Use"
    /// or "Always" (the location background mode is declared in Info.plist), so a
    /// pocketed phone keeps tracking for the duration of the walk.
    func start() {
        let status = manager.authorizationStatus
        guard status == .authorizedAlways || status == .authorizedWhenInUse else { return }
        manager.allowsBackgroundLocationUpdates = true
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
