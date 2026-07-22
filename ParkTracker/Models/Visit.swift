import Foundation
import SwiftData

/// One logged Central Park visit — the story behind the percentage.
///
/// Only walks that actually covered new ground are recorded, so every row in the
/// history represents real progress. Like `CoveredSegment`, properties carry
/// defaults and there's no unique constraint, keeping the model CloudKit-ready.
@Model
final class Visit {
    var startedAt: Date = Date.now
    var duration: TimeInterval = 0
    /// Overall completion (0...1) before and after this walk.
    var startPercent: Double = 0
    var endPercent: Double = 0
    /// Miles of park path walked for the first time during this visit.
    var newMiles: Double = 0
    /// True when the walk ended because you left the park.
    var autoStopped: Bool = false

    init(startedAt: Date,
         duration: TimeInterval,
         startPercent: Double,
         endPercent: Double,
         newMiles: Double,
         autoStopped: Bool) {
        self.startedAt = startedAt
        self.duration = duration
        self.startPercent = startPercent
        self.endPercent = endPercent
        self.newMiles = newMiles
        self.autoStopped = autoStopped
    }

    var gainedPercent: Double { max(0, endPercent - startPercent) }
}
