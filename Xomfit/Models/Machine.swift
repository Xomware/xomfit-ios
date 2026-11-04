import Foundation

/// A specific branded machine a lifter can perform one or more catalog exercises on.
///
/// Multi-function units (leg extension/seated leg curl, pec fly/rear delt) map
/// to several exercises, so the mapping is a list rather than a single id.
struct Machine: Identifiable, Hashable {
    enum Loading: String {
        case plateLoaded, selectorized

        var displayName: String {
            switch self {
            case .plateLoaded: return "Plate-loaded"
            case .selectorized: return "Selectorized"
            }
        }
    }

    let id: String
    let brand: String
    let series: String
    let name: String
    let loading: Loading
    let muscleGroups: [MuscleGroup]
    let exerciseIds: [String]
    /// Overrides the exercise's grip options while this machine is selected.
    var grips: [GripType]? = nil
    /// Overrides the exercise's position options while this machine is selected.
    var positions: [ExercisePosition]? = nil

    var displayName: String { "\(series) \(name)" }
}
