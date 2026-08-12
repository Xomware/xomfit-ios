import SwiftUI

/// Per-exercise strength rank, earned by estimated 1RM relative to bodyweight.
///
/// Tiers are deliberately spaced so that the first three are reachable by most
/// lifters within a year or two of consistent training, while the top two are
/// genuinely rare — a rank nobody can lose interest in reaching is not a rank.
/// See `StrengthStandards` for where the thresholds come from.
enum StrengthTier: Int, CaseIterable, Codable, Comparable, Identifiable {
    case unranked = 0
    case bronze
    case silver
    case gold
    case diamond
    case olympian
    case god

    var id: Int { rawValue }

    static func < (lhs: StrengthTier, rhs: StrengthTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Ranks a lifter can actually hold, in ascending order. Excludes `unranked`,
    /// which is the absence of a rank rather than one of them.
    static var ranked: [StrengthTier] {
        allCases.filter { $0 != .unranked }
    }

    var displayName: String {
        switch self {
        case .unranked: return "Unranked"
        case .bronze:   return "Bronze"
        case .silver:   return "Silver"
        case .gold:     return "Gold"
        case .diamond:  return "Diamond"
        case .olympian: return "Olympian"
        case .god:      return "God"
        }
    }

    /// One-line description of what the tier represents, for the detail sheet.
    var blurb: String {
        switch self {
        case .unranked: return "Log a set to earn your first rank"
        case .bronze:   return "Getting started — the lift is yours"
        case .silver:   return "Solid recreational strength"
        case .gold:     return "Strong for a serious gym-goer"
        case .diamond:  return "Advanced — years of dedicated training"
        case .olympian: return "Competitive strength"
        case .god:      return "Elite. Almost nobody gets here."
        }
    }

    var icon: String {
        switch self {
        case .unranked: return "circle.dashed"
        case .bronze:   return "medal.fill"
        case .silver:   return "medal.fill"
        case .gold:     return "medal.fill"
        case .diamond:  return "diamond.fill"
        case .olympian: return "flame.fill"
        case .god:      return "crown.fill"
        }
    }

    /// Tier colors are defined here rather than in Theme because they are a
    /// fixed, meaningful scale — bronze must read as bronze in either color
    /// scheme, so these do not adapt.
    var color: Color {
        switch self {
        case .unranked: return Color(white: 0.45)
        case .bronze:   return Color(red: 0.80, green: 0.50, blue: 0.20)
        case .silver:   return Color(red: 0.75, green: 0.76, blue: 0.78)
        case .gold:     return Color(red: 0.98, green: 0.76, blue: 0.18)
        case .diamond:  return Color(red: 0.45, green: 0.85, blue: 0.95)
        case .olympian: return Color(red: 1.00, green: 0.40, blue: 0.30)
        case .god:      return Color(red: 0.72, green: 0.45, blue: 1.00)
        }
    }

    /// Gradient used for badges and the tier-up celebration.
    var gradient: LinearGradient {
        LinearGradient(
            colors: [color.opacity(0.95), color.opacity(0.55)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// The tier above this one, or nil at the top of the ladder.
    var next: StrengthTier? {
        StrengthTier(rawValue: rawValue + 1)
    }
}

/// A lifter's standing on one exercise variant.
struct StrengthRank: Equatable {
    let tier: StrengthTier
    /// The e1RM this rank was computed from.
    let estimated1RM: Double
    /// Weight needed to reach the next tier, nil at `god` or when the exercise
    /// is not weight-ranked.
    let nextTierTarget: Double?
    let nextTier: StrengthTier?
    /// Progress through the current tier toward the next, 0...1.
    /// Nil when there is no next tier to progress toward.
    let progressToNext: Double?

    /// "92 lb from Gold" — the line that makes the rank actionable.
    var nextTierPrompt: String? {
        guard let nextTier, let target = nextTierTarget else { return nil }
        let remaining = max(0, target - estimated1RM)
        return "\(remaining.formattedWeight) lb from \(nextTier.displayName)"
    }
}
