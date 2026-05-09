import Foundation

/// Computes which "welcome back" badge toast (streak / new PR) to show on
/// app launch (#250). Persists the last seen streak and PR-celebration date
/// in `UserDefaults` so the user only sees a toast once per increment.
///
/// Stateless from the caller's perspective: it returns a single message at
/// most, then commits the new "seen" markers so subsequent launches are quiet.
@MainActor
enum BadgeToastService {
    private static let lastSeenStreakKey = "xomfit.badge.lastSeenStreak"
    private static let lastSeenPRDateKey = "xomfit.badge.lastSeenPRDate"

    /// What kind of badge fired, if any. Pure value; the caller chooses how to show it.
    enum Badge: Equatable {
        case streak(days: Int)
        case newPR(exerciseName: String, weight: Double, reps: Int)

        var message: String {
            switch self {
            case .streak(let days):
                let unit = days == 1 ? "day" : "days"
                return "\u{1F525} \(days) \(unit) streak!"
            case .newPR(let name, let weight, let reps):
                return "\u{1F3C6} New PR: \(name) \(weight.formattedWeight)×\(reps)"
            }
        }
    }

    /// Inspect the user's workouts and decide which badge (if any) to surface.
    /// Updates persisted state so we don't re-show the same celebration twice.
    /// Streak takes precedence over PR (rule of thumb: ship at most one toast per launch).
    static func badgeForLaunch(workouts: [Workout]) -> Badge? {
        let defaults = UserDefaults.standard

        // 1. Streak just incremented?
        let streak = WorkoutInsights.currentStreak(workouts: workouts)
        let lastSeenStreak = defaults.integer(forKey: lastSeenStreakKey)
        if WorkoutInsights.didIncrementStreak(previous: lastSeenStreak, current: streak) {
            defaults.set(streak, forKey: lastSeenStreakKey)
            return .streak(days: streak)
        }
        // Sync down so streak resets don't keep firing celebration once user falls off.
        if streak != lastSeenStreak {
            defaults.set(streak, forKey: lastSeenStreakKey)
        }

        // 2. Unseen PR from yesterday?
        let lastSeenPRDate = defaults.object(forKey: lastSeenPRDateKey) as? Date
        if let pr = WorkoutInsights.unseenRecentPR(workouts: workouts, lastSeenDate: lastSeenPRDate) {
            defaults.set(pr.completedAt, forKey: lastSeenPRDateKey)
            return .newPR(exerciseName: pr.exerciseName, weight: pr.weight, reps: pr.reps)
        }

        return nil
    }

    /// Test seam — clear persisted state.
    static func resetForTesting() {
        UserDefaults.standard.removeObject(forKey: lastSeenStreakKey)
        UserDefaults.standard.removeObject(forKey: lastSeenPRDateKey)
    }
}
