import Foundation
import Observation

/// MVVM bridge for the offline workout generator.
///
/// Owns the config state (selected muscles, time budget, set count, seed) and the
/// derived preview `WorkoutTemplate`. This is the **only** layer that touches
/// services: it pulls cached history from `WorkoutService`, builds the familiarity
/// map, calls the pure `WorkoutGenerator`, and bridges Save (`TemplateService`).
/// Start Now is handled by the view via the existing `WorkoutLoggerViewModel`
/// session + warmup gate, reading `previewTemplate` from here.
///
/// Views bind to this object and never call `WorkoutGenerator` or services directly.
@MainActor
@Observable
final class WorkoutGeneratorViewModel {

    // MARK: - Config state

    /// The single underlying selection. Split chips and the muscle grid both
    /// mutate this set; the generator only ever consumes the resulting set.
    var selectedMuscles: Set<MuscleGroup> = []
    /// Total session budget in minutes (drives exercise count).
    var timeBudgetMinutes: Int = 45
    /// Working sets per exercise.
    var targetSets: Int = 3
    /// Current seed — new per "Generate" tap, stable within a preview so reroll
    /// is reproducible.
    private(set) var seed: UInt64 = 0

    /// The generated preview, or nil before the first Generate.
    private(set) var previewTemplate: WorkoutTemplate?
    /// True between tapping Generate and rendering the preview. The generator is
    /// instant/offline, so this is essentially always false — kept only so the
    /// view can disable the button during the synchronous build, never a spinner.
    private(set) var isGenerating = false

    // MARK: - Dependencies

    private let generator = WorkoutGenerator()

    // MARK: - Bounds (for sliders / steppers)

    let minTime = 15
    let maxTime = 120
    let minSets = 2
    let maxSets = 6

    var canGenerate: Bool { !selectedMuscles.isEmpty }

    // MARK: - Selection

    /// Toggle every muscle in a region. If the region is fully selected, clears
    /// it; otherwise selects all of its muscles (Seam-3 reverse map).
    func toggleRegion(_ region: TrainingRegion) {
        let muscles = Set(region.muscles)
        if muscles.isSubset(of: selectedMuscles) {
            selectedMuscles.subtract(muscles)
        } else {
            selectedMuscles.formUnion(muscles)
        }
    }

    /// True when every muscle in the region is currently selected.
    func isRegionSelected(_ region: TrainingRegion) -> Bool {
        Set(region.muscles).isSubset(of: selectedMuscles)
    }

    func toggleMuscle(_ muscle: MuscleGroup) {
        if selectedMuscles.contains(muscle) {
            selectedMuscles.remove(muscle)
        } else {
            selectedMuscles.insert(muscle)
        }
    }

    /// Phase-2 entry point: pre-seed the config with a single muscle from the
    /// training nudge. Added now so Phase 2 needs no view-model change.
    func preseed(muscle: MuscleGroup) {
        selectedMuscles = [muscle]
    }

    // MARK: - Generate

    /// Build a fresh preview. Rolls a new seed each tap (stable within the preview
    /// for reroll). Pulls cached history → familiarity map → pure engine.
    func generate(userId: String) {
        guard canGenerate else { return }
        isGenerating = true
        defer { isGenerating = false }

        seed = UInt64.random(in: UInt64.min...UInt64.max)
        let familiarity = familiarityMap(userId: userId)

        previewTemplate = generator.generate(
            targets: orderedTargets,
            timeBudgetMinutes: timeBudgetMinutes,
            targetSets: targetSets,
            familiarity: familiarity,
            seed: seed
        )
    }

    /// Reroll a single slot in the current preview. Reuses the stable seed so the
    /// result is reproducible; only the named slot changes.
    func rerollSlot(_ slot: Int, userId: String) {
        guard let template = previewTemplate else { return }
        let familiarity = familiarityMap(userId: userId)
        previewTemplate = generator.reroll(
            slot: slot,
            in: template,
            targets: orderedTargets,
            familiarity: familiarity,
            seed: seed
        )
    }

    // MARK: - Save

    /// Persist the current preview as a custom template (forces `isCustom`,
    /// dedupes by id inside `TemplateService`).
    func saveTemplate() {
        guard let template = previewTemplate else { return }
        TemplateService.shared.saveCustomTemplate(template)
    }

    /// Reset to a clean config (used when the sheet is dismissed and reopened).
    func reset() {
        selectedMuscles = []
        timeBudgetMinutes = 45
        targetSets = 3
        seed = 0
        previewTemplate = nil
    }

    // MARK: - Familiarity (history walk)

    /// Build `exerciseId → logged-set count` from cached workouts. Walks every
    /// `workout.exercises[].exercise.id` and sums `sets.count`. Pure read off the
    /// cache — no network.
    private func familiarityMap(userId: String) -> [String: Int] {
        let workouts = WorkoutService.shared.fetchWorkoutsFromCache(userId: userId)
        var map: [String: Int] = [:]
        for workout in workouts {
            for exercise in workout.exercises {
                map[exercise.exercise.id, default: 0] += exercise.sets.count
            }
        }
        return map
    }

    /// Selection as a stable-ordered array (enum declaration order) so generation
    /// is deterministic for a given selection + seed.
    private var orderedTargets: [MuscleGroup] {
        MuscleGroup.allCases.filter { selectedMuscles.contains($0) }
    }
}
