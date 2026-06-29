import Foundation
import UserNotifications

/// Central notification manager for all user-facing alerts.
/// Full implementation in Phase P8.
final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    func requestPermission() {
        // UNUserNotificationCenter requires a proper .app bundle —
        // guard against running as a raw executable during development
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            print("[Crackinate] Skipping notification permission — not running in .app bundle")
            return
        }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("[Crackinate] Notification permission error: \(error.localizedDescription)")
            }
        }
    }

    func send(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
