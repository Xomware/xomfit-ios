import Foundation

/// Local workout storage (in-memory for now, SwiftData in next iteration)
@MainActor
class WorkoutStore: ObservableObject {
    static let shared = WorkoutStore()
    
    @Published var workouts: [Workout] = []
    @Published var personalRecords: [String: PersonalRecord] = [:] // exerciseId -> best PR
    
    func save(_ workout: Workout) {
        workouts.insert(workout, at: 0)
        detectPRs(in: workout)
    }
    
    func getWorkouts(for userId: String) -> [Workout] {
        workouts.filter { $0.userId == userId }
    }
    
    func getRecentWorkouts(limit: Int = 10) -> [Workout] {
        Array(workouts.prefix(limit))
    }
    
    // MARK: - PR Detection
    private func detectPRs(in workout: Workout) {
        for exercise in workout.exercises {
            for set in exercise.sets {
                let exerciseId = exercise.exercise.id
                
                if let existing = personalRecords[exerciseId] {
                    // Check if this set beats the existing PR (by estimated 1RM)
                    if set.estimated1RM > existing.weight {
                        personalRecords[exerciseId] = PersonalRecord(
                            id: UUID().uuidString,
                            userId: workout.userId,
                            exerciseId: exerciseId,
                            exerciseName: exercise.exercise.name,
                            weight: set.weight,
                            reps: set.reps,
                            date: set.completedAt,
                            previousBest: existing.weight
                        )
                    }
                } else {
                    // First time doing this exercise — it's a PR by default
                    personalRecords[exerciseId] = PersonalRecord(
                        id: UUID().uuidString,
                        userId: workout.userId,
                        exerciseId: exerciseId,
                        exerciseName: exercise.exercise.name,
                        weight: set.weight,
                        reps: set.reps,
                        date: set.completedAt,
                        previousBest: nil
                    )
                }
            }
        }
    }
    
    func getAllPRs() -> [PersonalRecord] {
        Array(personalRecords.values).sorted { $0.date > $1.date }
    }
    
    // MARK: - Analytics
    func totalVolume(since date: Date? = nil) -> Double {
        let filtered = date != nil ? workouts.filter { $0.startTime >= date! } : workouts
        return filtered.reduce(0) { $0 + $1.totalVolume }
    }
    
    func workoutCount(since date: Date? = nil) -> Int {
        let filtered = date != nil ? workouts.filter { $0.startTime >= date! } : workouts
        return filtered.count
    }
    
    func volumeByMuscleGroup(since date: Date? = nil) -> [(MuscleGroup, Double)] {
        let filtered = date != nil ? workouts.filter { $0.startTime >= date! } : workouts
        var volumes: [MuscleGroup: Double] = [:]
        
        for workout in filtered {
            for exercise in workout.exercises {
                let vol = exercise.sets.reduce(0.0) { $0 + $1.volume }
                for group in exercise.exercise.muscleGroups {
                    volumes[group, default: 0] += vol
                }
            }
        }
        
        return volumes.sorted { $0.value > $1.value }
    }
}
