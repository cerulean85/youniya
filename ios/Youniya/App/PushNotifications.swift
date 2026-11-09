import UIKit
import UserNotifications

/// Remote notifications (APNs) from the YOUNIYA API:
/// - `report_result` (101): a line the user reported was looked at.
/// - `announcement`: 새 기능·혜택 알림, only for marketing opt-in.
/// The device token goes to `PUT /v1/me/devices` once notifications are allowed,
/// and is removed on sign-out or when notifications are turned off.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { await PushRegistration.register(token: hex) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        #if DEBUG
        print("APNs registration failed: \(error)")
        #endif
    }

    /// Show banners while the app is open too.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    /// A tap opens what `target.screen` names (130 routing); without one, the 알림함.
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        guard info["kind"] != nil || info["target"] != nil else { return }  // e.g. the local 별 만들기 알림
        let target = NotificationTarget(info["target"] as? [String: Any]) ?? .inbox
        await MainActor.run {
            NotificationCenter.default.post(name: .openNotificationTarget, object: target)
        }
    }
}

enum PushRegistration {
    private static let tokenKey = "apnsToken"

    /// Debug builds talk to the APNs sandbox; TestFlight and the App Store to production.
    private static var environment: String {
        #if DEBUG
        "sandbox"
        #else
        "production"
        #endif
    }

    /// Asks iOS for a token when notifications are allowed and the live API is signed in.
    /// The token itself arrives in `AppDelegate`.
    @MainActor static func refresh(signedIn: Bool) async {
        guard signedIn, await APIClient.shared.isSignedIn else { return }
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        switch status {
        case .authorized, .provisional, .ephemeral:
            UIApplication.shared.registerForRemoteNotifications()
        case .denied:
            // Turned off in iOS Settings: stop sending to this device.
            await unregister()
        default:
            break
        }
    }

    static func register(token: String) async {
        guard await APIClient.shared.isSignedIn else { return }
        struct Body: Encodable { var token: String; var environment: String }
        do {
            try await APIClient.shared.sendRaw("PUT", "/v1/me/devices", body: Body(token: token, environment: environment))
            UserDefaults.standard.set(token, forKey: tokenKey)
        } catch {
            #if DEBUG
            print("Device registration failed: \(error)")
            #endif
        }
    }

    /// Before sign-out, and when iOS notifications are off.
    static func unregister() async {
        guard let token = UserDefaults.standard.string(forKey: tokenKey),
              await APIClient.shared.isSignedIn else { return }
        try? await APIClient.shared.delete("/v1/me/devices/\(token)")
        UserDefaults.standard.removeObject(forKey: tokenKey)
    }
}
