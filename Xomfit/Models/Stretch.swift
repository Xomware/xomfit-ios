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
    /// Body-area grouping used to organize the Stretches list (#388).
    /// Optional + default keeps existing call sites compiling and any future
    /// JSON decoding tolerant of the older shape.
    var category: StretchCategory = .fullBody

    /// SF Symbol icon for this stretch (defaults to a flexibility figure).
    var icon: String { "figure.flexibility" }
}

/// Body-area grouping for stretches. Drives the sectioned list on the
/// Stretches screen (#388) and helps templates be coherent ("Upper Body Mobility",
/// "Lower Body Cooldown", etc.). Independent of `MuscleGroup` because the
/// "Hips" and "Mobility" groupings are flow-oriented, not strict 1:1 maps.
enum StretchCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case upperBody
    case lowerBody
    case hips
    case core
    case fullBody

    var id: String { rawValue }

    /// Section title shown in the Stretches view.
    var displayName: String {
        switch self {
        case .upperBody: return "Upper Body"
        case .lowerBody: return "Lower Body"
        case .hips:      return "Hips"
        case .core:      return "Core & Back"
        case .fullBody:  return "Full Body / Mobility"
        }
    }

    /// SF Symbol used as the section / row leading glyph.
    var icon: String {
        switch self {
        case .upperBody: return "figure.arms.open"
        case .lowerBody: return "figure.step.training"
        case .hips:      return "figure.cooldown"
        case .core:      return "figure.core.training"
        case .fullBody:  return "figure.flexibility"
        }
    }

    /// Order categories are presented in the Stretches list view (#388).
    /// "Full Body / Mobility" leads because that's where most users start.
    static let displayOrder: [StretchCategory] = [
        .fullBody,
        .upperBody,
        .lowerBody,
        .hips,
        .core,
    ]
}
