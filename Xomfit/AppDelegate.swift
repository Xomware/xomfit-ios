import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // MARK: - Remote Notifications

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            NotificationService.shared.setDeviceToken(deviceToken)
            // Save token to Supabase
            if let token = NotificationService.shared.deviceToken {
                await saveTokenToSupabase(token)
                // Also write the latest token to the user's profile row so the
                // backend has a canonical apns_device_token per user (#369).
                // Errors are logged but non-fatal — push_tokens upsert above is
                // the source-of-truth for multi-device delivery.
                do {
                    try await ProfileService.shared.updateAPNSToken(token)
                } catch {
                    print("[APNs] Failed to update profiles.apns_device_token: \(error.localizedDescription)")
                }
            }
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[APNs] Registration failed: \(error.localizedDescription)")
    }

    // MARK: - Foreground Notification Display

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner + sound even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    // MARK: - Notification Tap

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        Task { @MainActor in
            NotificationService.shared.handlePushPayload(userInfo)
        }
        completionHandler()
    }

    // MARK: - Save Token to Supabase

    private func saveTokenToSupabase(_ token: String) async {
        do {
            let userId = try await supabase.auth.session.user.id.uuidString.lowercased()
            let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String

            try await supabase
                .from("push_tokens")
                .upsert([
                    "user_id": userId,
                    "token": token,
                    "platform": "ios",
                    "app_version": appVersion ?? "unknown"
                ], onConflict: "user_id,token")
                .execute()
        } catch {
            print("[APNs] Failed to save token to Supabase: \(error.localizedDescription)")
        }
    }
}
