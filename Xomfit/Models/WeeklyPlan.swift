import Foundation

/// An explicit weekly training goal: a target session count plus optional focus
/// regions. Drives the goal-directed `GoalBaseline` nudge strategy (Phase 3).
///
/// Local-only (persisted by `WeeklyPlanService` as a single JSON blob). No stored
/// week boundary — week framing comes from `WorkoutInsights.userCalendar()` at
/// evaluation time so the plan tracks the user's `weekStartDay` preference live.
///
/// Named `WeeklyPlan` (NOT `TrainingGoal`, which is the unrelated training-style
/// enum in `Models/TrainingGoal.swift`).
struct WeeklyPlan: Codable, Equatable {
    /// Workouts/week target, e.g. 4. Clamp `1...14` at the UI layer.
    var targetSessions: Int
    /// Seam-3 focus vocabulary. `[]` means "session-count goal, no body-part focus".
    var focusRegions: [TrainingRegion]

    /// Focus muscles expanded via the Seam-3 reverse map (`TrainingRegion.muscles`),
    /// deduped preserving first occurrence.
    var focusMuscles: [MuscleGroup] {
        var seen = Set<MuscleGroup>()
        var result: [MuscleGroup] = []
        for region in focusRegions {
            for muscle in region.muscles where !seen.contains(muscle) {
                seen.insert(muscle)
                result.append(muscle)
            }
        }
        return result
    }
}
