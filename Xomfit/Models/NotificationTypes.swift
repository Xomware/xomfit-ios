import Foundation

// MARK: - Notification Categories
enum NotificationCategory: String, CaseIterable {
    case friendActivity = "friend_activity"
    case personalRecords = "personal_records"
    case workoutReminders = "workout_reminders"
    case challenges = "challenges"
    case social = "social"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .friendActivity: return "Friend Activity"
        case .personalRecords: return "Personal Records"
        case .workoutReminders: return "Workout Reminders"
        case .challenges: return "Challenges"
        case .social: return "Social"
        case .system: return "System"
        }
    }
    
    var description: String {
        switch self {
        case .friendActivity: return "When friends hit PRs, complete workouts, or check in"
        case .personalRecords: return "When you set a new personal record"
        case .workoutReminders: return "Daily workout reminders at your scheduled time"
        case .challenges: return "Challenge updates, completions, and leaderboard changes"
        case .social: return "Comments, reactions, and mentions on your posts"
        case .system: return "App updates and important announcements"
        }
    }
    
    var systemImage: String {
        switch self {
        case .friendActivity: return "figure.strengthtraining.traditional"
        case .personalRecords: return "trophy.fill"
        case .workoutReminders: return "alarm.fill"
        case .challenges: return "flag.fill"
        case .social: return "bubble.left.and.bubble.right.fill"
        case .system: return "bell.fill"
        }
    }
}

// MARK: - Notification Types
enum NotificationType: String {
    // Friend activity
    case friendPR = "friend_pr"
    case friendWorkoutComplete = "friend_workout_complete"
    case friendCheckIn = "friend_check_in"
    
    // Personal records
    case newPR = "new_pr"
    case PRStreakMilestone = "pr_streak_milestone"
    
    // Workout reminders
    case workoutReminder = "workout_reminder"
    case missedWorkoutStreak = "missed_workout_streak"
    case streakCelebration = "streak_celebration"
    
    // Challenges
    case challengeInvite = "challenge_invite"
    case challengeUpdate = "challenge_update"
    case challengeComplete = "challenge_complete"
    case leaderboardChange = "leaderboard_change"
    
    // Social
    case comment = "comment"
    case reaction = "reaction"
    case mention = "mention"
    case friendRequest = "friend_request"
    case friendRequestAccepted = "friend_request_accepted"
    
    var category: NotificationCategory {
        switch self {
        case .friendPR, .friendWorkoutComplete, .friendCheckIn: return .friendActivity
        case .newPR, .PRStreakMilestone: return .personalRecords
        case .workoutReminder, .missedWorkoutStreak, .streakCelebration: return .workoutReminders
        case .challengeInvite, .challengeUpdate, .challengeComplete, .leaderboardChange: return .challenges
        case .comment, .reaction, .mention, .friendRequest, .friendRequestAccepted: return .social
        }
    }
}

// MARK: - Notification Preferences
struct NotificationPreferences: Codable, Equatable {
    var userId: String
    var isEnabled: Bool
    
    // Category toggles
    var friendActivity: Bool
    var personalRecords: Bool
    var workoutReminders: Bool
    var challenges: Bool
    var social: Bool
    
    // Workout reminder time
    var reminderHour: Int    // 0-23
    var reminderMinute: Int  // 0-59
    var reminderDays: [Int]  // 0=Sun...6=Sat
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case isEnabled = "is_enabled"
        case friendActivity = "friend_activity"
        case personalRecords = "personal_records"
        case workoutReminders = "workout_reminders"
        case challenges
        case social
        case reminderHour = "reminder_hour"
        case reminderMinute = "reminder_minute"
        case reminderDays = "reminder_days"
    }
    
    static func defaultPrefs(userId: String) -> NotificationPreferences {
        NotificationPreferences(
            userId: userId,
            isEnabled: true,
            friendActivity: true,
            personalRecords: true,
            workoutReminders: true,
            challenges: true,
            social: true,
            reminderHour: 8,
            reminderMinute: 0,
            reminderDays: [1, 2, 3, 4, 5]  // Mon-Fri
        )
    }
    
    func isEnabled(for category: NotificationCategory) -> Bool {
        switch category {
        case .friendActivity: return friendActivity
        case .personalRecords: return personalRecords
        case .workoutReminders: return workoutReminders
        case .challenges: return challenges
        case .social: return social
        case .system: return true  // Always enabled
        }
    }
    
    var reminderTimeDescription: String {
        let hour = reminderHour
        let min = reminderMinute
        let amPm = hour < 12 ? "AM" : "PM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return String(format: "%d:%02d %@", displayHour, min, amPm)
    }
    
    var reminderDaysDescription: String {
        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        if reminderDays == [0, 1, 2, 3, 4, 5, 6] { return "Every day" }
        if reminderDays == [1, 2, 3, 4, 5] { return "Weekdays" }
        if reminderDays == [0, 6] { return "Weekends" }
        return reminderDays.map { dayNames[$0] }.joined(separator: ", ")
    }
}
