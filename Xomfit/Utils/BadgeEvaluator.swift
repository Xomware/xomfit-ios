import Foundation

/// Pure evaluator that decides which `ActivityBadge` entries from `BadgeCatalog`
/// a user has unlocked given their workout history and first-PR date (#320).
///
/// Like `WorkoutInsights`, this is intentionally pure — no service calls,
/// no side effects — so it's trivially testable and safe to re-run from views.
enum BadgeEvaluator {
    /// Returns the badges currently unlocked for this user, in catalog order.
    /// - Parameters:
    ///   - workouts: all workouts the user has logged.
    ///   - firstPRDate: date of the user's first ever PR, if any.
    static func unlocked(for workouts: [Workout], firstPRDate: Date?) -> [ActivityBadge] {
        let totalWorkouts = workouts.count
        let totalVolume = workouts.reduce(0.0) { $0 + $1.totalVolume }
        let longestStreak = WorkoutInsights.longestStreak(workouts: workouts)

        return BadgeCatalog.all.filter { badge in
            switch badge.unlockCriteria {
            case .firstWorkout:
                return totalWorkouts >= 1
            case .streakDays(let days):
                return longestStreak >= days
            case .totalWorkouts(let n):
                return totalWorkouts >= n
            case .totalVolumeLbs(let lbs):
                return totalVolume >= lbs
            case .firstPR:
                return firstPRDate != nil
            }
        }
    }
}
