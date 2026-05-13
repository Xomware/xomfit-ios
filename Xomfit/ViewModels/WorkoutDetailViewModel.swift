import Foundation
import SwiftUI

/// View model backing the edit mode on `WorkoutDetailView` (#365).
///
/// Holds an editable copy of a previously-saved `Workout` so the user can
/// fix mistakes (date, name, notes, location, rating, end time, per-set
/// weight/reps, add/remove sets, add/remove/reorder exercises) without
/// touching the original until they tap Save. Cancel reverts to the
/// originally-passed-in workout.
///
/// Save path mirrors `LogPastWorkoutViewModel.saveWorkout`: write through
/// `WorkoutService.updateWorkout` (upsert by id, wipes orphan child rows)
/// and patch the existing social-feed item via
/// `FeedService.updateFeedItemForWorkout` so the feed card stays in sync.
@MainActor
@Observable
final class WorkoutDetailViewModel {
    // MARK: - Original snapshot

    /// The pristine workout we were given. `cancel()` reverts `draft` to this.
    private(set) var original: Workout

    // MARK: - Editable draft

    /// Mutable copy the edit UI binds against. Mutated freely during edit mode;
    /// committed via `save()` or rolled back via `cancel()`.
    var draft: Workout

    // MARK: - Save State

    var isSaving: Bool = false
    var errorMessage: String? = nil

    // MARK: - Init

    init(workout: Workout) {
        self.original = workout
        self.draft = workout
    }

    // MARK: - Editable fields (typed bridges where Workout has optionals)

    /// `endTime` exposed as a non-optional date for the DatePicker. Falls back
    /// to `startTime` when the workout was never finished. Writing this back
    /// keeps `endTime` in sync.
    var endTimeBinding: Date {
        get { draft.endTime ?? draft.startTime }
        set { draft.endTime = newValue }
    }

    /// `notes` exposed as a non-optional string. Empty string round-trips to
    /// nil on save so we don't write back empty notes that decode awkwardly.
    var notesBinding: String {
        get { draft.notes ?? "" }
        set { draft.notes = newValue.isEmpty ? nil : newValue }
    }

    /// `location` exposed as a non-optional string. Empty string → nil on save.
    var locationBinding: String {
        get { draft.location ?? "" }
        set { draft.location = newValue.isEmpty ? nil : newValue }
    }

    /// `rating` exposed as a non-optional Int (0 = unset).
    var ratingBinding: Int {
        get { draft.rating ?? 0 }
        set { draft.rating = newValue > 0 ? newValue : nil }
    }

    // MARK: - Exercise Management

    /// Append a brand-new exercise with a single empty set (matching the
    /// `LogPastWorkoutViewModel` shape — user fills in weight/reps next).
    func addExercise(_ exercise: Exercise) {
        let newSet = WorkoutSet(
            id: UUID().uuidString,
            exerciseId: exercise.id,
            weight: 0,
            reps: 0,
            rpe: nil,
            isPersonalRecord: false,
            completedAt: draft.startTime
        )
        var we = WorkoutExercise(
            id: UUID().uuidString,
            exercise: exercise,
            sets: [newSet],
            notes: nil
        )
        we.selectedLaterality = exercise.defaultLaterality
        draft.exercises.append(we)
    }

    func removeExercise(at index: Int) {
        guard draft.exercises.indices.contains(index) else { return }
        draft.exercises.remove(at: index)
    }

    /// Swap the exercise at `index` with the one above it. No-op when at top.
    func moveExerciseUp(_ index: Int) {
        guard index > 0, draft.exercises.indices.contains(index) else { return }
        draft.exercises.swapAt(index, index - 1)
    }

    /// Swap the exercise at `index` with the one below it. No-op when at bottom.
    func moveExerciseDown(_ index: Int) {
        guard draft.exercises.indices.contains(index),
              index < draft.exercises.count - 1 else { return }
        draft.exercises.swapAt(index, index + 1)
    }

    // MARK: - Set Management

