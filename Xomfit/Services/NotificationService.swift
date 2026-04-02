import Foundation
import UserNotifications
import UIKit
import Supabase

@MainActor
@Observable
final class NotificationService {
    static let shared = NotificationService()

    var isPermissionGranted = false
    var deviceToken: String?
    var unreadCount: Int { notifications.filter { !$0.isRead }.count }
    var notifications: [AppNotification] = []

    private let storageKey = "xomfit_notifications"
    private let prefsKey = "xomfit_notification_prefs"

    private init() {
        loadNotifications()
        loadPreferences()
    }

    // MARK: - Permission

    func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            isPermissionGranted = granted
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
        } catch {
            print("[NotificationService] Permission request failed: \(error.localizedDescription)")
        }
    }

    func checkPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isPermissionGranted = settings.authorizationStatus == .authorized
    }

    // MARK: - Device Token

    func setDeviceToken(_ tokenData: Data) {
        let token = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        deviceToken = token
    }

    // MARK: - Preferences

    var preferences: NotificationPreferences?

    func updatePreferences(_ prefs: NotificationPreferences) {
        preferences = prefs
        savePreferences()
        Task { await syncPreferencesToSupabase(prefs) }
    }

    private func syncPreferencesToSupabase(_ prefs: NotificationPreferences) async {
        do {
            try await supabase
                .from("notification_preferences")
                .upsert(prefs, onConflict: "user_id")
                .execute()
        } catch {
            print("[NotificationService] Failed to sync preferences: \(error.localizedDescription)")
        }
    }

    // MARK: - Notifications

    func addNotification(_ notification: AppNotification) {
        notifications.insert(notification, at: 0)
        // Keep last 100
        if notifications.count > 100 {
            notifications = Array(notifications.prefix(100))
        }
        saveNotifications()
    }

    func markAsRead(_ id: String) {
        if let index = notifications.firstIndex(where: { $0.id == id }) {
            notifications[index].isRead = true
            saveNotifications()
        }
    }

    func markAllAsRead() {
        for i in notifications.indices {
            notifications[i].isRead = true
        }
        saveNotifications()
    }

    func clearAll() {
        notifications.removeAll()
        saveNotifications()
    }

    // MARK: - Handle Incoming Push

    func handlePushPayload(_ userInfo: [AnyHashable: Any]) {
        guard let type = userInfo["type"] as? String,
              let notifType = AppNotification.NotificationType(rawValue: type) else { return }

        let title = userInfo["title"] as? String ?? notifType.defaultTitle
        let body = userInfo["body"] as? String ?? ""
        let senderId = userInfo["sender_id"] as? String
        let targetId = userInfo["target_id"] as? String

        let notification = AppNotification(
            type: notifType,
            title: title,
            body: body,
            senderId: senderId,
            targetId: targetId
        )

        addNotification(notification)
    }

    // MARK: - Persistence

    private func loadNotifications() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([AppNotification].self, from: data) else { return }
        notifications = saved
    }

    private func saveNotifications() {
        if let data = try? JSONEncoder().encode(notifications) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadPreferences() {
        guard let data = UserDefaults.standard.data(forKey: prefsKey),
              let prefs = try? JSONDecoder().decode(NotificationPreferences.self, from: data) else { return }
        preferences = prefs
    }

    private func savePreferences() {
        if let data = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(data, forKey: prefsKey)
        }
    }
}

// MARK: - Models

struct AppNotification: Codable, Identifiable {
    let id: String
    let type: NotificationType
    let title: String
    let body: String
    var isRead: Bool
    let senderId: String?
    let targetId: String?
    let createdAt: Date

    init(type: NotificationType, title: String, body: String, senderId: String? = nil, targetId: String? = nil) {
        self.id = UUID().uuidString
        self.type = type
        self.title = title
        self.body = body
        self.isRead = false
        self.senderId = senderId
        self.targetId = targetId
        self.createdAt = Date()
    }

    enum NotificationType: String, Codable, CaseIterable {
        case friendRequest = "friend_request"
        case friendAccepted = "friend_accepted"
        case like
        case comment
        case newPR = "new_pr"
        case streakMilestone = "streak_milestone"
        case friendWorkout = "friend_workout"

        var defaultTitle: String {
            switch self {
            case .friendRequest: return "New Friend Request"
            case .friendAccepted: return "Friend Request Accepted"
            case .like: return "New Like"
            case .comment: return "New Comment"
            case .newPR: return "New Personal Record!"
            case .streakMilestone: return "Streak Milestone"
            case .friendWorkout: return "Friend Completed a Workout"
            }
        }

        var icon: String {
            switch self {
            case .friendRequest, .friendAccepted: return "person.badge.plus"
            case .like: return "heart.fill"
            case .comment: return "bubble.right.fill"
            case .newPR: return "trophy.fill"
            case .streakMilestone: return "flame.fill"
            case .friendWorkout: return "figure.strengthtraining.traditional"
            }
        }
    }
}

