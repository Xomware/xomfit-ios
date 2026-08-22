import Foundation
import SwiftUI

/// Ranks lifts against bodyweight-relative strength standards.
///
/// Ranking needs three things about the lifter — bodyweight, sex, and age — and
/// the app only reliably has the first. Bodyweight comes from the latest
/// `.weight` body measurement; sex and age are collected once and stored
/// locally. When they are missing the service still ranks, using midpoint
/// standards and no age allowance, and reports that the rank is provisional so
/// the UI can prompt rather than silently show a wrong number.
@MainActor
@Observable
final class StrengthLevelService {
    static let shared = StrengthLevelService()

    // MARK: - Lifter attributes

    /// Stored locally rather than on the profile row: it is only used for
    /// ranking, and it is the kind of thing people expect to stay on-device
    /// unless they opt into sharing it.
    @ObservationIgnored
    @AppStorage("lifterSex") private var sexRaw: String = LifterSex.unspecified.rawValue

    /// 0 means "not provided".
    @ObservationIgnored
    @AppStorage("lifterBirthYear") private var birthYear: Int = 0

    /// Manual bodyweight fallback for lifters who have not logged a measurement.
    @ObservationIgnored
    @AppStorage("lifterBodyweightLbs") private var manualBodyweight: Double = 0

    /// Latest logged bodyweight, refreshed from `MeasurementsService`.
    private(set) var loggedBodyweight: Double = 0

    var sex: LifterSex {
        get { LifterSex(rawValue: sexRaw) ?? .unspecified }
        set { sexRaw = newValue.rawValue }
    }

    /// Logged measurement wins over the manual value — it is the one that keeps
    /// itself current as the lifter's weight changes.
    var bodyweight: Double {
        loggedBodyweight > 0 ? loggedBodyweight : manualBodyweight
    }

    func setManualBodyweight(_ value: Double) { manualBodyweight = value }

    var age: Int? {
        guard birthYear > 0 else { return nil }
        let year = Calendar.current.component(.year, from: Date())
        let age = year - birthYear
        return (10...100).contains(age) ? age : nil
    }

    func setBirthYear(_ year: Int) { birthYear = year }

    /// True when a rank can be computed at all. Without bodyweight there is
    /// nothing to compare a lift against.
    var canRank: Bool { bodyweight > 0 }

    /// True when the rank is based on assumed rather than known attributes, so
    /// the UI can offer to improve it.
    var isProvisional: Bool { sex == .unspecified || age == nil }

    private init() {}

    // MARK: - Refresh

    /// Pulls the most recent bodyweight measurement into memory.
    func refreshBodyweight(userId: String) async {
        let measurements = await MeasurementsService.shared.fetchAll(userId: userId)
        if let latest = measurements
            .filter({ $0.kind == .weight })
            .max(by: { $0.recordedAt < $1.recordedAt }) {
            loggedBodyweight = latest.value
        }
    }

    // MARK: - Age adjustment

    /// Multiplier applied to the required thresholds.
    ///
    /// Strength standards are built around lifters in their physical prime, so
    /// holding a 55-year-old to the same absolute ratio as a 25-year-old makes
    /// the top ranks unreachable for reasons that have nothing to do with
    /// effort. This follows the shape of masters lifting coefficients: flat
    /// through the prime years, then an accelerating allowance. Younger lifters
    /// get a small allowance too, since teenagers are still developing.
    nonisolated static func ageFactor(for age: Int?) -> Double {
        guard let age else { return 1.0 }
        switch age {
        case ..<16:   return 0.80
        case 16...17: return 0.90
        case 18...23: return 0.97
        case 24...34: return 1.00
        case 35...39: return 0.97
        case 40...44: return 0.93
        case 45...49: return 0.88
        case 50...54: return 0.83
        case 55...59: return 0.77
        case 60...64: return 0.71
        case 65...69: return 0.64
        default:      return 0.57
        }
    }

    // MARK: - Ranking

    /// Rank for a given estimated 1RM on an exercise.
    ///
    /// Returns nil when the exercise is not weight-ranked (holds, mobility) or
    /// bodyweight is unknown.
    func rank(exerciseId: String, estimated1RM: Double) -> StrengthRank? {
        rank(
            exerciseId: exerciseId,
            estimated1RM: estimated1RM,
            bodyweight: bodyweight,
            sex: sex,
            age: age
        )
    }

