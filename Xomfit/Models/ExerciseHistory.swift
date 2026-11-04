import Foundation

/// The lifter's past workouts, indexed once per session for the active-workout
/// screen. Every set row reads from this on every render, and
/// `WorkoutService.fetchWorkoutsFromCache` decodes the entire cached history
/// on each call — doing that per row per keystroke is what made typing lag.
struct ExerciseHistory {
    /// Working sets (drop sets excluded) from the most recent workout that
    /// contained each variant, in logged order, keyed by `ExerciseVariant.key`.
    let previousSets: [String: [WorkoutSet]]
    /// Heaviest set ever logged per exercise id, tie-broken on reps.
    let personalRecords: [String: WorkoutSet]

    init(workouts: [Workout]) {
        var previous: [String: [WorkoutSet]] = [:]
        var records: [String: WorkoutSet] = [:]

        for workout in workouts.sorted(by: { $0.startTime > $1.startTime }) {
            for logged in workout.exercises {
                let key = ExerciseVariant.key(for: logged)
                // Newest-first, so the first sighting of a variant is its last session.
                if previous[key] == nil {
                    let working = logged.sets.filter { !$0.isDropSet && ($0.weight > 0 || $0.reps > 0) }
                    if !working.isEmpty { previous[key] = working }
                }

                let id = logged.exercise.id
                for set in logged.sets where set.weight > 0 && set.reps > 0 {
                    guard let best = records[id] else { records[id] = set; continue }
                    if set.weight > best.weight || (set.weight == best.weight && set.reps > best.reps) {
                        records[id] = set
                    }
                }
            }
        }
        previousSets = previous
        personalRecords = records
    }

    /// Weight and reps for working set `ordinal` of a variant: last session's
    /// set in the same position, or its final set when today has more sets
    /// than last time. Zeros when the variant has never been logged.
    func prefill(variantKey: String, ordinal: Int) -> (weight: Double, reps: Int) {
        guard let sets = previousSets[variantKey], let last = sets.last else { return (0, 0) }
        let set = sets.indices.contains(ordinal) ? sets[ordinal] : last
        return (set.weight, set.reps)
    }
}
