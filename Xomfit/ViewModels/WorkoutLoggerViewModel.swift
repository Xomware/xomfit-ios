import SwiftUI

struct RemainingExercise: Identifiable {
    let index: Int
    let name: String
    var id: Int { index }
}

@MainActor
@Observable
final class WorkoutLoggerViewModel {
    var workoutName: String = ""
    var exercises: [WorkoutExercise] = []
    var startTime = Date()
    var isActive = false
    var isSaving = false
    var errorMessage: String?

    // Rest timer
    var restTimeRemaining: Double = 0
    var restDuration: Double = 0
    var isRestTimerActive: Bool = false

    // PR celebration — set when a completed set beats the user's record
    var newPR: PersonalRecord? = nil
    var showPRCelebration: Bool = false

    // Exercise transition — shown when all sets of an exercise are complete
    var showExerciseTransition: Bool = false
    var completedExerciseIndex: Int = 0
    var nextExerciseIndex: Int? = nil
    var remainingExercises: [RemainingExercise] = []

    /// Name of the exercise that was just completed (for the transition card header).
    var completedExerciseName: String {
        guard exercises.indices.contains(completedExerciseIndex) else { return "" }
        return exercises[completedExerciseIndex].exercise.name
    }

    /// The next exercise to suggest, if one exists.
    var nextExercise: WorkoutExercise? {
        guard let idx = nextExerciseIndex, exercises.indices.contains(idx) else { return nil }
        return exercises[idx]
    }