    /// Adds a set to an exercise, defaulting weight/reps to the prior set so
    /// the user doesn't have to retype.
    func addSet(to exerciseIndex: Int) {
        guard draft.exercises.indices.contains(exerciseIndex) else { return }
        let ex = draft.exercises[exerciseIndex]
        let last = ex.sets.last
        let newSet = WorkoutSet(
            id: UUID().uuidString,
            exerciseId: ex.exercise.id,
            weight: last?.weight ?? 0,
            reps: last?.reps ?? 0,
            rpe: nil,
            isPersonalRecord: false,
            completedAt: last?.completedAt ?? draft.startTime
        )
        draft.exercises[exerciseIndex].sets.append(newSet)
    }

    func removeSet(exerciseIndex: Int, setIndex: Int) {
        guard draft.exercises.indices.contains(exerciseIndex),
              draft.exercises[exerciseIndex].sets.indices.contains(setIndex) else { return }
        draft.exercises[exerciseIndex].sets.remove(at: setIndex)
    }

    func updateSet(exerciseIndex: Int, setIndex: Int, weight: Double, reps: Int) {
        guard draft.exercises.indices.contains(exerciseIndex),
              draft.exercises[exerciseIndex].sets.indices.contains(setIndex) else { return }
        draft.exercises[exerciseIndex].sets[setIndex].weight = weight
        draft.exercises[exerciseIndex].sets[setIndex].reps = reps
    }

    // MARK: - Validation

    /// Allow save only when there's a name and at least one set with reps.
    /// Mirrors the constraints used at log time so we never write a workout
    /// the rest of the app can't sensibly render.
    var canSave: Bool {
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }
        guard !draft.exercises.isEmpty else { return false }
        return draft.exercises.contains { ex in
            ex.sets.contains { $0.reps > 0 }
        }
    }

    /// True when the draft diverged from the original — used to gate
    /// the discard-changes prompt on cancel.
    var hasChanges: Bool {
        guard let lhs = try? JSONEncoder().encode(draft),
              let rhs = try? JSONEncoder().encode(original) else {
            return true
        }
        return lhs != rhs
    }

    // MARK: - Save / Cancel

    /// Persists the draft via `WorkoutService.updateWorkout`, then patches the
    /// matching feed item. Returns `true` on success so the caller can drop
    /// edit mode.
    func save() async -> Bool {
        guard canSave else { return false }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        // Strip empty sets (reps == 0) the same way the log-past flow does so
        // we never persist hollow rows.
        let cleaned = draft.exercises.compactMap { ex -> WorkoutExercise? in
            let valid = ex.sets.filter { $0.reps > 0 }
            guard !valid.isEmpty else { return nil }
            return WorkoutExercise(
                id: ex.id,
                exercise: ex.exercise,
                sets: valid,
                notes: ex.notes,
                selectedGrip: ex.selectedGrip,
                selectedAttachment: ex.selectedAttachment,
                selectedPosition: ex.selectedPosition,
                selectedLaterality: ex.selectedLaterality,
                supersetGroupId: ex.supersetGroupId,
                restSeconds: ex.restSeconds
            )
        }

        guard !cleaned.isEmpty else {
            errorMessage = "Add at least one set with reps before saving."
            return false
        }

        // Trim name; fall back to the original if the user cleared it.
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmedName.isEmpty ? original.name : trimmedName

        // Keep `endTime` nil if the user dragged it back before startTime.
        let normalizedEnd: Date? = {
            guard let end = draft.endTime else { return nil }
            return end > draft.startTime ? end : nil
        }()

        let finalWorkout = Workout(
            id: draft.id,
            userId: draft.userId,
            name: resolvedName,
            exercises: cleaned,
            startTime: draft.startTime,
            endTime: normalizedEnd,
            notes: draft.notes,
            location: draft.location,
            rating: draft.rating,
            tracks: draft.tracks
        )

        _ = await WorkoutService.shared.updateWorkout(finalWorkout)

        // Feed sync — best-effort. Don't fail the save if it errors.
        do {
            try await FeedService.shared.updateFeedItemForWorkout(
                workout: finalWorkout,
                userId: finalWorkout.userId
            )
        } catch {
            print("[WorkoutDetailViewModel] Feed update failed: \(error.localizedDescription)")
        }

        // Promote the saved workout as the new baseline so subsequent edits
        // diff against the just-saved state.
        original = finalWorkout
        draft = finalWorkout
        return true
    }

    /// Reverts the draft back to the originally-passed-in workout.
    func cancel() {
        draft = original
        errorMessage = nil
    }
}
