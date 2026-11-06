import UIKit
import UserNotifications

/// Asks iOS for permission to show notifications, once, when a notification
/// toggle is first turned on (별 만들기 알림, 새 기능·혜택 알림).
enum NotificationAccess {
    /// True when notifications may be shown. Asks the first time; after the user
    /// has said no, iOS won't ask again and this returns false.
    static func request() async -> Bool {
        let center = UNUserNotificationCenter.current()
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        default:
            return false
        }
    }

    /// The app's page in the iOS Settings app, where notifications can be turned back on.
    @MainActor static func openSettings() {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
