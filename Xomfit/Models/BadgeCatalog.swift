import Foundation
import SwiftUI

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
    /// Held `tier` or better on at least `count` distinct lifts.
    case tierReached(StrengthTier, count: Int)
    /// Moved at least this much volume within a single workout.
    case singleWorkoutVolumeLbs(Double)
    /// Started at least N workouts before `BadgeEvaluator.earlyHour`.
    case earlyBirdWorkouts(Int)
    /// Started at least N workouts at or after `BadgeEvaluator.lateHour`.
    case nightOwlWorkouts(Int)
    /// Trained in each of N consecutive calendar weeks.
    ///
    /// Distinct from `streakDays`, and a better fit for how most people
    /// actually train: a consecutive-*day* streak punishes rest days, which is
    /// the opposite of what a lifting app should reward.
    case consecutiveWeeks(Int)
    /// Completed at least N sets while the previous set's rest timer was still
    /// running.
    case beatTheClockSets(Int)
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
        ),
        ActivityBadge(
            id: "volume-500k",
            title: "Half a Million",
            description: "Lifted 500,000 lbs total.",
            iconSystemName: "mountain.2.fill",
            unlockCriteria: .totalVolumeLbs(500_000)
        ),
        ActivityBadge(
            id: "volume-1m",
            title: "Millionaire",
            description: "Lifted 1,000,000 lbs total.",
            iconSystemName: "crown.fill",
            unlockCriteria: .totalVolumeLbs(1_000_000)
        ),
        ActivityBadge(
            id: "workouts-250",
            title: "Regular",
            description: "Logged 250 total workouts.",
            iconSystemName: "calendar.badge.checkmark",
            unlockCriteria: .totalWorkouts(250)
        ),
        ActivityBadge(
            id: "workouts-500",
            title: "Lifer",
            description: "Logged 500 total workouts.",
            iconSystemName: "infinity.circle.fill",
            unlockCriteria: .totalWorkouts(500)
        ),
        ActivityBadge(
            id: "streak-14",
            title: "Fortnight",
            description: "Worked out 14 days in a row.",
            iconSystemName: "flame.circle",
            unlockCriteria: .streakDays(14)
        ),
        ActivityBadge(
            id: "streak-100",
            title: "Unbroken",
            description: "Worked out 100 days in a row.",
            iconSystemName: "seal.fill",
            unlockCriteria: .streakDays(100)
        ),

        // Consistency measured in weeks, not days — a day streak punishes rest
        // days, which is the opposite of what this app should reward.
        ActivityBadge(
            id: "weeks-8",
            title: "Two Months Solid",
            description: "Trained at least once a week for 8 weeks straight.",
            iconSystemName: "checkmark.seal.fill",
            unlockCriteria: .consecutiveWeeks(8)
        ),
        ActivityBadge(
            id: "weeks-26",
            title: "Half a Year",
            description: "Trained at least once a week for 26 weeks straight.",
            iconSystemName: "medal.fill",
            unlockCriteria: .consecutiveWeeks(26)
        ),

        // Strength ranks — the ladder, mirrored into the badge grid.
        ActivityBadge(
            id: "tier-gold-1",
            title: "Struck Gold",
            description: "Reached Gold on any lift.",
            iconSystemName: "medal.fill",
            unlockCriteria: .tierReached(.gold, count: 1)
        ),
        ActivityBadge(
            id: "tier-diamond-1",
            title: "Diamond Hands",
            description: "Reached Diamond on any lift.",
            iconSystemName: "diamond.fill",
            unlockCriteria: .tierReached(.diamond, count: 1)
        ),
        ActivityBadge(
            id: "tier-diamond-3",
            title: "Triple Threat",
            description: "Reached Diamond on three different lifts.",
            iconSystemName: "diamond.circle.fill",
            unlockCriteria: .tierReached(.diamond, count: 3)
        ),

        ActivityBadge(
            id: "single-volume-20k",
            title: "Big Day",
            description: "Moved 20,000 lbs in a single workout.",
            iconSystemName: "figure.strengthtraining.traditional",
            unlockCriteria: .singleWorkoutVolumeLbs(20_000)
        ),
        ActivityBadge(
            id: "early-bird-10",
            title: "Early Bird",
            description: "Started 10 workouts before 6am.",
            iconSystemName: "sunrise.fill",
            unlockCriteria: .earlyBirdWorkouts(10)
        ),
        ActivityBadge(
            id: "night-owl-10",
            title: "Night Owl",
            description: "Started 10 workouts after 9pm.",
            iconSystemName: "moon.stars.fill",
            unlockCriteria: .nightOwlWorkouts(10)
        ),

        // Only badge that needs data the app did not previously record, so it
        // counts forward from the 20260822 migration rather than across history.
        ActivityBadge(
            id: "beat-the-clock-10",
            title: "Back Under the Bar",
            description: "Started 10 sets before the rest timer ran out.",
            iconSystemName: "timer",
            unlockCriteria: .beatTheClockSets(10)
        ),
        ActivityBadge(
            id: "beat-the-clock-100",
            title: "No Dawdling",
            description: "Started 100 sets before the rest timer ran out.",
            iconSystemName: "hare.fill",
            unlockCriteria: .beatTheClockSets(100)
        )
    ]
}
