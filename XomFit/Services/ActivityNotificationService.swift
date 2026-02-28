import Foundation
import UserNotifications

/// Service for managing activity notifications related to live workouts
class ActivityNotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ActivityNotificationService()
    
    private let notificationCenter = UNUserNotificationCenter.current()
    
    override init() {
        super.init()
        notificationCenter.delegate = self
        requestNotificationPermissions()
    }
    
    // MARK: - Permissions
    
    func requestNotificationPermissions() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Live Workout Notifications
    
    /// Notify when a friend starts a live workout
    func notifyFriendStartedLiveWorkout(_ user: User, workoutName: String) {
        let content = UNMutableNotificationContent()
        content.title = "\(user.displayName) is lifting! 💪"
        content.body = workoutName
        content.sound = .default
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)
        
        // Add custom data
        content.userInfo = [
            "type": "live_workout_started",
            "userId": user.id,
            "workoutName": workoutName
        ]
        
        // Add action buttons
        let joinAction = UNNotificationAction(identifier: "join_live_workout", title: "Watch", options: .foreground)
        let category = UNNotificationCategory(
            identifier: "live_workout_notification",
            actions: [joinAction],
            intentIdentifiers: [],
            options: []
        )
        notificationCenter.setNotificationCategories([category])
        content.categoryIdentifier = "live_workout_notification"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "live_workout_\(user.id)", content: content, trigger: trigger)
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error.localizedDescription)")
            }
        }
    }
    
    /// Notify when someone reacts to your live workout
    func notifyReactionReceived(_ reactor: User, emoji: String, onYourWorkout: Bool = true) {
        let content = UNMutableNotificationContent()
        content.title = "\(reactor.displayName) \(emoji)"
        content.body = "reacted to your workout"
        content.sound = .default
        
        content.userInfo = [
            "type": "reaction_received",
            "userId": reactor.id,
            "emoji": emoji
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "reaction_\(reactor.id)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("Failed to schedule reaction notification: \(error.localizedDescription)")
            }
        }
    }
    
    /// Notify when someone joins to watch your live workout
    func notifyViewerJoined(_ user: User) {
        let content = UNMutableNotificationContent()
        content.title = "\(user.displayName) is watching"
        content.body = "Joined your live workout"
        content.sound = .default
        
        content.userInfo = [
            "type": "viewer_joined",
            "userId": user.id
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "viewer_joined_\(user.id)",
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("Failed to schedule viewer notification: \(error.localizedDescription)")
            }
        }
    }
    
    /// Notify about a friend's personal record during live workout
    func notifyFriendPersonalRecord(_ user: User, exercise: Exercise, weight: Double) {
        let content = UNMutableNotificationContent()
        content.title = "🔥 \(user.displayName) just hit a PR!"
        content.body = "\(exercise.name) - \(weight) lbs"
        content.sound = UNNotificationSound(named: UNNotificationSoundName("pr_sound"))
        
        content.userInfo = [
            "type": "friend_pr",
            "userId": user.id,
            "exerciseName": exercise.name,
            "weight": weight
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "friend_pr_\(user.id)_\(exercise.id)",
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("Failed to schedule PR notification: \(error.localizedDescription)")
            }
        }
    }
    
    /// Notify when a friend finishes their live workout
    func notifyFriendFinishedWorkout(_ user: User, workoutStats: WorkoutStats) {
        let content = UNMutableNotificationContent()
        content.title = "\(user.displayName) finished their workout"
        content.body = "\(workoutStats.totalSets) sets • \(workoutStats.durationString)"
        content.sound = .default
        
        content.userInfo = [
            "type": "workout_finished",
            "userId": user.id
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "workout_finished_\(user.id)",
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("Failed to schedule finish notification: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Notification Delegate
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even if app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        // Handle notification actions
        if response.actionIdentifier == "join_live_workout" {
            if let userId = userInfo["userId"] as? String {
                // Navigate to watch friend's live workout
                NotificationCenter.default.post(
                    name: NSNotification.Name("watchLiveWorkout"),
                    object: nil,
                    userInfo: ["userId": userId]
                )
            }
        }
        
        completionHandler()
    }
}

/// Helper structure for workout statistics
struct WorkoutStats: Codable {
    let totalSets: Int
    let totalVolume: Double
    let duration: TimeInterval
    let muscleGroupsCovered: [MuscleGroup]
    
    var durationString: String {
        let minutes = Int(duration / 60)
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}
