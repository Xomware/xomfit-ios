import Foundation

/// A pre-workout stretch with a suggested hold time and the muscle groups it loosens up.
/// Used by the warmup flow to build a short stretch routine before a workout.
struct Stretch: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var description: String
    /// Suggested hold time in seconds for one cycle/side.
    var durationSeconds: Int
    /// Muscle groups this stretch primarily targets.
    var targetMuscleGroups: [MuscleGroup]

    /// SF Symbol icon for this stretch (defaults to a flexibility figure).
    var icon: String { "figure.flexibility" }
}
