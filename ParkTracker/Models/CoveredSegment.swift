import Foundation
import SwiftData

/// Persistent record that a given path segment has been walked at least once.
/// One row per segment; `segmentID` matches `PathSegment.id`.
@Model
final class CoveredSegment {
    @Attribute(.unique) var segmentID: String
    var firstCoveredAt: Date

    init(segmentID: String, firstCoveredAt: Date = .now) {
        self.segmentID = segmentID
        self.firstCoveredAt = firstCoveredAt
    }
}
