import Foundation
import UserNotifications

/// Sends the end-of-session summary as a local notification — important for the
/// auto-stop case, where the user may have pocketed the phone after leaving.
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {

    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
    }

    /// Ask once for permission to post notifications. Safe to call repeatedly.
    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Post the "your completion grew…" (or "no increase") notification.
    func postSummary(_ summary: SessionSummary) {
        let content = UNMutableNotificationContent()
        content.title = "Central Park visit complete"
        if summary.increased {
            content.body = String(
                format: "Your completion grew from %.1f%% to %.1f%% (+%.1f mi walked).",
                summary.startPercent * 100, summary.endPercent * 100, summary.milesAdded)
        } else {
            content.body = "Today's Central Park visit didn't increase your completion rate."
        }
        content.sound = .default
        if let icon = iconAttachment() {
            content.attachments = [icon]   // show the app icon in the notification
        }

        // Fire ~immediately.
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content, trigger: trigger)
        center.add(request)
    }

    /// The app icon as a notification image attachment. The system takes
    /// ownership of the file, so we hand it a fresh copy in the temp directory.
    private func iconAttachment() -> UNNotificationAttachment? {
        guard let src = Bundle.main.url(forResource: "notification_icon",
                                        withExtension: "png") else { return nil }
        let dst = FileManager.default.temporaryDirectory
            .appendingPathComponent("notif_icon_\(UUID().uuidString).png")
        do {
            try FileManager.default.copyItem(at: src, to: dst)
            return try UNNotificationAttachment(identifier: "appIcon", url: dst)
        } catch {
            return nil
        }
    }

    // Show the banner even if the app is still in the foreground (manual stop).
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler:
                                @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
