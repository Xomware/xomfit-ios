import Foundation
import Combine

@MainActor
class WorkoutLoggerViewModel: ObservableObject {
    @Published var activeWorkout: Workout?
    @Published var isWorkoutActive = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var restTimeRemaining: TimeInterval = 0
    @Published var isRestTimerRunning = false
    @Published var currentExerciseIndex: Int?
    @Published var recentExercises: [Exercise] = []
    @Published var previousWorkoutExercises: [Exercise] = []
    @Published var showingRestTimer = false
    
    // UI State
    @Published var inputWeight = ""
    @Published var inputReps = ""
    @Published var inputRPE = ""
    @Published var selectedRestDuration: TimeInterval = 90 // Default 90 seconds
    
    private var timer: Timer?
    private var restTimer: Timer?
    private let workoutService = WorkoutService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Default rest times (seconds)
    let restDurations: [TimeInterval] = [45, 60, 90, 120, 180]
    
    init() {
        loadRecentExercises()
    }
    
    // MARK: - Workout Management
    
    func startWorkout(name: String) {
        let workout = Workout(
            id: UUID().uuidString,
            userId: "user-1",
            name: name,
            exercises: [],
            startTime: Date(),
            endTime: nil,
            notes: nil
        )
        self.activeWorkout = workout
        self.isWorkoutActive = true
        self.elapsedTime = 0
        startTimer()
    }
    
    func finishWorkout() {
        activeWorkout?.endTime = Date()
        stopTimer()
        stopRestTimer()
        isWorkoutActive = false
        
        if let workout = activeWorkout {
            // Save to service
            Task {
                try await workoutService.saveWorkout(workout)
            }
        }
    }
    
    func cancelWorkout() {
        activeWorkout = nil
        isWorkoutActive = false
        stopTimer()
        stopRestTimer()
    }
    
    // MARK: - Exercise Management
    
    func addExercise(_ exercise: Exercise) {
        let workoutExercise = WorkoutExercise(
            id: UUID().uuidString,
            exercise: exercise,
            sets: [],
            notes: nil
        )
        activeWorkout?.exercises.append(workoutExercise)
        currentExerciseIndex = (activeWorkout?.exercises.count ?? 1) - 1
        
        // Track recent exercise
        if !recentExercises.contains(where: { $0.id == exercise.id }) {
            recentExercises.insert(exercise, at: 0)
            if recentExercises.count > 10 {
                recentExercises.removeLast()
            }
        }
    }
    
    func quickAddExerciseFromPrevious(_ exercise: Exercise) {
        addExercise(exercise)
    }
    
    // MARK: - Set Logging
    
    func addSet(to exerciseIndex: Int, weight: Double, reps: Int, rpe: Double? = nil) {
        guard let workout = activeWorkout else { return }
        guard exerciseIndex < workout.exercises.count else { return }
        
        let set = WorkoutSet(
            id: UUID().uuidString,
            exerciseId: workout.exercises[exerciseIndex].exercise.id,
            weight: weight,
            reps: reps,
            rpe: rpe,
            isPersonalRecord: checkIfPersonalRecord(exerciseId: workout.exercises[exerciseIndex].exercise.id, weight: weight, reps: reps),
            completedAt: Date()
        )
        
        activeWorkout?.exercises[exerciseIndex].sets.append(set)
        
        // Clear inputs
        clearInputs()
        
        // Start rest timer
        startRestTimer()
    }
    
    func deleteSet(from exerciseIndex: Int, setIndex: Int) {
        guard let workout = activeWorkout else { return }
        guard exerciseIndex < workout.exercises.count else { return }
        guard setIndex < workout.exercises[exerciseIndex].sets.count else { return }
        
        activeWorkout?.exercises[exerciseIndex].sets.remove(at: setIndex)
    }
    
    func editSet(at exerciseIndex: Int, setIndex: Int, weight: Double, reps: Int, rpe: Double?) {
        guard let workout = activeWorkout else { return }
        guard exerciseIndex < workout.exercises.count else { return }
        guard setIndex < workout.exercises[exerciseIndex].sets.count else { return }
        
        activeWorkout?.exercises[exerciseIndex].sets[setIndex].weight = weight
        activeWorkout?.exercises[exerciseIndex].sets[setIndex].reps = reps
        activeWorkout?.exercises[exerciseIndex].sets[setIndex].rpe = rpe
    }
    
    func removeExercise(at index: Int) {
        guard let workout = activeWorkout else { return }
        guard index < workout.exercises.count else { return }
        
        activeWorkout?.exercises.remove(at: index)
        if currentExerciseIndex == index {
            currentExerciseIndex = nil
        }
    }
    
    // MARK: - Rest Timer
    
    func startRestTimer(duration: TimeInterval? = nil) {
        let duration = duration ?? selectedRestDuration
        restTimeRemaining = duration
        isRestTimerRunning = true
        showingRestTimer = true
        
        restTimer?.invalidate()
        restTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.restTimeRemaining -= 1
            if self?.restTimeRemaining ?? 0 <= 0 {
                self?.stopRestTimer()
            }
        }
    }
    
    func skipRestTimer() {
        stopRestTimer()
        showingRestTimer = false
    }
    
    func stopRestTimer() {
        restTimer?.invalidate()
        restTimer = nil
        isRestTimerRunning = false
        restTimeRemaining = 0
    }
    
    func pauseRestTimer() {
        restTimer?.invalidate()
        restTimer = nil
        isRestTimerRunning = false
    }
    
    func resumeRestTimer() {
        guard restTimeRemaining > 0 else { return }
        startRestTimer(duration: restTimeRemaining)
    }
    
    // MARK: - Timers
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.elapsedTime += 1
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    deinit {
        stopTimer()
        stopRestTimer()
    }
    
    // MARK: - Input Management
    
    func clearInputs() {
        inputWeight = ""
        inputReps = ""
        inputRPE = ""
    }
    
    func validateInputs() -> (valid: Bool, weight: Double?, reps: Int?) {
        guard let weight = Double(inputWeight), let reps = Int(inputReps) else {
            return (false, nil, nil)
        }
        guard weight > 0, reps > 0 else {
            return (false, nil, nil)
        }
        return (true, weight, reps)
    }
    
    // MARK: - Previous Workouts
    
    func loadPreviousWorkoutExercises() {
        // This would load from the workout service
        // For now, we'll use the recent exercises
        previousWorkoutExercises = recentExercises
    }
    
    private func loadRecentExercises() {
        // Load from local storage or defaults
        recentExercises = [
            Exercise.benchPress,
            Exercise.squat,
            Exercise.deadlift,
            Exercise.barbell_row,
            Exercise.overhead_press
        ]
    }
    
    // MARK: - Helper Methods
    
    private func checkIfPersonalRecord(exerciseId: String, weight: Double, reps: Int) -> Bool {
        // This would check against past records
        // For MVP, we'll implement this in the service
        return false
    }
    
    func formatTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) / 60 % 60
        let seconds = Int(interval) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    func getExerciseSets(at index: Int) -> [WorkoutSet] {
        guard let workout = activeWorkout else { return [] }
        guard index < workout.exercises.count else { return [] }
        return workout.exercises[index].sets
    }
    
    func getWorkoutStats() -> (totalSets: Int, totalVolume: Double) {
        guard let workout = activeWorkout else { return (0, 0) }
        let totalSets = workout.totalSets
        let totalVolume = workout.totalVolume
        return (totalSets, totalVolume)
    }
}
