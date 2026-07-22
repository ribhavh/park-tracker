import Foundation
import SwiftData

/// Persistent record that a given path segment has been walked at least once.
/// One row per segment; `segmentID` matches `PathSegment.id`.
///
/// Properties carry defaults and there is no `.unique` constraint so the model
/// stays CloudKit-compatible (CloudKit supports neither) — see BUILD.md for
/// turning on iCloud sync. Duplicates are prevented in `TrackerModel` instead,
/// which keeps an in-memory set of covered ids.
@Model
final class CoveredSegment {
    var segmentID: String = ""
    var firstCoveredAt: Date = Date.now

    init(segmentID: String, firstCoveredAt: Date = .now) {
        self.segmentID = segmentID
        self.firstCoveredAt = firstCoveredAt
    }
}
