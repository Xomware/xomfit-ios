import Foundation
import WidgetKit

/// Writes workout data to the shared App Group container so widgets can read it.
@MainActor
final class WidgetDataService {
    static let shared = WidgetDataService()

    private let suiteName = "group.com.xomware.xomfit"
    private var defaults: UserDefaults? { UserDefaults(suiteName: suiteName) }

    private init() {}

    // MARK: - Update Widget Data

    func updateAfterWorkout(
        streak: Int,
        weeklyVolume: Double,
        weeklyWorkouts: Int,
        lastWorkoutName: String?,
        lastWorkoutDate: Date?,
        recentPR: String?
    ) {
        guard let defaults else { return }
        defaults.set(streak, forKey: WidgetKeys.streak)
        defaults.set(weeklyVolume, forKey: WidgetKeys.weeklyVolume)
        defaults.set(weeklyWorkouts, forKey: WidgetKeys.weeklyWorkouts)
        defaults.set(lastWorkoutName, forKey: WidgetKeys.lastWorkoutName)
        defaults.set(lastWorkoutDate, forKey: WidgetKeys.lastWorkoutDate)
        defaults.set(recentPR, forKey: WidgetKeys.recentPR)
        defaults.set(Date(), forKey: WidgetKeys.lastUpdated)

        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - Shared Keys

enum WidgetKeys {
    static let streak = "widget_streak"
    static let weeklyVolume = "widget_weekly_volume"
    static let weeklyWorkouts = "widget_weekly_workouts"
    static let lastWorkoutName = "widget_last_workout_name"
    static let lastWorkoutDate = "widget_last_workout_date"
    static let recentPR = "widget_recent_pr"
    static let lastUpdated = "widget_last_updated"
}
