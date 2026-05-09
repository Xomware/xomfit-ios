import Foundation

/// Shared filter state for workout views (Mine / Recent / Templates / Friends).
///
/// An empty filter (no search text, no selections) matches everything.
/// Combined predicates AND together — a result must satisfy every active criterion.
struct WorkoutFilter: Equatable {
    var searchText: String = ""
    var muscleGroup: MuscleGroup? = nil
    var equipment: Equipment? = nil

    /// True when no criteria are set — i.e. nothing is being filtered out.
    var isEmpty: Bool {
        trimmedSearch.isEmpty && muscleGroup == nil && equipment == nil
    }

    private var trimmedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Lowercased, trimmed search query for matching.
    private var query: String {
        trimmedSearch.lowercased()
    }

    // MARK: - Template matching

    func matches(_ template: WorkoutTemplate) -> Bool {
        if isEmpty { return true }

        let allMuscles = template.exercises.flatMap { $0.exercise.muscleGroups }
        if let mg = muscleGroup, !allMuscles.contains(mg) {
            return false
        }

        let allEquipment = template.exercises.map { $0.exercise.equipment }
        if let eq = equipment, !allEquipment.contains(eq) {
            return false
        }

        if !query.isEmpty {
            let nameHit = template.name.lowercased().contains(query)
            let descHit = template.description.lowercased().contains(query)
            let exerciseHit = template.exercises.contains { ex in
                ex.exercise.name.lowercased().contains(query)
            }
            if !(nameHit || descHit || exerciseHit) {
                return false
            }
        }

        return true
    }

    // MARK: - Workout matching

    func matches(_ workout: Workout) -> Bool {
        if isEmpty { return true }

        let allMuscles = workout.exercises.flatMap { $0.exercise.muscleGroups }
        if let mg = muscleGroup, !allMuscles.contains(mg) {
            return false
        }

        let allEquipment = workout.exercises.map { $0.exercise.equipment }
        if let eq = equipment, !allEquipment.contains(eq) {
            return false
        }

        if !query.isEmpty {
            let nameHit = workout.name.lowercased().contains(query)
            let exerciseHit = workout.exercises.contains { ex in
                ex.exercise.name.lowercased().contains(query)
            }
            if !(nameHit || exerciseHit) {
                return false
            }
        }

        return true
    }
}
