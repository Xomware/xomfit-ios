import ActivityKit
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
    var isPresented: Bool = false
    var isSaving = false
    var errorMessage: String?
    var location: String = ""
    var rating: Int = 0

    // Rest timer
    var restTimeRemaining: Double = 0
    var restDuration: Double = 0
    var isRestTimerActive: Bool = false

    // Pause state — freezes elapsed timer + rest countdown without ending the workout.
    // In-memory only (not persisted).
    var isPaused: Bool = false
    var pausedAt: Date? = nil
    var totalPausedDuration: TimeInterval = 0

    /// Default rest duration in seconds. Reactive stored property; syncs to UserDefaults via didSet.
    var defaultRestDuration: Double = WorkoutLoggerViewModel.loadRestDuration() {
        didSet { UserDefaults.standard.set(defaultRestDuration, forKey: "restDuration") }
    }

    private static func loadRestDuration() -> Double {
        let stored = UserDefaults.standard.double(forKey: "restDuration")
        return stored > 0 ? stored : 90
    }

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
    /// Used by the exercise transition card when all sets of an exercise are done.
    var nextExercise: WorkoutExercise? {
        guard let idx = nextExerciseIndex, exercises.indices.contains(idx) else { return nil }
        return exercises[idx]
    }

    /// The upcoming exercise shown during rest timer — computed from the current focus position.
    /// Unlike `nextExercise`, this updates after every set, not just when an exercise completes.
    var upcomingExercise: WorkoutExercise? {
        guard exercises.count > 1 else { return nil }
        // If current exercise still has incomplete sets, no "next" to show
        let currentEx = exercises.indices.contains(focusExerciseIndex) ? exercises[focusExerciseIndex] : nil
        let allCurrentDone = currentEx?.sets.allSatisfy { $0.completedAt != Date.distantPast } ?? false
        guard allCurrentDone else { return nil }
        // Find next exercise with incomplete sets
        let afterCurrent = exercises.indices.first { idx in
            idx > focusExerciseIndex && exercises[idx].sets.contains { $0.completedAt == Date.distantPast }
        }
        let beforeCurrent = exercises.indices.first { idx in
            idx < focusExerciseIndex && exercises[idx].sets.contains { $0.completedAt == Date.distantPast }
        }
        if let idx = afterCurrent ?? beforeCurrent {
            return exercises[idx]
        }
        return nil
    }

    /// True when every set across all exercises is complete.
    var allExercisesComplete: Bool {
        !exercises.isEmpty && exercises.allSatisfy { ex in
            ex.sets.allSatisfy { $0.completedAt != Date.distantPast }
        }
    }

    // Focus mode — large gym-floor view
    var focusMode: Bool = false
    var focusExerciseIndex: Int = 0
    var focusSetIndex: Int = 0

    // Live Activity
    private var liveActivity: Activity<XomfitWidgetAttributes>?
    private var liveActivityUpdateCounter = 0

    // Stored so completeSet can fire PR checks without needing the caller to pass it
    private(set) var activeUserId: String = ""

    // MARK: - Computed

    var duration: TimeInterval {
        var elapsed = Date().timeIntervalSince(startTime) - totalPausedDuration
        // If currently paused, also subtract the in-progress paused interval so the
        // displayed time stays frozen at the moment of pausing.
        if isPaused, let pausedAt {
            elapsed -= Date().timeIntervalSince(pausedAt)
        }
        return max(0, elapsed)
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
        isPaused = false
        pausedAt = nil
        totalPausedDuration = 0
        skipRestTimer()
        startLiveActivity()
    }

    func discardWorkout() {
        endLiveActivity()
        workoutName = ""
        exercises = []
        isActive = false
        isPresented = false
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
        isPaused = false
        pausedAt = nil
        totalPausedDuration = 0
        location = ""
        rating = 0
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

            var we = WorkoutExercise(
                id: UUID().uuidString,
                exercise: templateExercise.exercise,
                sets: sets,
                notes: templateExercise.notes
            )
            we.selectedLaterality = templateExercise.exercise.defaultLaterality
            builtExercises.append(we)
        }
        exercises = builtExercises
        updateLiveActivity()
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

        var workoutExercise = WorkoutExercise(
            id: UUID().uuidString,
            exercise: exercise,
            sets: sets,
            notes: nil
        )
        workoutExercise.selectedLaterality = exercise.defaultLaterality
        exercises.append(workoutExercise)
        updateLiveActivity()
    }

    /// Find the most recent set for an exercise from workout history.
    /// Public for use by `SetRowView` PR-aware suggestions (#250).
    func lastSetForExercise(_ exerciseId: String) -> WorkoutSet? {
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

    /// Find the highest-weight set ever performed for an exercise from cached workout history.
    /// Tie-breaks on reps so `145×6` beats `145×5`. Used by SetRowView for PR hint + new-PR badge (#250).
    func personalRecordForExercise(_ exerciseId: String) -> WorkoutSet? {
        guard !activeUserId.isEmpty else { return nil }
        let workouts = WorkoutService.shared.fetchWorkoutsFromCache(userId: activeUserId)
        let allSets = workouts
            .flatMap { $0.exercises }
            .filter { $0.exercise.id == exerciseId }
            .flatMap { $0.sets }
            .filter { $0.weight > 0 && $0.reps > 0 }
        guard !allSets.isEmpty else { return nil }
        return allSets.max { lhs, rhs in
            if lhs.weight != rhs.weight { return lhs.weight < rhs.weight }
            return lhs.reps < rhs.reps
        }
    }

    func removeExercise(at index: Int) {
        guard exercises.indices.contains(index) else { return }
        exercises.remove(at: index)
        updateLiveActivity()
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

    func setLaterality(exerciseIndex: Int, laterality: Laterality) {
        guard exercises.indices.contains(exerciseIndex) else { return }
        exercises[exerciseIndex].selectedLaterality = laterality
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
        updateLiveActivity()
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

    // MARK: - Current-Exercise Pill Accessors (#253)
    //
    // These additive computed properties drive the persistent "current exercise"
    // pill in `ActiveWorkoutView`. They never mutate state and are safe to call
    // even when `focusExerciseIndex` is out of bounds.

    /// Name of the exercise currently in focus, or `nil` when there is no valid focus.
    var currentExerciseName: String? {
        focusExercise?.exercise.name
    }

    /// 1-based set number of the focused set, clamped to `[1, totalSets]`.
    /// Returns `1` when there is no focused exercise (caller should branch on `currentExerciseName`).
    var currentSetNumber: Int {
        let total = currentExerciseTotalSets
        guard total > 0 else { return 1 }
        return min(max(focusSetIndex + 1, 1), total)
    }

    /// Total number of sets in the focused exercise. `0` when no exercise in focus.
    var currentExerciseTotalSets: Int {
        focusExercise?.sets.count ?? 0
    }

    /// Free navigation jump used by the exercise-jumper sheet (#253).
    ///
    /// Distinct from `moveToExercise(index:)`, which is part of the post-set
    /// transition-card flow. `jumpToExercise` deliberately does NOT toggle
    /// `showExerciseTransition` — the user is mid-workout and explicitly chose
    /// to switch exercises, not completing one.
    func jumpToExercise(index: Int) {
        guard exercises.indices.contains(index) else { return }
        focusExerciseIndex = index
        // Land on the first incomplete set; fall back to set 0 when fully complete.
        if let setIdx = exercises[index].sets.firstIndex(where: { $0.completedAt == Date.distantPast }) {
            focusSetIndex = setIdx
        } else {
            focusSetIndex = 0
        }
    }

    /// Sync focus indices to the first incomplete exercise/set. Called when entering focus mode from list mode.
    func syncFocusToCurrentExercise() {
        // Find first exercise with an incomplete set
        for (exIdx, ex) in exercises.enumerated() {
            if let setIdx = ex.sets.firstIndex(where: { $0.completedAt == Date.distantPast }) {
                focusExerciseIndex = exIdx
                focusSetIndex = setIdx
                return
            }
        }
        // All done — point to last exercise, last set
        if let last = exercises.indices.last {
            focusExerciseIndex = last
            focusSetIndex = max(exercises[last].sets.count - 1, 0)
        }
    }

    /// Complete the focused set and auto-advance.
    func completeFocusedSet() {
        completeSet(exerciseIndex: focusExerciseIndex, setIndex: focusSetIndex)
        focusAdvance()
    }

    // MARK: - Exercise Transition Actions

    func addAnotherSet() {
        addSet(to: completedExerciseIndex)
        // Point focus at the newly added set so focus mode doesn't jump away
        if focusMode {
            focusExerciseIndex = completedExerciseIndex
            focusSetIndex = exercises[completedExerciseIndex].sets.count - 1
        }
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

    /// Timestamp when the rest timer was started — used to survive background suspension.
    private var restTimerStartDate: Date?

    func startRestTimer(for category: ExerciseCategory) {
        guard defaultRestDuration > 0 else { return }
        restDuration = defaultRestDuration
        restTimeRemaining = defaultRestDuration
        isRestTimerActive = true
        restTimerStartDate = Date()
        updateLiveActivity()
    }

    /// Called when the app returns to foreground. Recalculates rest timer based on wall-clock time elapsed.
    /// Skipped while paused — the countdown is frozen.
    func recalculateRestTimer() {
        guard isRestTimerActive, !isPaused, let startDate = restTimerStartDate else { return }
        let elapsed = Date().timeIntervalSince(startDate)
        restTimeRemaining = restDuration - elapsed
    }

    func tickRestTimer() {
        guard isRestTimerActive, !isPaused else { return }
        restTimeRemaining -= 1
    }

    func skipRestTimer() {
        restTimeRemaining = 0
        isRestTimerActive = false
        updateLiveActivity()
    }

    func extendRestTimer(_ seconds: Double = 30) {
        restTimeRemaining += seconds
        restDuration += seconds
        updateLiveActivity()
    }

    // MARK: - Pause / Resume

    /// Freeze (or resume) the elapsed-time counter and the rest-timer countdown without
    /// ending the workout. Pause state is in-memory only — not persisted.
    func togglePause() {
        if isPaused {
            // Resume: account for the time spent paused
            if let pausedAt {
                let pausedFor = Date().timeIntervalSince(pausedAt)
                totalPausedDuration += pausedFor

                // Roll the rest timer's start anchor forward by the paused duration so
                // recalculateRestTimer() and Live Activity restEndDate math stay correct.
                if let start = restTimerStartDate {
                    restTimerStartDate = start.addingTimeInterval(pausedFor)
                }
            }
            pausedAt = nil
            isPaused = false
        } else {
            // Pause
            pausedAt = Date()
            isPaused = true
        }
        updateLiveActivity()
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
        Haptics.prCelebration()
    }

    // MARK: - Live Activity

    private func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // End any stale activities to prevent stacking (e.g. cancel + restart)
        for activity in Activity<XomfitWidgetAttributes>.activities {
            let finalState = XomfitWidgetAttributes.ContentState(
                elapsedSeconds: 0,
                completedSets: 0,
                totalSets: 0,
                currentExercise: "Ended",
                totalExercises: 0
            )
            Task { await activity.end(.init(state: finalState, staleDate: nil), dismissalPolicy: .immediate) }
        }

        let attributes = XomfitWidgetAttributes(
            workoutName: workoutName,
            startTime: startTime
        )
        let state = XomfitWidgetAttributes.ContentState(
            elapsedSeconds: 0,
            completedSets: completedSets,
            totalSets: totalSets,
            currentExercise: exercises.first?.exercise.name ?? "Warming up",
            totalExercises: exercises.count
        )

        do {
            liveActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            print("[LiveActivity] Failed to start: \(error)")
        }
    }

    private func updateLiveActivity() {
        guard let activity = liveActivity else { return }

        let currentExName = exercises.first(where: { ex in
            ex.sets.contains(where: { $0.completedAt == Date.distantPast })
        })?.exercise.name ?? "Finishing up"

        // While paused, suppress restEndDate so the widget renders a static "Paused" pill
        // instead of an active countdown.
        let restEnd: Date? = (isRestTimerActive && restTimeRemaining > 0 && !isPaused)
            ? Date().addingTimeInterval(restTimeRemaining)
            : nil

        let overtime = isRestTimerActive && restTimeRemaining <= 0 && !isPaused

        let state = XomfitWidgetAttributes.ContentState(
            elapsedSeconds: Int(duration),
            completedSets: completedSets,
            totalSets: totalSets,
            currentExercise: currentExName,
            totalExercises: exercises.count,
            isResting: isRestTimerActive,
            restTimeRemaining: Int(self.restTimeRemaining),
            restEndDate: restEnd,
            isOvertime: overtime,
            isPaused: isPaused
        )

        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    private func endLiveActivity() {
        guard let activity = liveActivity else { return }
        let finalState = XomfitWidgetAttributes.ContentState(
            elapsedSeconds: Int(duration),
            completedSets: completedSets,
            totalSets: totalSets,
            currentExercise: "Workout Complete",
            totalExercises: exercises.count
        )
        Task {
            await activity.end(.init(state: finalState, staleDate: nil), dismissalPolicy: .after(.now + 5))
        }
        liveActivity = nil
    }

    func tickLiveActivity() {
        liveActivityUpdateCounter += 1
        // Update frequently during rest transitions, otherwise every 30s
        // (timer style handles real-time display, we just need state pushes)
        let interval = isRestTimerActive ? 5 : 30
        if liveActivityUpdateCounter % interval == 0 {
            updateLiveActivity()
        }
    }

    // MARK: - Finish Workout

    func finishWorkout(userId: String, notes: String? = nil, photoURLs: [String]? = nil) async {
        endLiveActivity()
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
                notes: ex.notes,
                selectedGrip: ex.selectedGrip,
                selectedAttachment: ex.selectedAttachment,
                selectedPosition: ex.selectedPosition,
                selectedLaterality: ex.selectedLaterality
            )
        }

        let trimmedNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
        let workout = Workout(
            id: UUID().uuidString,
            userId: userId,
            name: workoutName,
            exercises: completedExercises,
            startTime: startTime,
            endTime: Date(),
            notes: trimmedNotes?.isEmpty == false ? trimmedNotes : nil,
            location: trimmedLocation.isEmpty ? nil : trimmedLocation,
            rating: rating > 0 ? rating : nil
        )

        do {
            // Only post to feed if the workout actually persisted to Supabase.
            // Prevents orphan feed items (posts with no matching workout row).
            let persisted = await WorkoutService.shared.saveWorkout(workout)
            if persisted {
                try await FeedService.shared.postWorkoutToFeed(workout: workout, userId: userId, caption: workout.notes, photoURLs: photoURLs)
            }

            // Update widget data
            let allWorkouts = await WorkoutService.shared.fetchWorkouts(userId: userId)
            let weekStart = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
            let weekWorkouts = allWorkouts.filter { $0.startTime >= weekStart }
            let weeklyVolume = weekWorkouts.reduce(0.0) { $0 + $1.totalVolume }
            let streak = calculateStreak(from: allWorkouts)
            let latestPR = allWorkouts.flatMap { $0.exercises.flatMap { $0.sets } }
                .filter { $0.isPersonalRecord }
                .max(by: { $0.completedAt < $1.completedAt })
            let prText: String? = if let pr = latestPR,
                let ex = allWorkouts.flatMap({ $0.exercises }).first(where: { $0.sets.contains(where: { $0.id == pr.id }) }) {
                "\(ex.exercise.name) \(Int(pr.weight)) lbs"
            } else {
                nil
            }
            WidgetDataService.shared.updateAfterWorkout(
                streak: streak,
                weeklyVolume: weeklyVolume,
                weeklyWorkouts: weekWorkouts.count,
                lastWorkoutName: workout.name,
                lastWorkoutDate: workout.startTime,
                recentPR: prText
            )

            // Only discard local state after successful save
            isSaving = false
            discardWorkout()
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }

    private func calculateStreak(from workouts: [Workout]) -> Int {
        let calendar = Calendar.current
        let workoutDays = Set(workouts.map { calendar.startOfDay(for: $0.startTime) })
        var streak = 0
        var day = calendar.startOfDay(for: Date())
        while workoutDays.contains(day) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }
}
