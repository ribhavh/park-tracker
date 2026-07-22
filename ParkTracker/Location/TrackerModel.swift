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

    private(set) var phase: AppPhase = .home
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
    private let exitGrace: TimeInterval = 120          // grace after leaving the park
    private let neverArrivedTimeout: TimeInterval = 1800  // 30 min: started, never arrived

    private let modelContext: ModelContext
    private let locationManager = LocationManager()
    private let notifications = NotificationManager()

    // Matching configuration. Deliberately strict: falsely marking a path you
    // never walked corrupts the "100% of the park" goal far worse than missing
    // one you did (you'll pass it again).
    private let maxAcceptableAccuracy: CLLocationDistance = 20   // drop fuzzier fixes
    private let minMatchRadius: CLLocationDistance = 8
    private let maxMatchRadius: CLLocationDistance = 15
    private let maxHeadingDelta: Double = 45                     // degrees
    private let movingSpeed: CLLocationSpeed = 0.5               // m/s
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
        // Ask for notification permission now, at the start of the walk, so it's
        // resolved well before the end-of-session summary notification fires.
        notifications.requestAuthorization()
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

        // Only log visits that actually covered new ground — a session started by
        // accident, or one spent entirely on already-walked paths, isn't a visit
        // worth showing.
        if coveredMeters > start {
            modelContext.insert(Visit(startedAt: sessionStartDate ?? Date(),
                                      duration: summary.duration,
                                      startPercent: summary.startPercent,
                                      endPercent: summary.endPercent,
                                      newMiles: summary.milesAdded,
                                      autoStopped: auto))
            try? modelContext.save()
        }

        notifications.postSummary(summary)
        phase = .summary(summary)
    }

    /// Dismiss the summary and return to the welcome screen.
    func dismissSummary() {
        phase = .home
    }

    private func beginSession() {
        sessionStartMeters = coveredMeters
        sessionStartDate = Date()
        sessionElapsed = 0
        // Left nil deliberately: the leave-the-park timer only arms once you've
        // actually been inside, so starting a walk on your way to the park
        // doesn't auto-stop before you arrive.
        lastInsideDate = nil
        phase = .tracking
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
            if let last = lastInsideDate {
                // Been inside already — you've left the park.
                if Date().timeIntervalSince(last) > exitGrace { stopSession(auto: true) }
            } else if let started = sessionStartDate,
                      Date().timeIntervalSince(started) > neverArrivedTimeout {
                // Started but never made it to the park — don't track forever.
                stopSession(auto: true)
            }
            return
        }
        lastInsideDate = Date()
        markSegments(near: location)
    }

    /// Matches a fix to the path(s) you're actually walking.
    ///
    /// Three guards keep us off neighbouring paths, which in a dense network like
    /// Central Park is the main source of false "walked" marks:
    ///  1. a tight radius that only mildly widens with GPS uncertainty,
    ///  2. a heading gate — a path crossing your direction of travel isn't the one
    ///     you're on (this is what kills the perpendicular "spillovers"),
    ///  3. when you're standing still there's no heading to trust, so we mark only
    ///     the single nearest path rather than everything around you.
    private func markSegments(near location: CLLocation) {
        let coord = location.coordinate
        let radius = min(maxMatchRadius,
                         minMatchRadius + location.horizontalAccuracy * 0.35)
        let candidates = parkData.nearbySegmentIndices(
            to: coord, radiusMeters: radius + location.horizontalAccuracy)

        let course = location.course
        let isMoving = location.speed > movingSpeed && course >= 0

        var matches: [Int] = []
        var nearest: (idx: Int, dist: CLLocationDistance)?
        for idx in candidates {
            let seg = parkData.segments[idx]
            let dist = Geo.distance(from: coord, toSegment: seg.start, seg.end)
            guard dist <= radius else { continue }
            if isMoving {
                let segBearing = Geo.bearing(from: seg.start, to: seg.end)
                guard Geo.headingDelta(course, segBearing) <= maxHeadingDelta else { continue }
                matches.append(idx)
            } else if nearest == nil || dist < nearest!.dist {
                nearest = (idx, dist)
            }
        }
        if !isMoving, let nearest { matches = [nearest.idx] }

        var newlyCovered: [String] = []
        for idx in matches {
            let seg = parkData.segments[idx]
            if coveredIDs.contains(seg.id) { continue }
            coveredIDs.insert(seg.id)
            coveredMeters += seg.lengthMeters
            newlyCovered.append(seg.id)
        }

        guard !newlyCovered.isEmpty else { return }
        for id in newlyCovered {
            modelContext.insert(CoveredSegment(segmentID: id))
        }
        try? modelContext.save()
        coverageVersion += 1
    }

    // MARK: - Progress management

    /// Wipe all recorded coverage (e.g. to start a clean baseline).
    func resetProgress() {
        try? modelContext.delete(model: CoveredSegment.self)
        try? modelContext.save()
        coveredIDs.removeAll()
        coveredMeters = 0
        sessionStartMeters = 0
        coverageVersion += 1
    }

    /// Write a JSON backup of walked segments and visit history to a temp file.
    func exportBackup() -> URL? {
        let rows = (try? modelContext.fetch(FetchDescriptor<CoveredSegment>())) ?? []
        let visits = (try? modelContext.fetch(FetchDescriptor<Visit>())) ?? []
        let backup = Backup(
            segments: rows.map { Backup.Entry(id: $0.segmentID, at: $0.firstCoveredAt) },
            visits: visits.map {
                Backup.VisitEntry(startedAt: $0.startedAt, duration: $0.duration,
                                  startPercent: $0.startPercent, endPercent: $0.endPercent,
                                  newMiles: $0.newMiles, autoStopped: $0.autoStopped)
            })
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]
        guard let data = try? encoder.encode(backup) else { return nil }

        let stamp = ISO8601DateFormatter().string(from: Date()).prefix(10)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("park-tracker-backup-\(stamp).json")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    /// Merge a JSON backup into current progress, reporting what was restored.
    @discardableResult
    func importBackup(from url: URL) -> (segments: Int, visits: Int) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: url),
              let backup = try? decoder.decode(Backup.self, from: data) else {
            return (0, 0)
        }

        // Only ids that exist in the current path data and aren't already walked.
        let known = Set(parkData.segments.map(\.id))
        var added = 0
        for entry in backup.segments where known.contains(entry.id)
                                        && !coveredIDs.contains(entry.id) {
            coveredIDs.insert(entry.id)
            modelContext.insert(CoveredSegment(segmentID: entry.id,
                                               firstCoveredAt: entry.at))
            added += 1
        }

        // Restore visit history too (v2 backups), skipping ones we already have.
        // Compare at whole-second resolution: ISO-8601 export drops fractional
        // seconds, so raw Date equality would never match and would duplicate
        // every visit each time the same backup is imported.
        func key(_ date: Date) -> Int { Int(date.timeIntervalSince1970.rounded()) }
        var existing = Set(((try? modelContext.fetch(FetchDescriptor<Visit>())) ?? [])
            .map { key($0.startedAt) })
        var addedVisits = 0
        for v in backup.visits ?? [] where !existing.contains(key(v.startedAt)) {
            modelContext.insert(Visit(startedAt: v.startedAt, duration: v.duration,
                                      startPercent: v.startPercent,
                                      endPercent: v.endPercent,
                                      newMiles: v.newMiles,
                                      autoStopped: v.autoStopped))
            existing.insert(key(v.startedAt))
            addedVisits += 1
        }

        if added > 0 {
            coveredMeters = parkData.segments
                .filter { coveredIDs.contains($0.id) }
                .reduce(0) { $0 + $1.lengthMeters }
            coverageVersion += 1
        }
        if added > 0 || addedVisits > 0 { try? modelContext.save() }
        return (added, addedVisits)
    }

    struct Backup: Codable {
        var version = 2
        var exportedAt = Date()
        var segments: [Entry]
        /// Absent in version-1 backups.
        var visits: [VisitEntry]?
        struct Entry: Codable { let id: String; let at: Date }
        struct VisitEntry: Codable {
            let startedAt: Date
            let duration: TimeInterval
            let startPercent: Double
            let endPercent: Double
            let newMiles: Double
            let autoStopped: Bool
        }
    }
}
