import Foundation

/// Stable identity for "this exercise, performed this specific way".
///
/// A rope pushdown and a straight-bar pushdown are the same `Exercise` but not
/// the same lift — the achievable weight differs enough that sharing a personal
/// record between them makes both records meaningless. The same is true of a
/// unilateral dumbbell row (weight per side) versus a bilateral one.
///
/// The key is the unit of PR tracking and of "last time you did this" history.
/// It is written to `personal_records.variant_key` and must stay stable across
/// releases — changing how a key is built orphans every record under the old key.
enum ExerciseVariant {

    /// Builds the variant key for a logged exercise.
    ///
    /// Only attributes that materially change the achievable load participate.
    /// Position (seated/standing/incline) is deliberately included — an incline
    /// press and a flat press are genuinely different lifts. Rest duration and
    /// notes are not, so they are excluded.
    ///
    /// Components are joined with `|` and absent components collapse to `-`, so
    /// the key is fixed-arity and stays parseable if it ever needs to be split.
    static func key(
        exerciseId: String,
        grip: GripType? = nil,
        attachment: CableAttachment? = nil,
        position: ExercisePosition? = nil,
        laterality: Laterality = .bilateral
    ) -> String {
        [
            exerciseId,
            grip?.rawValue ?? "-",
            attachment?.rawValue ?? "-",
            position?.rawValue ?? "-",
            laterality.rawValue
        ].joined(separator: "|")
    }

    /// Convenience overload for a logged exercise in a workout.
    static func key(for workoutExercise: WorkoutExercise) -> String {
        key(
            exerciseId: workoutExercise.exercise.id,
            grip: workoutExercise.selectedGrip,
            attachment: workoutExercise.selectedAttachment,
            position: workoutExercise.selectedPosition,
            laterality: workoutExercise.selectedLaterality
        )
    }

    /// The plain-exercise key, matching how pre-variant records were backfilled.
    /// Used when reading legacy records that predate variant segmentation.
    static func legacyKey(exerciseId: String) -> String { exerciseId }

    /// Human-readable suffix describing the variant, e.g. "Rope · Single".
    /// Returns nil when the exercise was performed in its default configuration,
    /// so callers can render just the exercise name in the common case.
    static func displaySuffix(
        grip: GripType? = nil,
        attachment: CableAttachment? = nil,
        position: ExercisePosition? = nil,
        laterality: Laterality = .bilateral
    ) -> String? {
        var parts: [String] = []
        if let attachment { parts.append(attachment.displayName) }
        if let grip { parts.append(grip.displayName) }
        if let position { parts.append(position.displayName) }
        if laterality != .bilateral { parts.append(laterality.displayName) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
