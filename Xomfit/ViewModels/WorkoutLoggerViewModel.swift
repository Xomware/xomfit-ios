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

    // PR celebration — set when a completed set beats the user's record
    var newPR: PersonalRecord? = nil
    var showPRCelebration: Bool = false

    // Stored so completeSet can fire PR checks without needing the caller to pass it
    private(set) var activeUserId: String = ""

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

    func startWorkout(name: String, userId: String = "") {
        workoutName = name.isEmpty ? "Workout" : name
        exercises = []
        startTime = Date()
        isActive = true
        errorMessage = nil
        activeUserId = userId
        newPR = nil
        showPRCelebration = false
    }

    func discardWorkout() {
        workoutName = ""
        exercises = []
        isActive = false
        isSaving = false
        errorMessage = nil
        newPR = nil
        showPRCelebration = false
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
            exercises[exerciseIndex].sets[setIndex].isPersonalRecord = false
        } else {
            exercises[exerciseIndex].sets[setIndex].completedAt = Date()
            // Fire PR check asynchronously — non-blocking
            let set = exercises[exerciseIndex].sets[setIndex]
            let exercise = exercises[exerciseIndex].exercise
            Task {
                await checkForPR(
                    set: set,
                    exercise: exercise,
                    exerciseIndex: exerciseIndex,
                    setIndex: setIndex
                )
            }
        }
    }

    func removeSet(exerciseIndex: Int, setIndex: Int) {
        guard exercises.indices.contains(exerciseIndex),
              exercises[exerciseIndex].sets.indices.contains(setIndex) else { return }
        exercises[exerciseIndex].sets.remove(at: setIndex)
    }

    // MARK: - PR Detection

    private func checkForPR(
        set: WorkoutSet,
        exercise: Exercise,
        exerciseIndex: Int,
        setIndex: Int
    ) async {
        guard !activeUserId.isEmpty, set.reps > 0, set.weight > 0 else { return }

        let pr = await PRService.shared.checkForPR(
            exerciseId: exercise.id,
            exerciseName: exercise.name,
            weight: set.weight,
            reps: set.reps,
            userId: activeUserId
        )

        guard let pr else { return }

        // Mark the set as a PR in the local state
        if exercises.indices.contains(exerciseIndex),
           exercises[exerciseIndex].sets.indices.contains(setIndex) {
            exercises[exerciseIndex].sets[setIndex].isPersonalRecord = true
        }

        // Trigger the celebration banner
        newPR = pr
        showPRCelebration = true
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
            // Auto-post to feed after saving
            try await FeedService.shared.postWorkoutToFeed(workout: workout, userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
        discardWorkout()
    }
}
