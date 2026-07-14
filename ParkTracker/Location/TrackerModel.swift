import Foundation
import CoreLocation
import SwiftData
import Observation

/// App-wide state, session flow, and the coverage engine. Owns the park data,
/// the set of covered segment IDs, and the location feed; drives a walk session
/// from welcome → tracking → summary, and turns raw GPS fixes into "this path
/// segment is now walked".
@MainActor
@Observable
final class TrackerModel {

    let parkData: ParkData

    // MARK: - Coverage state

    /// IDs of segments walked at least once. In-memory mirror of `CoveredSegment`.
    private(set) var coveredIDs: Set<String> = []
    /// Running total length of walked segments, in meters.
    private(set) var coveredMeters: Double = 0
    /// Bumps whenever `coveredIDs` grows, so the map knows to redraw.
    private(set) var coverageVersion: Int = 0

    // MARK: - Session state

    private(set) var phase: AppPhase = .welcome
    var authStatus: CLAuthorizationStatus
    var lastLocation: CLLocation?
    /// Set when the user tapped Start but location access was refused.
    private(set) var permissionDenied = false
    /// Seconds elapsed in the current session (updated ~1×/sec while tracking).
    private(set) var sessionElapsed: TimeInterval = 0

    private var sessionStartMeters: Double = 0
    private var sessionStartDate: Date?
    private var pendingStart = false
    private var lastInsideDate: Date?
    private var elapsedTimer: Timer?
    private let exitGrace: TimeInterval = 120   // leave-the-park grace period

    private let modelContext: ModelContext
    private let locationManager = LocationManager()
    private let notifications = NotificationManager()

    // Matching configuration (meters).
    private let baseThreshold: CLLocationDistance = 12
    private let maxThreshold: CLLocationDistance = 22
    private let maxAcceptableAccuracy: CLLocationDistance = 30
    private let metersPerMile = 1609.344

    init(parkData: ParkData, modelContext: ModelContext) {
        self.parkData = parkData
        self.modelContext = modelContext
        self.authStatus = locationManager.authorizationStatus
        loadCovered()

        // CLLocationManager delivers callbacks on the main thread (it's created
        // here on the main actor), so we can assume main-actor isolation.
        locationManager.onLocation = { [weak self] location in
            MainActor.assumeIsolated { self?.ingest(location) }
        }
        locationManager.onAuthChange = { [weak self] status in
            MainActor.assumeIsolated { self?.handleAuthChange(status) }
        }
    }

    // MARK: - Progress (overall)

    /// Share of the park's total path length that has been walked.
    var progress: Double {
        guard parkData.totalMeters > 0 else { return 0 }
        return coveredMeters / parkData.totalMeters
    }
    var coveredMiles: Double { coveredMeters / metersPerMile }
    var totalMiles: Double { parkData.totalMeters / metersPerMile }

    // MARK: - Session-live stats

    /// New miles walked since this session began.
    var sessionMilesAdded: Double {
        max(0, (coveredMeters - sessionStartMeters) / metersPerMile)
    }

    // MARK: - Session control

    /// Start button: begin a session, requesting permission first if needed.
    func requestStart() {
        permissionDenied = false
        switch authStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            beginSession()
        case .notDetermined:
            pendingStart = true
            locationManager.requestAuthorization()
        default:
            permissionDenied = true
        }
    }

    /// Stop button, or automatic stop when the user leaves the park.
    func stopSession(auto: Bool) {
        guard phase == .tracking else { return }
        locationManager.stop()
        elapsedTimer?.invalidate()
        elapsedTimer = nil

        let start = sessionStartMeters
        let summary = SessionSummary(
            startPercent: parkData.totalMeters > 0 ? start / parkData.totalMeters : 0,
            endPercent: progress,
            milesAdded: max(0, (coveredMeters - start) / metersPerMile),
            duration: sessionStartDate.map { Date().timeIntervalSince($0) } ?? sessionElapsed,
            autoStopped: auto)
        notifications.postSummary(summary)
        phase = .summary(summary)
    }

    /// Dismiss the summary and return to the welcome screen.
    func dismissSummary() {
        phase = .welcome
    }

    private func beginSession() {
        sessionStartMeters = coveredMeters
        sessionStartDate = Date()
        sessionElapsed = 0
        lastInsideDate = Date()
        phase = .tracking
        notifications.requestAuthorization()
        locationManager.start()

        elapsedTimer?.invalidate()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let start = self.sessionStartDate else { return }
                self.sessionElapsed = Date().timeIntervalSince(start)
            }
        }
    }

    private func handleAuthChange(_ status: CLAuthorizationStatus) {
        authStatus = status
        guard pendingStart else { return }
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            pendingStart = false
            beginSession()
        case .denied, .restricted:
            pendingStart = false
            permissionDenied = true
        default:
            break   // still .notDetermined; wait for the user's choice
        }
    }

    // MARK: - Coverage engine

    private func loadCovered() {
        let descriptor = FetchDescriptor<CoveredSegment>()
        if let rows = try? modelContext.fetch(descriptor) {
            coveredIDs = Set(rows.map { $0.segmentID })
            coveredMeters = parkData.segments
                .filter { coveredIDs.contains($0.id) }
                .reduce(0) { $0 + $1.lengthMeters }
        }
    }

    private func ingest(_ location: CLLocation) {
        guard phase == .tracking else { return }
        lastLocation = location
        guard location.horizontalAccuracy > 0,
              location.horizontalAccuracy <= maxAcceptableAccuracy else { return }

        // Only ever record coverage while physically inside Central Park. When
        // outside, record nothing and auto-stop after the grace period.
        let coord = location.coordinate
        guard parkData.isInsidePark(coord) else {
            if let last = lastInsideDate, Date().timeIntervalSince(last) > exitGrace {
                stopSession(auto: true)
            }
            return
        }
        lastInsideDate = Date()

        // Loosen the match tolerance for less-accurate fixes, but cap it so we
        // don't mark a parallel path a few meters away.
        let threshold = min(maxThreshold, baseThreshold + location.horizontalAccuracy * 0.5)
        let candidates = parkData.nearbySegmentIndices(
            to: coord, radiusMeters: threshold + location.horizontalAccuracy)

        var newlyCovered: [String] = []
        for idx in candidates {
            let seg = parkData.segments[idx]
            if coveredIDs.contains(seg.id) { continue }
            if Geo.distance(from: coord, toSegment: seg.start, seg.end) <= threshold {
                coveredIDs.insert(seg.id)
                coveredMeters += seg.lengthMeters
                newlyCovered.append(seg.id)
            }
        }

        guard !newlyCovered.isEmpty else { return }
        for id in newlyCovered {
            modelContext.insert(CoveredSegment(segmentID: id))
        }
        try? modelContext.save()
        coverageVersion += 1
    }
}
