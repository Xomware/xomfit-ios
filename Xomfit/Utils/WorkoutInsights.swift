import Foundation

/// Pure helpers for streak counting and recent-PR detection over a user's
/// workout history. Used by Profile streak card (#250) and the app-open
/// badge toast on `MainTabView`.
///
/// All functions are pure -- they take an array of workouts and return
/// derived values. No side effects, no service calls. Keep them this way
/// so they're trivially testable and safe to call repeatedly from views.
enum WorkoutInsights {

    // MARK: - Streaks

    /// Current consecutive-day streak ending today (or yesterday).
    ///
    /// A "streak day" is any calendar day with at least one workout.
    /// Streak resets after one missed day. We allow "today not yet logged"
    /// to still count yesterday's streak so users don't see the number
    /// drop to zero between waking up and lifting.
    static func currentStreak(workouts: [Workout], calendar: Calendar = .current, now: Date = Date()) -> Int {
        let workoutDays = Set(workouts.map { calendar.startOfDay(for: $0.startTime) })
        let today = calendar.startOfDay(for: now)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return 0 }

        // Walk back from today; if today has no workout, start from yesterday.
        var cursor: Date
        if workoutDays.contains(today) {
            cursor = today
        } else if workoutDays.contains(yesterday) {
            cursor = yesterday
        } else {
            return 0
        }

        var streak = 0
        while workoutDays.contains(cursor) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    /// Longest historical streak across all workouts. Used as a subtitle on
    /// the streak card so users always see their personal best.
    static func longestStreak(workouts: [Workout], calendar: Calendar = .current) -> Int {
        let workoutDays = Set(workouts.map { calendar.startOfDay(for: $0.startTime) })
        guard !workoutDays.isEmpty else { return 0 }

        let sorted = workoutDays.sorted()
        var best = 1
        var run = 1
        for i in 1..<sorted.count {
            let prev = sorted[i - 1]
            let curr = sorted[i]
            if let next = calendar.date(byAdding: .day, value: 1, to: prev), next == curr {
                run += 1
                best = max(best, run)
            } else {
                run = 1
            }
        }
        return best
    }

    // MARK: - Per-day rollups

    /// Map of `startOfDay -> workout count` for the given workouts.
    /// Used by calendar views to color cells by activity.
    static func workoutCountsByDay(workouts: [Workout], calendar: Calendar = .current) -> [Date: Int] {
        var result: [Date: Int] = [:]
        for workout in workouts {
            let day = calendar.startOfDay(for: workout.startTime)
            result[day, default: 0] += 1
        }
        return result
    }

    /// Map of `startOfDay -> total volume` for the given workouts.
    /// Used by the year heatmap to bucket cells by intensity tertiles.
    static func volumeByDay(workouts: [Workout], calendar: Calendar = .current) -> [Date: Double] {
        var result: [Date: Double] = [:]
        for workout in workouts {
            let day = calendar.startOfDay(for: workout.startTime)
            result[day, default: 0] += workout.totalVolume
        }
        return result
    }

    // MARK: - Toast triggers

    /// True when the user just incremented their streak today vs. their
    /// previous app session. Caller compares the persisted last-streak
    /// value against the current streak.
    static func didIncrementStreak(previous: Int, current: Int) -> Bool {
        current > previous && current > 1
    }

    /// PRs from "yesterday's" workout that the user hasn't been celebrated
    /// for in-app yet. We pick the single best (heaviest) PR set if any.
    /// Returns nil when there's nothing to celebrate.
    static func unseenRecentPR(
        workouts: [Workout],
        lastSeenDate: Date?,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> RecentPRTip? {
        let today = calendar.startOfDay(for: now)
        let lookbackStart = calendar.date(byAdding: .day, value: -1, to: today) ?? today

        // Find PR sets logged within the last day that the user hasn't seen yet.
        var candidates: [(workout: Workout, exercise: WorkoutExercise, set: WorkoutSet)] = []
        for workout in workouts where workout.startTime >= lookbackStart && workout.startTime < today {
            for ex in workout.exercises {
                for set in ex.sets where set.isPersonalRecord {
                    if let lastSeen = lastSeenDate, set.completedAt <= lastSeen { continue }
                    candidates.append((workout, ex, set))
                }
            }
        }
        guard let best = candidates.max(by: { $0.set.weight < $1.set.weight }) else { return nil }
        return RecentPRTip(
            exerciseName: best.exercise.exercise.name,
            weight: best.set.weight,
            reps: best.set.reps,
            completedAt: best.set.completedAt
        )
    }
}

/// A single PR worth celebrating when the user re-opens the app.
struct RecentPRTip: Equatable {
    let exerciseName: String
    let weight: Double
    let reps: Int
    let completedAt: Date
}
