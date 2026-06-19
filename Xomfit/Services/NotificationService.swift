import Foundation
import UserNotifications
import UIKit
import Supabase

// MARK: - Notification Audit (#369)
//
// Local notifications scheduled by this app (fire in-process, no APNs server):
//   * Rest-timer completion  -> id "rest-{workoutId}"
//       Scheduled when WorkoutLoggerViewModel.startRestTimer(for:) fires.
//       Cancelled when skipRestTimer() is called or the rest naturally ends.
//       Trigger: rest duration (seconds, UNTimeIntervalNotificationTrigger).
//       Gated by `restTimerLocalEnabled` user toggle.
//   * Warmup completion      -> id "warmup-completion"
//       Scheduled when WarmupView's total timer begins.
//       Cancelled when the warmup finishes (naturally or via "Skip to workout").
//       Trigger: total warmup duration (seconds).
//       Gated by `warmupLocalEnabled` user toggle.
//
// Remote notifications (delivered via APNs to the registered device token,
// payload routed through `handlePushPayload`):
//   * friend_request, friend_accepted          (friendActivity prefs toggle)
//   * like, comment                            (social prefs toggle)
//   * new_pr, streak_milestone                 (personalRecords prefs toggle)
//   * friend_workout                           (friendActivity prefs toggle)
//   * weekly_report (server-scheduled cron)    (weeklyReportEnabled toggle)
//
// Notes:
//   - Permission is requested at first launch (`requestPermission()`).
//   - Device token is registered on launch + POSTed to profiles.apns_device_token
//     via ProfileService.updateAPNSToken (see AppDelegate).
//   - All UNUserNotificationCenter scheduling no-ops silently when permission
//     has not been granted (avoids simulator/test crashes).

@MainActor
@Observable
final class NotificationService {
    static let shared = NotificationService()

    var isPermissionGranted = false
    var deviceToken: String?
    var unreadCount: Int { notifications.filter { !$0.isRead }.count }
    var notifications: [AppNotification] = []

    /// Local-only toggles (not synced to Supabase — these gate in-process scheduling).
    /// Defaults true so we surface the notifications to brand-new users until they opt out.
    var restTimerLocalEnabled: Bool {
        didSet { UserDefaults.standard.set(restTimerLocalEnabled, forKey: Self.restTimerKey) }
    }
    var warmupLocalEnabled: Bool {
        didSet { UserDefaults.standard.set(warmupLocalEnabled, forKey: Self.warmupKey) }
    }
    var weeklyReportEnabled: Bool {
        didSet { UserDefaults.standard.set(weeklyReportEnabled, forKey: Self.weeklyReportKey) }
    }

    private static let restTimerKey = "xomfit_notif_rest_timer_enabled"
    private static let warmupKey = "xomfit_notif_warmup_enabled"
    private static let weeklyReportKey = "xomfit_notif_weekly_report_enabled"
    private static let restNotifPrefix = "rest-"
    static let warmupNotifId = "warmup-completion"

    private let storageKey = "xomfit_notifications"
    private let prefsKey = "xomfit_notification_prefs"

    private init() {
        // Default missing keys to `true` (opt-in by default).
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Self.restTimerKey) == nil { defaults.set(true, forKey: Self.restTimerKey) }
        if defaults.object(forKey: Self.warmupKey) == nil { defaults.set(true, forKey: Self.warmupKey) }
        if defaults.object(forKey: Self.weeklyReportKey) == nil { defaults.set(true, forKey: Self.weeklyReportKey) }
        self.restTimerLocalEnabled = defaults.bool(forKey: Self.restTimerKey)
        self.warmupLocalEnabled = defaults.bool(forKey: Self.warmupKey)
        self.weeklyReportEnabled = defaults.bool(forKey: Self.weeklyReportKey)
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

    // MARK: - Local Notification Scheduling (#369)

