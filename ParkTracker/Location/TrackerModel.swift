import Foundation
import CoreLocation
import SwiftData
import Observation

/// App-wide state and the coverage engine. Owns the park data, the set of
/// covered segment IDs, and the location feed; turns raw GPS fixes into
/// "this path segment is now walked" and persists the result.
@MainActor
@Observable
final class TrackerModel {

    let parkData: ParkData

    /// IDs of segments walked at least once. In-memory mirror of `CoveredSegment`.
    private(set) var coveredIDs: Set<String> = []
    /// Bumps whenever `coveredIDs` grows, so the map knows to redraw.
    private(set) var coverageVersion: Int = 0

    var authStatus: CLAuthorizationStatus
    var lastLocation: CLLocation?

    private let modelContext: ModelContext
    private let locationManager = LocationManager()

    // Matching configuration (meters).
    private let baseThreshold: CLLocationDistance = 12
    private let maxThreshold: CLLocationDistance = 22
    private let maxAcceptableAccuracy: CLLocationDistance = 30

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
            MainActor.assumeIsolated {
                guard let self else { return }
                self.authStatus = status
                if status == .authorizedAlways || status == .authorizedWhenInUse {
                    self.locationManager.start()
                }
            }
        }
    }

    // MARK: - Progress

    var progress: Double {
        guard !parkData.segments.isEmpty else { return 0 }
        return Double(coveredIDs.count) / Double(parkData.segments.count)
    }
    var coveredCount: Int { coveredIDs.count }
    var totalCount: Int { parkData.segments.count }

    // MARK: - Tracking control

    /// Prompt for location access (and start tracking if already granted).
    func startTracking() {
        if authStatus == .authorizedAlways || authStatus == .authorizedWhenInUse {
            locationManager.start()
        } else if authStatus == .notDetermined {
            locationManager.requestAuthorization()
        }
    }

    // MARK: - Coverage engine

    private func loadCovered() {
        let descriptor = FetchDescriptor<CoveredSegment>()
        if let rows = try? modelContext.fetch(descriptor) {
            coveredIDs = Set(rows.map { $0.segmentID })
        }
    }

    private func ingest(_ location: CLLocation) {
        lastLocation = location
        guard location.horizontalAccuracy > 0,
              location.horizontalAccuracy <= maxAcceptableAccuracy else { return }

        // Loosen the match tolerance for less-accurate fixes, but cap it so we
        // don't mark a parallel path a few meters away.
        let threshold = min(maxThreshold, baseThreshold + location.horizontalAccuracy * 0.5)
        let coord = location.coordinate
        let candidates = parkData.nearbySegmentIndices(
            to: coord, radiusMeters: threshold + location.horizontalAccuracy)

        var newlyCovered: [String] = []
        for idx in candidates {
            let seg = parkData.segments[idx]
            if coveredIDs.contains(seg.id) { continue }
            if Geo.distance(from: coord, toSegment: seg.start, seg.end) <= threshold {
                coveredIDs.insert(seg.id)
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
