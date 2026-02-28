import Foundation
import UserNotifications
import UIKit
import OSLog
import Supabase

private let logger = Logger(subsystem: "com.xomware.xomfit", category: "Notifications")

@MainActor
final class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    
    // MARK: - Published State
    @Published var authStatus: UNAuthorizationStatus = .notDetermined
    @Published var preferences: NotificationPreferences?
    @Published var isLoading = false
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        Task { await checkAuthStatus() }
    }
    
    // MARK: - Permission
    
    /// Request push notification permission from the user
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            
            authStatus = granted ? .authorized : .denied
            
            if granted {
                await registerForRemoteNotifications()
            }
            
            logger.info("Notification permission: \(granted ? "granted" : "denied")")
            return granted
        } catch {
            logger.error("Failed to request notification permission: \(error)")
            return false
        }
    }
    
    func checkAuthStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authStatus = settings.authorizationStatus
    }
    
    // MARK: - Device Token Registration
    
    @MainActor
    func registerForRemoteNotifications() async {
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    /// Called from AppDelegate/SceneDelegate after APNs returns a device token
    func registerDeviceToken(_ tokenData: Data, userId: String) async {
        let tokenString = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        logger.info("Registering device token for user \(userId): \(tokenString.prefix(20))...")
        
        do {
            try await supabase
                .from("push_tokens")
                .upsert([
                    "user_id": userId,
                    "token": tokenString,
                    "platform": "ios",
                    "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ], onConflict: "user_id,token")
                .execute()
            
            logger.info("Device token registered successfully")
        } catch {
            logger.error("Failed to register device token: \(error)")
        }
    }
    
    /// Remove device token on sign-out
    func unregisterDeviceToken(_ token: String, userId: String) async {
        do {
            try await supabase
                .from("push_tokens")
                .delete()
                .eq("user_id", value: userId)
                .eq("token", value: token)
                .execute()
        } catch {
            logger.error("Failed to unregister device token: \(error)")
        }
    }
    
    // MARK: - Preferences
    
    func loadPreferences(userId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let prefs: [NotificationPreferences] = try await supabase
                .from("notification_preferences")
                .select()
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
                .value
            
            if let pref = prefs.first {
                preferences = pref
            } else {
                // Create default preferences
                let defaults = NotificationPreferences.defaultPrefs(userId: userId)
                preferences = defaults
                try await savePreferences(defaults)
            }
        } catch {
            logger.error("Failed to load notification preferences: \(error)")
            preferences = NotificationPreferences.defaultPrefs(userId: userId)
        }
    }
    
    func savePreferences(_ prefs: NotificationPreferences) async throws {
        try await supabase
            .from("notification_preferences")
            .upsert(prefs, onConflict: "user_id")
            .execute()
        
        preferences = prefs
        
        // Reschedule local workout reminders
        if prefs.workoutReminders && prefs.isEnabled {
            scheduleWorkoutReminders(prefs)
        } else {
            cancelWorkoutReminders()
        }
        
        logger.info("Saved notification preferences for user \(prefs.userId)")
    }
    
    // MARK: - Local Workout Reminders
    
    func scheduleWorkoutReminders(_ prefs: NotificationPreferences) {
        cancelWorkoutReminders()
        
        guard prefs.isEnabled && prefs.workoutReminders else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Time to train 💪"
        content.body = "Keep your streak alive. Your gym session awaits."
        content.sound = .default
        content.badge = 1
        
        for dayIndex in prefs.reminderDays {
            var dateComponents = DateComponents()
            dateComponents.hour = prefs.reminderHour
            dateComponents.minute = prefs.reminderMinute
            dateComponents.weekday = dayIndex + 1  // Calendar uses 1=Sun
            
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: true
            )
            
            let request = UNNotificationRequest(
                identifier: "workout_reminder_day_\(dayIndex)",
                content: content,
                trigger: trigger
            )
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error {
                    logger.error("Failed to schedule reminder for day \(dayIndex): \(error)")
                }
            }
        }
        
        logger.info("Scheduled workout reminders for \(prefs.reminderDays.count) days")
    }
    
    func cancelWorkoutReminders() {
        let ids = (0...6).map { "workout_reminder_day_\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }
    
    // MARK: - Deep Link Handling
    
    /// Parse a push notification payload into a deep link destination
    func deepLinkDestination(from userInfo: [AnyHashable: Any]) -> NotificationDeepLink? {
        guard let type = userInfo["type"] as? String,
              let notifType = NotificationType(rawValue: type) else { return nil }
        
        switch notifType {
        case .friendPR, .friendWorkoutComplete:
            if let userId = userInfo["user_id"] as? String {
                return .profile(userId: userId)
            }
        case .newPR, .PRStreakMilestone:
            if let exerciseId = userInfo["exercise_id"] as? String {
                return .exercise(exerciseId: exerciseId)
            }
        case .comment, .reaction, .mention:
            if let workoutId = userInfo["workout_id"] as? String {
                return .workout(workoutId: workoutId)
            }
        case .friendRequest, .friendRequestAccepted:
            if let userId = userInfo["user_id"] as? String {
                return .profile(userId: userId)
            }
        case .challengeInvite, .challengeUpdate, .challengeComplete:
            if let challengeId = userInfo["challenge_id"] as? String {
                return .challenge(challengeId: challengeId)
            }
        default:
            break
        }
        
        return nil
    }
}

// MARK: - Deep Link Destination

enum NotificationDeepLink {
    case profile(userId: String)
    case workout(workoutId: String)
    case exercise(exerciseId: String)
    case challenge(challengeId: String)
    case checkIn
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    
    /// Called when notification arrives while app is in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        logger.debug("Received foreground notification: \(notification.request.identifier)")
        return [.banner, .sound, .badge]
    }
    
    /// Called when user taps a notification
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        logger.debug("User tapped notification with type: \(userInfo["type"] as? String ?? "unknown")")
        
        // Post deep link notification for the app to handle
        await MainActor.run {
            NotificationCenter.default.post(
                name: .notificationDeepLink,
                object: nil,
                userInfo: userInfo
            )
        }
    }
}

// MARK: - Notification Name Extension

extension Notification.Name {
    static let notificationDeepLink = Notification.Name("XomFitNotificationDeepLink")
    static let deviceTokenReceived = Notification.Name("XomFitDeviceTokenReceived")
}