    /// Schedule a local "rest complete" notification keyed by workout id. The
    /// identifier convention (`"rest-{workoutId}"`) ensures the latest schedule
    /// replaces any previously pending rest notification for the same workout —
    /// matching the rule "the latest replaces earlier ones".
    ///
    /// Always schedules: the system suppresses delivery when the app is in the
    /// foreground (the visual timer handles UI in that case), and delivers as a
    /// banner when the app is backgrounded or screen-locked.
    ///
    /// Silent no-op when permission has not been granted (e.g. simulator without
    /// notification entitlement).
    func scheduleRestTimerNotification(workoutId: String, duration: TimeInterval) {
        guard restTimerLocalEnabled else { return }
        guard isPermissionGranted else { return }
        guard duration > 0 else { return }

        let identifier = restIdentifier(for: workoutId)
        // Replace any prior pending notification for this workout up-front.
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = "Rest's up"
        content.body = "Rest done! Time to lift 💪"
        content.sound = .default
        content.userInfo = ["type": "rest_complete", "workout_id": workoutId]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: duration, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("[NotificationService] Failed to schedule rest notification: \(error.localizedDescription)")
            }
        }
    }

    /// Cancel the pending rest-timer notification for a workout. Safe to call
    /// when none is pending — UNUserNotificationCenter no-ops on unknown ids.
    func cancelRestTimerNotification(workoutId: String) {
        let identifier = restIdentifier(for: workoutId)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        // Also clear it from the delivered tray when natural completion just fired.
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    private func restIdentifier(for workoutId: String) -> String {
        Self.restNotifPrefix + workoutId
    }

    /// Schedule a "warmup complete" notification keyed by a single shared id —
    /// only one warmup runs at a time so the id is constant.
    func scheduleWarmupNotification(duration: TimeInterval) {
        guard warmupLocalEnabled else { return }
        guard isPermissionGranted else { return }
        guard duration > 0 else { return }

        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [Self.warmupNotifId]
        )

        let content = UNMutableNotificationContent()
        content.title = "Warmup complete"
        content.body = "You're loose. Let's lift 💪"
        content.sound = .default
        content.userInfo = ["type": "warmup_complete"]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: duration, repeats: false)
        let request = UNNotificationRequest(identifier: Self.warmupNotifId, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("[NotificationService] Failed to schedule warmup notification: \(error.localizedDescription)")
            }
        }
    }

    func cancelWarmupNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [Self.warmupNotifId]
        )
        UNUserNotificationCenter.current().removeDeliveredNotifications(
            withIdentifiers: [Self.warmupNotifId]
        )
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

    // MARK: - Backend Refresh (#inbox)

    /// Whether a refresh is currently in flight — drives the inbox loading state.
    var isRefreshing = false

    /// Pull live notifications from the backend and merge them into the inbox.
    /// Three sources, each independently best-effort (a failure in one never
    /// blocks the others):
    ///   * pending friend requests        -> `.friendRequest`
    ///   * friends' recent workouts        -> `.friendWorkout`
    ///   * an under-trained-muscle nudge   -> `.suggestedWorkout`
    ///
    /// Stable, source-derived ids let us merge without duplicating across
    /// refreshes while preserving the user's read state (see `merge(server:)`).
    func refresh(currentUserId: String) async {
        guard !currentUserId.isEmpty else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        var built: [AppNotification] = []

        // Friend requests sent TO this user.
        if let requests = try? await FriendsService.shared.fetchPendingRequests(userId: currentUserId) {
            for row in requests {
                let name = try? await ProfileService.shared.fetchProfile(userId: row.requesterId).displayName
                built.append(AppNotification(
                    id: "friendreq-\(row.id)",
                    type: .friendRequest,
                    title: name.map { "\($0) sent you a friend request" } ?? "New friend request",
                    body: "Tap to review and respond.",
                    senderId: row.requesterId,
                    targetId: nil,
                    createdAt: ISO8601DateFormatter().date(from: row.createdAt) ?? Date()
                ))
            }
        }

        // Friends' recent workout activity from the social feed.
        if let feed = try? await FeedService.shared.fetchFeed(userId: currentUserId, limit: 15) {
            for item in feed where item.userId != currentUserId && item.activityType == .workout {
                let workoutName = item.workoutActivity?.workoutName ?? "a workout"
                built.append(AppNotification(
                    id: "feed-\(item.id)",
                    type: .friendWorkout,
                    title: "\(item.user.displayName) finished \(workoutName)",
                    body: Self.workoutSummaryLine(item),
                    senderId: item.userId,
                    targetId: item.id,
                    createdAt: item.createdAt
                ))
            }
        }

        // Workout suggestion — surfaced when a muscle group is under-trained.
        let workouts = WorkoutService.shared.fetchWorkoutsFromCache(userId: currentUserId)
        if let suggestion = TrainingNudgeService.suggestionForInbox(workouts: workouts) {
            built.append(AppNotification(
                id: "suggest-\(suggestion.muscle.rawValue)",
                type: .suggestedWorkout,
                title: "Suggested: \(suggestion.muscle.displayName) session",
                body: suggestion.reason,
                senderId: nil,
                targetId: suggestion.muscle.rawValue,
                createdAt: Date()
            ))
        }

        merge(server: built)
    }

    /// One-line teaser for a friend's workout feed item.
    private static func workoutSummaryLine(_ item: SocialFeedItem) -> String {
        guard let w = item.workoutActivity else { return item.caption ?? "" }
        return "\(w.exerciseCount) exercises · \(w.totalSets) sets"
    }

    /// Merge backend-derived notifications into the local list. Existing ids keep
    /// their read state (and updated content); new ones are inserted. Locally
    /// stored push notifications (different id space) are preserved.
    private func merge(server incoming: [AppNotification]) {
        var byId: [String: AppNotification] = Dictionary(
            notifications.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for var note in incoming {
            if let existing = byId[note.id] {
                note.isRead = existing.isRead
            }
            byId[note.id] = note
        }
        notifications = byId.values.sorted { $0.createdAt > $1.createdAt }
        if notifications.count > 100 {
            notifications = Array(notifications.prefix(100))
        }
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

    /// Stable-id initializer for backend-derived notifications. The caller supplies
    /// a deterministic id (e.g. `"feed-\(itemId)"`) so repeated refreshes merge
    /// onto the same row instead of duplicating.
    init(id: String, type: NotificationType, title: String, body: String, isRead: Bool = false, senderId: String? = nil, targetId: String? = nil, createdAt: Date) {
        self.id = id
        self.type = type
        self.title = title
        self.body = body
        self.isRead = isRead
        self.senderId = senderId
        self.targetId = targetId
        self.createdAt = createdAt
    }

    enum NotificationType: String, Codable, CaseIterable {
        case friendRequest = "friend_request"
        case friendAccepted = "friend_accepted"
        case like
        case comment
        case newPR = "new_pr"
        case streakMilestone = "streak_milestone"
        case friendWorkout = "friend_workout"
        case suggestedWorkout = "suggested_workout"

        var defaultTitle: String {
            switch self {
            case .friendRequest: return "New Friend Request"
            case .friendAccepted: return "Friend Request Accepted"
            case .like: return "New Like"
            case .comment: return "New Comment"
            case .newPR: return "New Personal Record!"
            case .streakMilestone: return "Streak Milestone"
            case .friendWorkout: return "Friend Completed a Workout"
            case .suggestedWorkout: return "Suggested Workout"
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
            case .suggestedWorkout: return "sparkles"
            }
        }

        /// Inbox filter bucket this type belongs to.
        var filter: NotificationFilter {
            switch self {
            case .friendRequest, .friendAccepted, .like, .comment: return .friends
            case .friendWorkout, .newPR, .streakMilestone: return .workouts
            case .suggestedWorkout: return .suggestions
            }
        }
    }
}

/// Top-level filter buckets surfaced as chips in the notification inbox.
/// Distinct from `NotificationCategory` (which models user preference toggles).
enum NotificationFilter: String, CaseIterable, Identifiable {
    case all, friends, workouts, suggestions
    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .friends: return "Friends"
        case .workouts: return "Workouts"
        case .suggestions: return "Suggestions"
        }
    }
}

