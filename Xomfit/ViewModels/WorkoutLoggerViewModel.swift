import SwiftUI

@MainActor
@Observable
final class WorkoutLoggerViewModel {
    var workoutName: String = ""
    var exercises: [WorkoutExercise] = []
    var startTime = Date()
    var isActive = false
    var isSaving = false
    var errorMessage: String?

    // MARK: - Computed

    var duration: TimeInterval {
        Date().timeIntervalSince(startTime)
    }

    var durationString: String {
        let seconds = Int(duration)
        let minutes = seconds / 60
        let hours = minutes / 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes % 60, seconds % 60)
        }
        return String(format: "%d:%02d", minutes, seconds % 60)
    }

    var totalSets: Int {
        exercises.reduce(0) { $0 + $1.sets.count }
    }

    var completedSets: Int {
        exercises.reduce(0) { total, ex in
            total + ex.sets.filter { $0.completedAt != Date.distantPast }.count
        }
    }

    // MARK: - Workout Lifecycle

    func startWorkout(name: String) {
        workoutName = name.isEmpty ? "Workout" : name
        exercises = []
        startTime = Date()
        isActive = true
        errorMessage = nil
    }

    func discardWorkout() {
        workoutName = ""
        exercises = []
        isActive = false
        isSaving = false
        errorMessage = nil
    }

    // MARK: - Exercise Management

    func addExercise(_ exercise: Exercise) {
        let workoutExercise = WorkoutExercise(
            id: UUID().uuidString,
            exercise: exercise,
            sets: [],
            notes: nil
        )
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

        // Pre-fill weight/reps from the last set if available
        let lastSet = exercise.sets.last
        let newSet = WorkoutSet(
            id: UUID().uuidString,
            exerciseId: exercise.exercise.id,
            weight: lastSet?.weight ?? 0,
            reps: lastSet?.reps ?? 0,
            rpe: nil,
            isPersonalRecord: false,
            completedAt: Date.distantPast   // distantPast = not yet completed
        )
        exercises[exerciseIndex].sets.append(newSet)
    }

    func updateSet(exerciseIndex: Int, setIndex: Int, weight: Double, reps: Int) {
        guard exercises.indices.contains(exerciseIndex),
              exercises[exerciseIndex].sets.indices.contains(setIndex) else { return }
        exercises[exerciseIndex].sets[setIndex].weight = weight
        exercises[exerciseIndex].sets[setIndex].reps = reps
    }

    func completeSet(exerciseIndex: Int, setIndex: Int) {
        guard exercises.indices.contains(exerciseIndex),
              exercises[exerciseIndex].sets.indices.contains(setIndex) else { return }
        let isCurrentlyCompleted = exercises[exerciseIndex].sets[setIndex].completedAt != Date.distantPast
        if isCurrentlyCompleted {
            // Toggle off
            exercises[exerciseIndex].sets[setIndex].completedAt = Date.distantPast
        } else {
            exercises[exerciseIndex].sets[setIndex].completedAt = Date()
        }
    }

    func removeSet(exerciseIndex: Int, setIndex: Int) {
        guard exercises.indices.contains(exerciseIndex),
              exercises[exerciseIndex].sets.indices.contains(setIndex) else { return }
        exercises[exerciseIndex].sets.remove(at: setIndex)
    }

    // MARK: - Finish Workout

    func finishWorkout(userId: String) async {
        isSaving = true
        errorMessage = nil

        // Only keep completed sets (completedAt != distantPast) for the saved workout,
        // but keep all exercises that have at least one set
        let completedExercises: [WorkoutExercise] = exercises.compactMap { ex in
            let doneSets = ex.sets.filter { $0.completedAt != Date.distantPast }
            guard !doneSets.isEmpty else { return nil }
            return WorkoutExercise(
                id: ex.id,
                exercise: ex.exercise,
                sets: doneSets,
                notes: ex.notes
            )
        }

        let workout = Workout(
            id: UUID().uuidString,
            userId: userId,
            name: workoutName,
            exercises: completedExercises,
            startTime: startTime,
            endTime: Date(),
            notes: nil
        )

        do {
            try await WorkoutService.shared.saveWorkout(workout)
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
        discardWorkout()
    }
}
