import Foundation
import SwiftUI

/// View model for retroactively logging a workout that already happened.
/// No live timer, no rest timer — pure data entry that ends with a save through the
/// same path used by `WorkoutLoggerViewModel.finishWorkout` (`WorkoutService.shared.saveWorkout`).
@MainActor
@Observable
final class LogPastWorkoutViewModel {
    // MARK: - Form State

    var workoutDate: Date = Date()
    var name: String = ""
    /// Optional duration in minutes. `nil` when the field is empty.
    var durationMinutes: Int? = nil
    var exercises: [WorkoutExercise] = []

    // MARK: - Save State

    var isSaving: Bool = false
    var errorMessage: String? = nil

    // MARK: - Defaults

    static let defaultName = "Logged Workout"

    // MARK: - Validation

    /// At least one exercise with at least one set with reps > 0 is required.
    var canSave: Bool {
        guard !exercises.isEmpty else { return false }
        return exercises.contains { ex in
            ex.sets.contains { $0.reps > 0 }
        }
    }

    // MARK: - Exercise Management

    func addExercise(_ exercise: Exercise) {
        let defaultSetCount = 3
        var sets: [WorkoutSet] = []
        for _ in 0..<defaultSetCount {
            sets.append(WorkoutSet(
                id: UUID().uuidString,
                exerciseId: exercise.id,
                weight: 0,
                reps: 0,
                rpe: nil,
                isPersonalRecord: false,
                completedAt: Date.distantPast
            ))
        }
        var workoutExercise = WorkoutExercise(
            id: UUID().uuidString,
            exercise: exercise,
            sets: sets,
            notes: nil
        )
        workoutExercise.selectedLaterality = exercise.defaultLaterality
        exercises.append(workoutExercise)
    }

    func removeExercise(at index: Int) {
        guard exercises.indices.contains(index) else { return }
        exercises.remove(at: index)
    }

    // MARK: - Set Management

    func addSet(to exerciseIndex: Int) {
        guard exercises.indices.contains(exerciseIndex) else { return }
        let exercise = exercises[exerciseIndex]
        let lastSet = exercise.sets.last
        let newSet = WorkoutSet(
            id: UUID().uuidString,
            exerciseId: exercise.exercise.id,
            weight: lastSet?.weight ?? 0,
            reps: lastSet?.reps ?? 0,
            rpe: nil,
            isPersonalRecord: false,
            completedAt: Date.distantPast
        )
        exercises[exerciseIndex].sets.append(newSet)
    }

    func updateSet(exerciseIndex: Int, setIndex: Int, weight: Double, reps: Int) {
        guard exercises.indices.contains(exerciseIndex),
              exercises[exerciseIndex].sets.indices.contains(setIndex) else { return }
        exercises[exerciseIndex].sets[setIndex].weight = weight
        exercises[exerciseIndex].sets[setIndex].reps = reps
    }

    func removeSet(exerciseIndex: Int, setIndex: Int) {
        guard exercises.indices.contains(exerciseIndex),
              exercises[exerciseIndex].sets.indices.contains(setIndex) else { return }
        exercises[exerciseIndex].sets.remove(at: setIndex)
    }

    // MARK: - Save

    /// Persists the workout via the same path `WorkoutLoggerViewModel.finishWorkout` uses:
    /// `WorkoutService.shared.saveWorkout` (cache + Supabase) plus `FeedService.postWorkoutToFeed` on success.
    /// Sets are stamped completed at the workout's `startTime` so they show up in history.
    func saveWorkout(userId: String) async -> Bool {
        guard canSave else { return false }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmedName.isEmpty ? Self.defaultName : trimmedName

        let startTime = workoutDate

        // Only keep sets with reps > 0 — empty rows are noise. Stamp them completed at startTime
        // so history queries treat them as real sets (matches behavior of `finishWorkout`,
        // which filters out distant-past completedAt sets before save).
        let savedExercises: [WorkoutExercise] = exercises.compactMap { ex in
            let validSets = ex.sets.enumerated().compactMap { (offset, set) -> WorkoutSet? in
                guard set.reps > 0 else { return nil }
                var stamped = set
                // Tiny offset per set so identical timestamps don't collide in PR/sort logic.
                stamped.completedAt = startTime.addingTimeInterval(Double(offset))
                return stamped
            }
            guard !validSets.isEmpty else { return nil }
            return WorkoutExercise(
                id: ex.id,
                exercise: ex.exercise,
                sets: validSets,
                notes: ex.notes,
                selectedGrip: ex.selectedGrip,
                selectedAttachment: ex.selectedAttachment,
                selectedPosition: ex.selectedPosition,
                selectedLaterality: ex.selectedLaterality
            )
        }

        guard !savedExercises.isEmpty else {
            errorMessage = "Add at least one set with reps before saving."
            return false
        }

        let endTime: Date? = durationMinutes.map { startTime.addingTimeInterval(TimeInterval($0) * 60) }

        let workout = Workout(
            id: UUID().uuidString,
            userId: userId,
            name: resolvedName,
            exercises: savedExercises,
            startTime: startTime,
            endTime: endTime,
            notes: nil,
            location: nil,
            rating: nil
        )

        // Reuse the same persistence path as the live workout flow.
        let persisted = await WorkoutService.shared.saveWorkout(workout)
        if persisted {
            do {
                try await FeedService.shared.postWorkoutToFeed(
                    workout: workout,
                    userId: userId,
                    caption: nil,
                    photoURLs: nil
                )
            } catch {
                // Feed post failure shouldn't block save success — log and continue.
                print("[LogPastWorkout] Feed post failed: \(error.localizedDescription)")
            }
        }

        return true
    }

    // MARK: - Reset

    func reset() {
        workoutDate = Date()
        name = ""
        durationMinutes = nil
        exercises = []
        isSaving = false
        errorMessage = nil
    }
}
