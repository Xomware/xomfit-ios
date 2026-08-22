import Foundation

/// Remembers the highest strength tier a lifter has reached on each exercise,
/// so crossing into a new one can be recognised as it happens.
///
/// A tier is a pure function of best e1RM, bodyweight, sex and age, so nothing
/// here is authoritative — it is entirely recoverable from PR history. That is
/// why `UserDefaults` is enough and why losing it is a non-event.
///
/// **Self-seeding.** The first time an exercise is seen, its tier is recorded
/// silently and no tier-up is reported. Without that rule, shipping this to a
/// lifter with years of history would fire a celebration for every lift in their
/// first workout — a flood that would teach them to ignore the banner
/// permanently. The cost is that a genuinely new exercise never celebrates its
/// first rank, which is correct: they didn't cross into it, they arrived there.
@MainActor
enum TierProgressStore {
    private static let storageKey = "xomfit_best_tier_by_exercise"

    /// Highest tier recorded for an exercise, or nil when it has never been seen.
    static func bestTier(for exerciseId: String) -> StrengthTier? {
        guard let raw = stored()[exerciseId] else { return nil }
        return StrengthTier(rawValue: raw)
    }

    /// Records a tier and reports whether it is a genuine promotion.
    ///
    /// Returns the tier that was crossed into, or nil when there is nothing to
    /// celebrate — no prior baseline (first sighting), no change, or a regression.
    @discardableResult
    static func record(_ tier: StrengthTier, for exerciseId: String) -> StrengthTier? {
        var map = stored()
        let previous = map[exerciseId].flatMap(StrengthTier.init(rawValue:))

        // Never lower a recorded tier. Bodyweight moves, and gaining weight can
        // drop a bodyweight-relative rank — demoting someone mid-set for that
        // would be a hostile way to deliver the news.
        guard tier > (previous ?? .unranked) else { return nil }

        map[exerciseId] = tier.rawValue
        UserDefaults.standard.set(map, forKey: storageKey)

        // First sighting seeds the baseline silently. See the note above.
        guard previous != nil else { return nil }
        return tier
    }

    /// Seeds baselines in bulk without reporting any promotions. Safe to call
    /// repeatedly — existing entries are never lowered or overwritten.
    static func seed(_ tiers: [String: StrengthTier]) {
        var map = stored()
        for (exerciseId, tier) in tiers {
            let previous = map[exerciseId].flatMap(StrengthTier.init(rawValue:)) ?? .unranked
            if tier > previous { map[exerciseId] = tier.rawValue }
        }
        UserDefaults.standard.set(map, forKey: storageKey)
    }

    /// Test seam — clears persisted progress.
    static func resetForTesting() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    private static func stored() -> [String: Int] {
        UserDefaults.standard.dictionary(forKey: storageKey) as? [String: Int] ?? [:]
    }
}
