import SwiftUI

/// Something worth interrupting a lifter mid-workout to show them.
///
/// One celebration is on screen at a time. They are deliberately **not**
/// queued: a PR and the tier-up it caused fire from the same set, and showing
/// two banners back-to-back mid-set is noise, not a reward. `Celebration.rank`
/// decides which one survives — see `WorkoutLoggerViewModel.present(_:)`.
///
/// Adding a new kind (a badge unlock, a streak milestone) means a case here and
/// a rank, not another bolt-on banner in `ActiveWorkoutView`. Three separate
/// overlays is how the PR banner, the rest bar and the transition card each
/// ended up invisible in focus mode.
enum Celebration: Identifiable, Equatable {
    /// Crossed into a new strength tier on a lift.
    case tierUp(exerciseId: String, exerciseName: String, tier: StrengthTier)
    /// Beat a previous best on a lift.
    case personalRecord(PersonalRecord)

    var id: String {
        switch self {
        case let .tierUp(exerciseId, _, tier): return "tier-\(exerciseId)-\(tier.rawValue)"
        case let .personalRecord(pr):          return "pr-\(pr.id)"
        }
    }

    /// Higher wins when two celebrations land together.
    ///
    /// A tier-up outranks the PR that caused it: tiers move a handful of times
    /// a year, PRs move most weeks, so the tier is the rarer and more meaningful
    /// of the two.
    var rank: Int {
        switch self {
        case .tierUp:         return 2
        case .personalRecord: return 1
        }
    }

    /// The lift this celebration is about, used to recognise a tier-up and the
    /// PR that caused it as the same moment.
    var exerciseId: String {
        switch self {
        case let .tierUp(exerciseId, _, _): return exerciseId
        case let .personalRecord(pr):       return pr.exerciseId
        }
    }

    var title: String {
        switch self {
        case let .tierUp(_, _, tier): return "\(tier.displayName) unlocked!"
        case .personalRecord:         return "New Personal Record!"
        }
    }

    var subtitle: String {
        switch self {
        case let .tierUp(_, exerciseName, _):
            return exerciseName
        case let .personalRecord(pr):
            return "\(pr.exerciseName) — \(pr.weight.formattedWeight) lbs × \(pr.reps)"
        }
    }

    var iconSystemName: String {
        switch self {
        case let .tierUp(_, _, tier): return tier.icon
        case .personalRecord:         return "trophy.fill"
        }
    }

    /// Background fill. Tier-ups take the tier's own colour so Diamond reads as
    /// Diamond — the scale is the point, and a uniform gold banner would flatten
    /// it back into "you did a thing".
    var fill: AnyShapeStyle {
        switch self {
        case let .tierUp(_, _, tier): return AnyShapeStyle(tier.gradient)
        case .personalRecord:         return AnyShapeStyle(Theme.prGold)
        }
    }

    /// Colour used for the banner's glow, which a gradient can't provide.
    var glow: Color {
        switch self {
        case let .tierUp(_, _, tier): return tier.color
        case .personalRecord:         return Theme.prGold
        }
    }

    /// Identity-based, because `PersonalRecord` is not `Equatable` and a
    /// celebration is the same moment when it is about the same achievement.
    static func == (lhs: Celebration, rhs: Celebration) -> Bool {
        lhs.id == rhs.id
    }

    var accessibilityLabel: String {
        switch self {
        case let .tierUp(_, exerciseName, tier):
            return "\(tier.displayName) tier reached on \(exerciseName)"
        case let .personalRecord(pr):
            return "New personal record: \(pr.exerciseName), \(pr.weight.formattedWeight) lbs for \(pr.reps) reps"
        }
    }
}
