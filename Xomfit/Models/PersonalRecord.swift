import Foundation

/// What a record is measuring. A lifter cares about both "best single effort
/// ever, at any rep count" and "best ever 5-rep set" — they answer different
/// questions and neither subsumes the other.
enum PRKind: String, Codable {
    /// Best estimated 1RM across all rep ranges. One per variant.
    case e1rm
    /// Heaviest weight at one specific rep count. One per variant per rep count.
    case repRange = "rep_range"
}

struct PersonalRecord: Codable, Identifiable {
    let id: String
    var userId: String
    var exerciseId: String
    var exerciseName: String
    var weight: Double
    var reps: Int
    var date: Date
    var previousBest: Double?

    // MARK: - Variant + e1RM (20260811)

    /// What this record measures. Defaults to `.repRange` so records decoded
    /// from before this field existed keep their original meaning.
    var kind: PRKind = .repRange
    /// Identity of the exercise *as performed* — see `ExerciseVariant`.
    /// Defaults to the bare exercise id, matching the migration's backfill.
    var variantKey: String?
    var estimated1RM: Double?
    var previous1RM: Double?
    var weightMode: WeightMode = .total
    var selectedGrip: GripType?
    var selectedAttachment: CableAttachment?
    var selectedLaterality: Laterality = .bilateral
    var workoutId: String?

    /// Effective variant key, falling back to the plain exercise id for legacy
    /// records written before variant segmentation existed.
    var effectiveVariantKey: String {
        variantKey ?? ExerciseVariant.legacyKey(exerciseId: exerciseId)
    }

    /// "Bench Press · Rope · Single" — the variant made legible.
    var displayName: String {
        guard let suffix = ExerciseVariant.displaySuffix(
            grip: selectedGrip,
            attachment: selectedAttachment,
            laterality: selectedLaterality
        ) else { return exerciseName }
        return "\(exerciseName) · \(suffix)"
    }

    var improvement: Double? {
        guard let prev = previousBest else { return nil }
        return weight - prev
    }

    var improvementString: String? {
        guard let imp = improvement else { return nil }
        return "+\(imp.formattedWeight) lbs"
    }

    /// Gain in estimated 1RM, which is the meaningful delta for an `.e1rm`
    /// record — comparing raw weight across different rep counts is not.
    var improvement1RM: Double? {
        guard let current = estimated1RM, let prev = previous1RM else { return nil }
        return current - prev
    }
}

// MARK: - Mock Data
extension PersonalRecord {
    static let mockPRs: [PersonalRecord] = [
        PersonalRecord(id: "pr-1", userId: "user-1", exerciseId: "ex-1", exerciseName: "Bench Press", weight: 235, reps: 3, date: Date(), previousBest: 225),
        PersonalRecord(id: "pr-2", userId: "user-1", exerciseId: "ex-2", exerciseName: "Squat", weight: 315, reps: 5, date: Date().addingTimeInterval(-86400 * 3), previousBest: 305),
        PersonalRecord(id: "pr-3", userId: "user-1", exerciseId: "ex-3", exerciseName: "Deadlift", weight: 405, reps: 1, date: Date().addingTimeInterval(-86400 * 7), previousBest: 395),
    ]
}
