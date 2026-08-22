import Foundation

/// Pure evaluator that decides which `ActivityBadge` entries from `BadgeCatalog`
/// a user has unlocked given their workout history (#320).
///
/// Like `WorkoutInsights`, this is intentionally pure — no service calls,
/// no side effects — so it's trivially testable and safe to re-run from views.
///
/// Strength tiers are passed in rather than computed here. Ranking needs the
/// lifter's bodyweight, sex and age, which live on `StrengthLevelService` and
/// are main-actor state; pulling that in would make this neither pure nor
/// testable in isolation.
enum BadgeEvaluator {
    /// Before this hour counts as an early-morning session.
    static let earlyHour = 6
    /// At or after this hour counts as a late-night session.
    static let lateHour = 21

    /// Returns the badges currently unlocked for this user, in catalog order.
    /// - Parameters:
    ///   - workouts: all workouts the user has logged.
    ///   - firstPRDate: date of the user's first ever PR, if any.
    ///   - rankedTiers: the lifter's best tier on each ranked lift, one entry
    ///     per exercise. Empty when ranks are unavailable, which simply leaves
    ///     the tier badges locked rather than falsely unlocked.
    static func unlocked(
        for workouts: [Workout],
        firstPRDate: Date?,
        rankedTiers: [StrengthTier] = []
    ) -> [ActivityBadge] {
        let calendar = WorkoutInsights.userCalendar()
        let totalWorkouts = workouts.count
        let totalVolume = workouts.reduce(0.0) { $0 + $1.totalVolume }
        let longestStreak = WorkoutInsights.longestStreak(workouts: workouts)
        let bestSingleVolume = workouts.map(\.totalVolume).max() ?? 0
        let longestWeekStreak = WorkoutInsights.longestWeeklyStreak(workouts: workouts)

        let earlyCount = workouts.filter {
            calendar.component(.hour, from: $0.startTime) < earlyHour
        }.count
        let lateCount = workouts.filter {
            calendar.component(.hour, from: $0.startTime) >= lateHour
        }.count

        let beatTheClockCount = workouts.reduce(0) { total, workout in
            total + workout.exercises.reduce(0) { exerciseTotal, exercise in
                exerciseTotal + exercise.sets.filter { $0.beatRestTimer }.count
            }
        }

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
            case let .tierReached(tier, count):
                // "Tier or better" — reaching Diamond should not un-earn the
                // Gold badge on the way past it.
                return rankedTiers.filter { $0 >= tier }.count >= count
            case .singleWorkoutVolumeLbs(let lbs):
                return bestSingleVolume >= lbs
            case .earlyBirdWorkouts(let n):
                return earlyCount >= n
            case .nightOwlWorkouts(let n):
                return lateCount >= n
            case .consecutiveWeeks(let n):
                return longestWeekStreak >= n
            case .beatTheClockSets(let n):
                return beatTheClockCount >= n
            }
        }
    }
}