    /// Pure ranking entry point — no stored state, so it is directly testable
    /// and usable for "what would I rank at X bodyweight" comparisons.
    nonisolated func rank(
        exerciseId: String,
        estimated1RM: Double,
        bodyweight: Double,
        sex: LifterSex,
        age: Int?
    ) -> StrengthRank? {
        guard let profile = StrengthStandards.profile(for: exerciseId),
              profile.basis != .notRanked,
              bodyweight > 0
        else { return nil }

        // Bodyweight movements are ranked on total load moved, so a strict
        // pull-up counts as the lifter's own bodyweight rather than zero.
        let effortLoad: Double = {
            switch profile.basis {
            case .bodyweightPlusAdded: return bodyweight + estimated1RM
            case .external, .notRanked: return estimated1RM
            }
        }()

        guard var thresholds = StrengthStandards.thresholds(
            exerciseId: exerciseId,
            bodyweight: bodyweight,
            sex: sex
        ) else { return nil }

        let factor = Self.ageFactor(for: age)
        if factor != 1.0 {
            thresholds = thresholds.map { $0 * factor }
        }

        let ranks = StrengthTier.ranked
        var achieved: StrengthTier = .unranked
        for (index, threshold) in thresholds.enumerated() where effortLoad >= threshold {
            achieved = ranks[index]
        }

        // Index of the next threshold to clear. `achieved` is .unranked (0) when
        // nothing is cleared, and its rawValue doubles as the count of cleared
        // thresholds, which is exactly the index of the next one.
        let nextIndex = achieved.rawValue
        let nextTier: StrengthTier? = nextIndex < ranks.count ? ranks[nextIndex] : nil
        let nextThreshold: Double? = nextIndex < thresholds.count ? thresholds[nextIndex] : nil

        // Progress is measured across the band between the tier just earned and
        // the next one, so a lifter who just ranked up starts near 0 rather than
        // jumping to a misleading high percentage.
        let progress: Double? = {
            guard let nextThreshold else { return nil }
            let floorValue = nextIndex > 0 ? thresholds[nextIndex - 1] : 0
            let band = nextThreshold - floorValue
            guard band > 0 else { return nil }
            return min(1, max(0, (effortLoad - floorValue) / band))
        }()

        // Reported back in the same terms the lifter enters weight, so for a
        // bodyweight movement the target is the *added* weight they need.
        let reportedTarget: Double? = {
            guard let nextThreshold else { return nil }
            switch profile.basis {
            case .bodyweightPlusAdded: return nextThreshold - bodyweight
            case .external, .notRanked: return nextThreshold
            }
        }()

        return StrengthRank(
            tier: achieved,
            estimated1RM: profile.basis == .bodyweightPlusAdded ? estimated1RM : effortLoad,
            nextTierTarget: reportedTarget,
            nextTier: nextTier,
            progressToNext: progress
        )
    }

    /// Ranks a set directly, doing the e1RM conversion and per-side handling.
    func rank(exerciseId: String, weight: Double, reps: Int, weightMode: WeightMode = .total) -> StrengthRank? {
        let effective = weightMode == .perSide ? weight * 2 : weight
        return rank(
            exerciseId: exerciseId,
            estimated1RM: Exercise.estimateMax(weight: effective, reps: reps)
        )
    }

    // MARK: - Aggregate

    /// One ranked lift — the lifter's best rank on a single exercise.
    struct RankedLift: Identifiable {
        var id: String { exerciseId }
        let exerciseId: String
        let exerciseName: String
        let rank: StrengthRank
    }

    /// Best rank held on each ranked exercise, strongest first.
    ///
    /// Deduped by exercise and keyed on the *highest* e1RM rather than the most
    /// recent: a rank is the best a lifter has done, not the last thing they
    /// logged. A bad day shouldn't demote them.
    ///
    /// Ties break on exercise name so the profile ordering is stable between
    /// renders rather than shuffling on every dictionary iteration.
    func rankedLifts(from records: [PersonalRecord]) -> [RankedLift] {
        var bestByExercise: [String: RankedLift] = [:]

        for record in records where record.kind == .e1rm {
            let e1rm = record.estimated1RM ?? Exercise.estimateMax(
                weight: record.weight, reps: record.reps
            )
            guard let rank = rank(exerciseId: record.exerciseId, estimated1RM: e1rm),
                  rank.tier != .unranked else { continue }

            let candidate = RankedLift(
                exerciseId: record.exerciseId,
                exerciseName: record.exerciseName,
                rank: rank
            )
            if let existing = bestByExercise[record.exerciseId],
               existing.rank.estimated1RM >= rank.estimated1RM {
                continue
            }
            bestByExercise[record.exerciseId] = candidate
        }

        return bestByExercise.values.sorted { lhs, rhs in
            if lhs.rank.tier != rhs.rank.tier { return lhs.rank.tier > rhs.rank.tier }
            if lhs.rank.estimated1RM != rhs.rank.estimated1RM {
                return lhs.rank.estimated1RM > rhs.rank.estimated1RM
            }
            return lhs.exerciseName < rhs.exerciseName
        }
    }

    /// Highest rank held on each exercise, for the profile tier breakdown.
    func tierDistribution(from records: [PersonalRecord]) -> [StrengthTier: Int] {
        var counts: [StrengthTier: Int] = [:]
        for lift in rankedLifts(from: records) {
            counts[lift.rank.tier, default: 0] += 1
        }
        return counts
    }
}
