import Foundation

/// Which screen the app is showing.
enum AppPhase: Equatable {
    /// Your progress map + stats, with the Start button. The app's front door.
    case home
    case tracking
    case summary(SessionSummary)
}

/// The result of one Central Park visit, shown on the summary screen and in the
/// end-of-session notification.
struct SessionSummary: Equatable {
    let startPercent: Double   // 0...1 before the walk
    let endPercent: Double     // 0...1 after the walk
    let milesAdded: Double
    let duration: TimeInterval
    let autoStopped: Bool      // true if we stopped because you left the park

    /// Did this visit actually extend your coverage?
    var increased: Bool { endPercent - startPercent > 0.00005 }
}
