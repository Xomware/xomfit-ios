import Foundation

@MainActor
class WorkoutViewModel: ObservableObject {
    @Published var recentWorkouts: [Workout] = []
    @Published var activeWorkout: Workout?
    @Published var isWorkoutActive = false
    @Published var exercises: [Exercise] = Exercise.mockExercises
    
    init() {
        loadRecentWorkouts()
    }
    
    func loadRecentWorkouts() {
        recentWorkouts = [.mock, .mockFriendWorkout]
    }
    
    func startWorkout(name: String) {
        activeWorkout = Workout(
            id: UUID().uuidString,
            userId: "user-1",
            name: name,
            exercises: [],
            startTime: Date(),
            endTime: nil,
            notes: nil
        )
        isWorkoutActive = true
    }
    
    func addExercise(_ exercise: Exercise) {
        let workoutExercise = WorkoutExercise(
            id: UUID().uuidString,
            exercise: exercise,
            sets: [],
            notes: nil
        )
        activeWorkout?.exercises.append(workoutExercise)
    }
    
    func addSet(to exerciseIndex: Int, weight: Double, reps: Int, rpe: Double?) {
        let set = WorkoutSet(
            id: UUID().uuidString,
            exerciseId: activeWorkout?.exercises[exerciseIndex].exercise.id ?? "",
            weight: weight,
            reps: reps,
            rpe: rpe,
            isPersonalRecord: false,
            completedAt: Date()
        )
        activeWorkout?.exercises[exerciseIndex].sets.append(set)
    }
    
    func finishWorkout() {
        activeWorkout?.endTime = Date()
        if let workout = activeWorkout {
            recentWorkouts.insert(workout, at: 0)
        }
        activeWorkout = nil
        isWorkoutActive = false
    }
    
    func cancelWorkout() {
        activeWorkout = nil
        isWorkoutActive = false
    }
}
