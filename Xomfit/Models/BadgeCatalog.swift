import Foundation

// MARK: - ActivityBadge
//
// NOTE (#320): we use `ActivityBadge` rather than `Badge` to avoid colliding with
// the existing `Badge` type defined in `Challenge.swift`, which is the
// challenge-leaderboard award system. This file describes the *static catalog*
// of progression badges (first workout, streaks, volume thresholds, etc.).

/// A single static catalog entry describing a progression milestone.
struct ActivityBadge: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let iconSystemName: String
    let unlockCriteria: BadgeCriteria
}

/// Criteria for unlocking an `ActivityBadge`. Evaluated by `BadgeEvaluator`.
enum BadgeCriteria: Codable, Hashable {
    /// Logged a first workout.
    case firstWorkout
    /// Achieved a consecutive-day workout streak >= the given length.
    case streakDays(Int)
    /// Logged at least N total workouts.
    case totalWorkouts(Int)
    /// Lifetime training volume (in lbs) >= the given threshold.
    case totalVolumeLbs(Double)
    /// Set their first PR.
    case firstPR
}

// MARK: - BadgeCatalog

/// Static catalog of all progression badges in the app.
/// Order here is the order shown in the UI grid.
enum BadgeCatalog {
    static let all: [ActivityBadge] = [
        ActivityBadge(
            id: "first-workout",
            title: "First Steps",
            description: "Logged your first workout.",
            iconSystemName: "figure.walk",
            unlockCriteria: .firstWorkout
        ),
        ActivityBadge(
            id: "streak-7",
            title: "7-Day Streak",
            description: "Worked out 7 days in a row.",
            iconSystemName: "flame.fill",
            unlockCriteria: .streakDays(7)
        ),
        ActivityBadge(
            id: "streak-30",
            title: "30-Day Streak",
            description: "Worked out 30 days in a row.",
            iconSystemName: "flame.circle.fill",
            unlockCriteria: .streakDays(30)
        ),
        ActivityBadge(
            id: "first-pr",
            title: "First PR",
            description: "Set your first personal record.",
            iconSystemName: "trophy.fill",
            unlockCriteria: .firstPR
        ),
        ActivityBadge(
            id: "workouts-10",
            title: "Getting Going",
            description: "Logged 10 total workouts.",
            iconSystemName: "10.circle.fill",
            unlockCriteria: .totalWorkouts(10)
        ),
        ActivityBadge(
            id: "workouts-50",
            title: "Half-Century",
            description: "Logged 50 total workouts.",
            iconSystemName: "50.circle.fill",
            unlockCriteria: .totalWorkouts(50)
        ),
        ActivityBadge(
            id: "workouts-100",
            title: "Century Club",
            description: "Logged 100 total workouts.",
            iconSystemName: "100.circle.fill",
            unlockCriteria: .totalWorkouts(100)
        ),
        ActivityBadge(
            id: "volume-10k",
            title: "10k Lifter",
            description: "Lifted 10,000 lbs total.",
            iconSystemName: "scalemass.fill",
            unlockCriteria: .totalVolumeLbs(10_000)
        ),
        ActivityBadge(
            id: "volume-50k",
            title: "50k Lifter",
            description: "Lifted 50,000 lbs total.",
            iconSystemName: "dumbbell.fill",
            unlockCriteria: .totalVolumeLbs(50_000)
        ),
        ActivityBadge(
            id: "volume-100k",
            title: "100k Lifter",
            description: "Lifted 100,000 lbs total.",
            iconSystemName: "bolt.fill",
            unlockCriteria: .totalVolumeLbs(100_000)
        )
    ]
}
