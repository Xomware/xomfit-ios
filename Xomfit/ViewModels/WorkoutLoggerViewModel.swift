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

    // MARK: - Workout kind (#370)
    /// Format of the in-progress workout. Drives which runner UI is rendered
    /// (`ActiveWorkoutView` vs `TimedCircuitView`).
    var kind: WorkoutKind = .setsReps
    /// Goal duration in whole minutes for `.timedCircuit` / `.amrap` / `.emom`.
    var durationGoalMinutes: Int? = nil
    /// Goal round count for `.amrap` / `.emom`.
    var roundsGoal: Int? = nil

    /// Circuit rotation: which exercise the runner is currently showing.
    /// Wraps modulo `exercises.count`.
    var circuitExerciseIndex: Int = 0
    /// Circuit rotation: how many full rotations through `exercises` the user
    /// has completed. Increments when the index wraps past the last exercise.
    var circuitRound: Int = 0
    /// Round-by-round checkmarks keyed by exercise index. Each entry is the
    /// set of rounds (0-indexed) the user marked complete for that exercise.
    /// Used by `TimedCircuitView` to render per-round check pips.
    var circuitCompletedRounds: [Int: Set<Int>] = [:]

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
        defaultRestDuration = WorkoutLoggerViewModel.loadRestDuration()
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
        kind = .setsReps
        durationGoalMinutes = nil
        roundsGoal = nil
        circuitExerciseIndex = 0
        circuitRound = 0
        circuitCompletedRounds = [:]
        skipRestTimer()
        startLiveActivity()

        // Begin Now Playing capture — Apple Music only (see NowPlayingService docs).
        // Silent no-op when the user denied Apple Music access.
        NowPlayingService.shared.startCapture()
        // Spotify capture runs in parallel — also a silent no-op when not signed in (#347).
        SpotifyNowPlayingService.shared.startCapture()
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
        kind = .setsReps
        durationGoalMinutes = nil
        roundsGoal = nil
        circuitExerciseIndex = 0
        circuitRound = 0
        circuitCompletedRounds = [:]
        skipRestTimer()

        // Drop any captured Now Playing tracks — discarding the workout discards the soundtrack.
        _ = NowPlayingService.shared.stopCapture()
        _ = SpotifyNowPlayingService.shared.stopCapture()
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
            we.restSeconds = templateExercise.restSeconds
            // Carry the template's superset grouping into the live workout (#344).
            we.supersetGroupId = templateExercise.supersetGroupId
            builtExercises.append(we)
        }
        exercises = builtExercises
        updateLiveActivity()
    }

    // MARK: - Timed Circuit (#370)

    /// Start a timed-circuit workout: a rotation through `exercises` for
    /// `durationMinutes` total. No per-set reps/weight tracking — the runner
    /// (`TimedCircuitView`) cycles exercises and marks round-by-round completion.
    ///
    /// Each exercise gets a single placeholder set so the saved workout still
    /// renders in history. Sets are marked complete on finish based on
    /// `circuitCompletedRounds`.
    func startTimedCircuit(
        name: String,
        userId: String,
        exercises: [Exercise],
        durationMinutes: Int
    ) {
        startWorkout(name: name, userId: userId)
        kind = .timedCircuit
        durationGoalMinutes = max(1, durationMinutes)

        // Seed one placeholder set per exercise so the saved Workout has rows.
        var built: [WorkoutExercise] = []
        for ex in exercises {
            let placeholderSet = WorkoutSet(
                id: UUID().uuidString,
                exerciseId: ex.id,
                weight: 0,
                reps: 0,
                rpe: nil,
                isPersonalRecord: false,
                completedAt: Date.distantPast
            )
            var we = WorkoutExercise(
                id: UUID().uuidString,
                exercise: ex,
                sets: [placeholderSet],
                notes: nil
            )
            we.selectedLaterality = ex.defaultLaterality
            built.append(we)
        }
        self.exercises = built
        circuitExerciseIndex = 0
        circuitRound = 0
        circuitCompletedRounds = [:]
        updateLiveActivity()
    }

    /// Total elapsed for the active circuit, clamped at the goal duration.
    var circuitElapsedSeconds: Int {
        Int(duration)
    }

    /// Whole seconds remaining toward `durationGoalMinutes`. Floors at 0.
    var circuitRemainingSeconds: Int {
        guard let mins = durationGoalMinutes else { return 0 }
        let total = mins * 60
        return max(0, total - circuitElapsedSeconds)
    }

    /// Fraction of the circuit completed (0...1). Returns 0 when no goal is set.
    var circuitProgress: Double {
        guard let mins = durationGoalMinutes, mins > 0 else { return 0 }
        let total = Double(mins * 60)
        let elapsed = min(Double(circuitElapsedSeconds), total)
        return total > 0 ? elapsed / total : 0
    }

    /// True when the countdown has reached zero.
    var circuitTimeUp: Bool {
        circuitRemainingSeconds == 0 && durationGoalMinutes != nil
    }

    /// The exercise the circuit runner is currently showing, if any.
    var currentCircuitExercise: WorkoutExercise? {
        guard exercises.indices.contains(circuitExerciseIndex) else { return nil }
        return exercises[circuitExerciseIndex]
    }

    /// Advance to the next exercise in the rotation. Wrapping past the last
    /// exercise increments the round counter.
    func advanceCircuitExercise() {
        guard !exercises.isEmpty else { return }
        let next = circuitExerciseIndex + 1
        if next >= exercises.count {
            circuitExerciseIndex = 0
            circuitRound += 1
        } else {
            circuitExerciseIndex = next
        }
    }

    /// Toggle a round checkmark for the current circuit exercise.
    func toggleCurrentCircuitRoundComplete() {
        guard exercises.indices.contains(circuitExerciseIndex) else { return }
        var marks = circuitCompletedRounds[circuitExerciseIndex] ?? []
        if marks.contains(circuitRound) {
            marks.remove(circuitRound)
        } else {
            marks.insert(circuitRound)
        }
        circuitCompletedRounds[circuitExerciseIndex] = marks
    }

    /// True when the current exercise has its current round marked complete.
    var currentCircuitRoundIsComplete: Bool {
        circuitCompletedRounds[circuitExerciseIndex]?.contains(circuitRound) ?? false
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
               let bestSet = workoutExercise.sets
                .filter({ $0.completedAt != Date.distantPast && !$0.isDropSet })
                .max(by: { $0.weight < $1.weight }) {
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

    /// Update or clear the per-exercise note. Trims whitespace; treats empty strings as nil.
    func setNotes(exerciseIndex: Int, notes: String?) {
        guard exercises.indices.contains(exerciseIndex) else { return }
        let trimmed = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        exercises[exerciseIndex].notes = (trimmed?.isEmpty == false) ? trimmed : nil
    }

    /// Set or clear the per-exercise rest override. Pass nil to fall back to the global default.
    func setRestSeconds(exerciseIndex: Int, seconds: Int?) {
        guard exercises.indices.contains(exerciseIndex) else { return }
        exercises[exerciseIndex].restSeconds = seconds
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

            // Decide whether to start the rest timer based on superset / drop-set context.
            //
            // Skip rest when:
            //   - The next set on this exercise is a drop set (parent → drop chain stays back-to-back)
            //   - This exercise is mid-superset and another member still has a set queued for this round
            let nextSetIsDropSet: Bool = {
                let nextIdx = setIndex + 1
                let sets = exercises[exerciseIndex].sets
                return sets.indices.contains(nextIdx) && sets[nextIdx].isDropSet
            }()

            let supersetSiblingIndex = nextSupersetMember(after: exerciseIndex, currentSetIndex: setIndex)
            let inSupersetRound = supersetSiblingIndex != nil

            let shouldStartRest = !nextSetIsDropSet && !inSupersetRound
            if shouldStartRest {
                startRestTimer(for: exerciseIndex)
            }

            // Auto-advance focus for supersets — jump to the sibling exercise's matching set
            if let siblingIdx = supersetSiblingIndex {
                focusExerciseIndex = siblingIdx
                if let nextIncomplete = exercises[siblingIdx].sets.firstIndex(where: { $0.completedAt == Date.distantPast }) {
                    focusSetIndex = nextIncomplete
                } else {
                    focusSetIndex = 0
                }
            }
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

                // Suppress the transition card while still mid-superset round — the focus
                // already advanced to the next member, so no card needed.
                if !inSupersetRound {
                    showExerciseTransition = true
                }
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

    // MARK: - Supersets

    /// Returns the indices of all exercises sharing this superset group.
    func supersetMembers(groupId: UUID) -> [Int] {
        exercises.indices.filter { exercises[$0].supersetGroupId == groupId }
    }

    /// Returns the indices of all exercises in the same superset as `exerciseIndex`,
    /// or nil if it isn't part of a superset.
    func supersetMembers(forExercise exerciseIndex: Int) -> [Int]? {
        guard exercises.indices.contains(exerciseIndex),
              let groupId = exercises[exerciseIndex].supersetGroupId else { return nil }
        return supersetMembers(groupId: groupId)
    }

    /// Position label inside the group ("A", "B", "C", ...) — used by UI badges.
    /// Wraps to "AA", "BB", ... after Z; the alphabet covers any realistic group size.
    func supersetLetter(forExercise exerciseIndex: Int) -> String? {
        guard let members = supersetMembers(forExercise: exerciseIndex),
              let pos = members.firstIndex(of: exerciseIndex) else { return nil }
        let alphabet = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
                        "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]
        return alphabet[pos % alphabet.count]
    }

    /// Toggles a superset across the given exercise indices.
    /// - If the indices already share the same group, they are ungrouped.
    /// - Otherwise they all get a new shared group id.
    /// Requires at least 2 valid indices.
    func toggleSuperset(exerciseIndices: [Int]) {
        let validIndices = exerciseIndices.filter { exercises.indices.contains($0) }
        guard validIndices.count >= 2 else { return }

        let groupIds = Set(validIndices.map { exercises[$0].supersetGroupId })
        if groupIds.count == 1, let onlyId = groupIds.first, onlyId != nil {
            // All share the same group — ungroup them
            for idx in validIndices {
                exercises[idx].supersetGroupId = nil
            }
        } else {
            let newGroupId = UUID()
            for idx in validIndices {
                exercises[idx].supersetGroupId = newGroupId
            }
        }
    }

    /// Convenience: group `exerciseIndex` with the next exercise in the list, or
    /// (if it already has a group) ungroup the entire group.
    func toggleSupersetWithNext(exerciseIndex: Int) {
        guard exercises.indices.contains(exerciseIndex) else { return }

        if let members = supersetMembers(forExercise: exerciseIndex) {
            for idx in members {
                exercises[idx].supersetGroupId = nil
            }
            return
        }

        let nextIndex = exerciseIndex + 1
        guard exercises.indices.contains(nextIndex) else { return }
        toggleSuperset(exerciseIndices: [exerciseIndex, nextIndex])
    }

    /// During an in-progress superset round, find the next member that still
    /// owes a set at `currentSetIndex`. Returns nil when the current member
    /// finished the round (or it isn't a superset).
    private func nextSupersetMember(after exerciseIndex: Int, currentSetIndex: Int) -> Int? {
        guard let members = supersetMembers(forExercise: exerciseIndex),
              members.count > 1,
              let pos = members.firstIndex(of: exerciseIndex) else { return nil }

        // Iterate ring starting just after the current member
        for offset in 1..<members.count {
            let candidate = members[(pos + offset) % members.count]
            let sets = exercises[candidate].sets
            // Match the same round (same set index) when possible — fall back to any incomplete set.
            if sets.indices.contains(currentSetIndex),
               sets[currentSetIndex].completedAt == Date.distantPast {
                return candidate
            }
            if sets.contains(where: { $0.completedAt == Date.distantPast }) {
                return candidate
            }
        }
        return nil
    }

    // MARK: - Drop Sets

    /// Insert a drop set immediately after `parentSetIndex`. The drop set inherits
    /// reps from the parent and uses 80% of the parent's weight as a reasonable starting point.
    func addDropSet(exerciseIndex: Int, parentSetIndex: Int) {
        guard exercises.indices.contains(exerciseIndex),
              exercises[exerciseIndex].sets.indices.contains(parentSetIndex) else { return }

        let parent = exercises[exerciseIndex].sets[parentSetIndex]
        let droppedWeight = (parent.weight * 0.8).rounded(.toNearestOrEven)
        let dropSet = WorkoutSet(
            id: UUID().uuidString,
            exerciseId: parent.exerciseId,
            weight: max(droppedWeight, 0),
            reps: parent.reps,
            rpe: nil,
            isPersonalRecord: false,
            completedAt: Date.distantPast,
            weightMode: parent.weightMode,
            isDropSet: true
        )

        // Insert right after the parent. If the parent is itself a drop set, the new
        // drop set still slots immediately after — keeping the chain contiguous.
        let insertIndex = parentSetIndex + 1
        exercises[exerciseIndex].sets.insert(dropSet, at: insertIndex)
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

    /// Starts the rest timer using the per-exercise override when set, otherwise falls
    /// back to the global default. Reading the override at fire-time means edits to
    /// a pill mid-workout take effect on the very next set.
    func startRestTimer(for exerciseIndex: Int) {
        let override = exercises.indices.contains(exerciseIndex)
            ? exercises[exerciseIndex].restSeconds
            : nil
        let duration = Double(override ?? Int(defaultRestDuration))
        guard duration > 0 else { return }
        restDuration = duration
        restTimeRemaining = duration
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

        // Broadcast the same snapshot to the paired Apple Watch (#256).
        // No-op when no watch is paired / WCSession isn't supported.
        let watchState = WatchWorkoutState(
            workoutName: workoutName,
            currentExercise: currentExName,
            setNumber: currentSetNumber,
            totalSets: currentExerciseTotalSets,
            isResting: isRestTimerActive,
            restEndDate: restEnd,
            isPaused: isPaused,
            elapsedSeconds: Int(duration)
        )
        WatchSyncService.shared.send(state: watchState)
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

        // For sets/reps workouts: keep only completed sets per exercise.
        // For timed-circuit workouts: synthesize one "completed" set per round the
        // user checked off, so the saved Workout reflects what they actually did.
        let completedExercises: [WorkoutExercise]
        if kind == .timedCircuit {
            completedExercises = exercises.enumerated().compactMap { idx, ex in
                let rounds = circuitCompletedRounds[idx] ?? []
                guard !rounds.isEmpty else { return nil }
                let now = Date()
                let circuitSets: [WorkoutSet] = rounds.sorted().map { _ in
                    WorkoutSet(
                        id: UUID().uuidString,
                        exerciseId: ex.exercise.id,
                        weight: 0,
                        reps: 0,
                        rpe: nil,
                        isPersonalRecord: false,
                        completedAt: now
                    )
                }
                var copy = WorkoutExercise(
                    id: ex.id,
                    exercise: ex.exercise,
                    sets: circuitSets,
                    notes: ex.notes,
                    selectedGrip: ex.selectedGrip,
                    selectedAttachment: ex.selectedAttachment,
                    selectedPosition: ex.selectedPosition,
                    selectedLaterality: ex.selectedLaterality
                )
                copy.supersetGroupId = ex.supersetGroupId
                copy.restSeconds = ex.restSeconds
                return copy
            }
        } else {
            completedExercises = exercises.compactMap { ex in
                let doneSets = ex.sets.filter { $0.completedAt != Date.distantPast }
                guard !doneSets.isEmpty else { return nil }
                var copy = WorkoutExercise(
                    id: ex.id,
                    exercise: ex.exercise,
                    sets: doneSets,
                    notes: ex.notes,
                    selectedGrip: ex.selectedGrip,
                    selectedAttachment: ex.selectedAttachment,
                    selectedPosition: ex.selectedPosition,
                    selectedLaterality: ex.selectedLaterality
                )
                copy.supersetGroupId = ex.supersetGroupId
                copy.restSeconds = ex.restSeconds
                return copy
            }
        }

        let trimmedNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)

        // Pull the Now Playing capture and attach it to the saved workout.
        // Empty list when the user denied Apple Music access or only used non-Apple Music sources.
        // Spotify tracks (when authed) merge in alongside Apple Music — sort by capture time so
        // the saved soundtrack reflects actual play order across sources (#347).
        let appleMusicTracks = NowPlayingService.shared.stopCapture()
        let spotifyTracks = SpotifyNowPlayingService.shared.stopCapture()
        let capturedTracks = (appleMusicTracks + spotifyTracks)
            .sorted { $0.capturedAt < $1.capturedAt }

        let workout = Workout(
            id: UUID().uuidString,
            userId: userId,
            name: workoutName,
            exercises: completedExercises,
            startTime: startTime,
            endTime: Date(),
            notes: trimmedNotes?.isEmpty == false ? trimmedNotes : nil,
            location: trimmedLocation.isEmpty ? nil : trimmedLocation,
            rating: rating > 0 ? rating : nil,
            tracks: capturedTracks,
            kind: kind,
            durationGoalMinutes: durationGoalMinutes,
            roundsGoal: roundsGoal
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
            let streak = WorkoutInsights.currentStreak(workouts: allWorkouts)
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

}