    // Focus mode — large gym-floor view
    var focusMode: Bool = false
    var focusExerciseIndex: Int = 0
    var focusSetIndex: Int = 0

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
        showExerciseTransition = false
        completedExerciseIndex = 0
        nextExerciseIndex = nil
        remainingExercises = []
        focusMode = false
        focusExerciseIndex = 0
        focusSetIndex = 0
        skipRestTimer()
    }

    func discardWorkout() {
        workoutName = ""
        exercises = []
        isActive = false
        isSaving = false
        errorMessage = nil
        newPR = nil
        showPRCelebration = false
        showExerciseTransition = false
        completedExerciseIndex = 0
        nextExerciseIndex = nil
        remainingExercises = []
        focusMode = false
        focusExerciseIndex = 0
        focusSetIndex = 0
        skipRestTimer()
    }

    func startFromTemplate(_ template: WorkoutTemplate, userId: String) {
        startWorkout(name: template.name, userId: userId)

        var builtExercises: [WorkoutExercise] = []
        for templateExercise in template.exercises {
            let lastSet = lastSetForExercise(templateExercise.exercise.id)
            let prefillWeight = lastSet?.weight ?? 0
            let prefillReps = lastSet?.reps ?? 0

            var sets: [WorkoutSet] = []
            for _ in 0..<templateExercise.targetSets {
                sets.append(WorkoutSet(
                    id: UUID().uuidString,
                    exerciseId: templateExercise.exercise.id,
                    weight: prefillWeight,
                    reps: prefillReps,
                    rpe: nil,
                    isPersonalRecord: false,
                    completedAt: Date.distantPast
                ))
            }

            builtExercises.append(WorkoutExercise(
                id: UUID().uuidString,
                exercise: templateExercise.exercise,
                sets: sets,
                notes: templateExercise.notes
            ))
        }
        exercises = builtExercises
    }

    // MARK: - Exercise Management

    func addExercise(_ exercise: Exercise) {
        // Look up last workout's weight/reps for this exercise
        let lastSet = lastSetForExercise(exercise.id)
        let prefillWeight = lastSet?.weight ?? 0
        let prefillReps = lastSet?.reps ?? 0

        let defaultSetCount = 3
        var sets: [WorkoutSet] = []
        for _ in 0..<defaultSetCount {
            sets.append(WorkoutSet(
                id: UUID().uuidString,
                exerciseId: exercise.id,
                weight: prefillWeight,
                reps: prefillReps,
                rpe: nil,
                isPersonalRecord: false,
                completedAt: Date.distantPast
            ))
        }

        let workoutExercise = WorkoutExercise(
            id: UUID().uuidString,
            exercise: exercise,
            sets: sets,
            notes: nil
        )
        exercises.append(workoutExercise)
    }

    /// Find the most recent set for an exercise from workout history.
    private func lastSetForExercise(_ exerciseId: String) -> WorkoutSet? {
        guard !activeUserId.isEmpty else { return nil }
        let workouts = WorkoutService.shared.fetchWorkoutsFromCache(userId: activeUserId)
        for workout in workouts {
            if let workoutExercise = workout.exercises.first(where: { $0.exercise.id == exerciseId }),
               let bestSet = workoutExercise.sets.last {
                return bestSet
            }
        }
        return nil
    }

    func removeExercise(at index: Int) {
        guard exercises.indices.contains(index) else { return }
        exercises.remove(at: index)
    }

    func moveExercise(from source: Int, direction: Int) {
        let destination = source + direction
        guard exercises.indices.contains(source),
              exercises.indices.contains(destination) else { return }
        exercises.swapAt(source, destination)
    }

    // MARK: - Exercise Config (Grip / Attachment / Position)

    func setGrip(exerciseIndex: Int, grip: GripType) {
        guard exercises.indices.contains(exerciseIndex) else { return }
        exercises[exerciseIndex].selectedGrip = exercises[exerciseIndex].selectedGrip == grip ? nil : grip
    }

    func setAttachment(exerciseIndex: Int, attachment: CableAttachment) {
        guard exercises.indices.contains(exerciseIndex) else { return }
        exercises[exerciseIndex].selectedAttachment = exercises[exerciseIndex].selectedAttachment == attachment ? nil : attachment
    }

    func setPosition(exerciseIndex: Int, position: ExercisePosition) {
        guard exercises.indices.contains(exerciseIndex) else { return }
        exercises[exerciseIndex].selectedPosition = exercises[exerciseIndex].selectedPosition == position ? nil : position
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
            // Start rest timer
            let exerciseCategory = exercises[exerciseIndex].exercise.category
            startRestTimer(for: exerciseCategory)
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

            // Check if all sets in this exercise are now complete
            let allDone = exercises[exerciseIndex].sets.allSatisfy { $0.completedAt != Date.distantPast }
            if allDone {
                completedExerciseIndex = exerciseIndex

                // Find the next incomplete exercise (prefer one after current, then wrap around)
                let afterCurrent = exercises.indices.first { idx in
                    idx > exerciseIndex && exercises[idx].sets.contains { $0.completedAt == Date.distantPast }
                }
                let beforeCurrent = exercises.indices.first { idx in
                    idx < exerciseIndex && exercises[idx].sets.contains { $0.completedAt == Date.distantPast }
                }
                nextExerciseIndex = afterCurrent ?? beforeCurrent

                // Build remaining exercises list (all incomplete, excluding current)
                remainingExercises = exercises.enumerated().compactMap { idx, ex in
                    guard idx != exerciseIndex,
                          ex.sets.contains(where: { $0.completedAt == Date.distantPast }) else { return nil }
                    return RemainingExercise(index: idx, name: ex.exercise.name)
                }

                showExerciseTransition = true
            }
        }
    }

    func removeSet(exerciseIndex: Int, setIndex: Int) {
        guard exercises.indices.contains(exerciseIndex),
              exercises[exerciseIndex].sets.indices.contains(setIndex) else { return }
        exercises[exerciseIndex].sets.remove(at: setIndex)
    }

    func toggleWeightMode(exerciseIndex: Int, setIndex: Int) {
        guard exercises.indices.contains(exerciseIndex),
              exercises[exerciseIndex].sets.indices.contains(setIndex) else { return }
        exercises[exerciseIndex].sets[setIndex].weightMode =
            exercises[exerciseIndex].sets[setIndex].weightMode == .total ? .perSide : .total
    }

    // MARK: - Focus Mode Navigation

    /// The exercise currently in focus, if valid.
    var focusExercise: WorkoutExercise? {
        exercises.indices.contains(focusExerciseIndex) ? exercises[focusExerciseIndex] : nil
    }

    /// The set currently in focus, if valid.
    var focusSet: WorkoutSet? {
        guard let ex = focusExercise,
              ex.sets.indices.contains(focusSetIndex) else { return nil }
        return ex.sets[focusSetIndex]
    }

    /// Advance to the next incomplete set. If the current exercise is done, move to the next exercise.
    func focusAdvance() {
        guard exercises.indices.contains(focusExerciseIndex) else { return }
        let ex = exercises[focusExerciseIndex]

        // Try next set in the same exercise
        if focusSetIndex + 1 < ex.sets.count {
            focusSetIndex += 1
            return
        }

        // Move to next exercise, first set
        if focusExerciseIndex + 1 < exercises.count {
            focusExerciseIndex += 1
            focusSetIndex = 0
        }
    }

    func focusPreviousExercise() {
        guard focusExerciseIndex > 0 else { return }
        focusExerciseIndex -= 1
        focusSetIndex = 0
    }

    func focusNextExercise() {
        guard focusExerciseIndex + 1 < exercises.count else { return }
        focusExerciseIndex += 1
        focusSetIndex = 0
    }

    /// Complete the focused set and auto-advance.
    func completeFocusedSet() {
        completeSet(exerciseIndex: focusExerciseIndex, setIndex: focusSetIndex)
        focusAdvance()
    }

    // MARK: - Exercise Transition Actions

    func addAnotherSet() {
        addSet(to: completedExerciseIndex)
        showExerciseTransition = false
    }

    func moveToExercise(index: Int) {
        if focusMode {
            focusExerciseIndex = index
            focusSetIndex = 0
        }
        showExerciseTransition = false
    }

    func dismissTransition() {
        showExerciseTransition = false
    }

    // MARK: - Rest Timer

    func startRestTimer(for category: ExerciseCategory) {
        let duration: Double = switch category {
        case .compound: 90
        case .isolation: 60
        case .cardio, .stretching: 30
        }
        restDuration = duration
        restTimeRemaining = duration
        isRestTimerActive = true
    }

    func tickRestTimer() {
        guard isRestTimerActive else { return }
        restTimeRemaining -= 1
    }

    func skipRestTimer() {
        restTimeRemaining = 0
        isRestTimerActive = false
    }

    func extendRestTimer(_ seconds: Double = 30) {
        restTimeRemaining += seconds
        restDuration += seconds
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
            // Only discard local state after successful save
            isSaving = false
            discardWorkout()
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }
}
