import Foundation
import Supabase

@MainActor
class WorkoutService: ObservableObject {
    static let shared = WorkoutService()
    
    @Published var workouts: [Workout] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let supabaseClient = supabase
    private let userDefaults = UserDefaults.standard
    private let workoutsKey = "saved_workouts"
    
    init() {
        loadWorkoutsFromLocalStorage()
    }
    
    // MARK: - Workout Management
    
    func saveWorkout(_ workout: Workout) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Save to local storage first
            saveWorkoutLocally(workout)
            
            // Try to sync with Supabase
            try await syncWorkoutToSupabase(workout)
            
            // Update local list
            if let index = workouts.firstIndex(where: { $0.id == workout.id }) {
                workouts[index] = workout
            } else {
                workouts.insert(workout, at: 0)
            }
        } catch {
            self.error = "Failed to save workout: \(error.localizedDescription)"
            throw error
        }
    }
    
    func loadWorkouts() async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Load from Supabase
            try await syncWorkoutsFromSupabase()
        } catch {
            // Fall back to local storage
            loadWorkoutsFromLocalStorage()
        }
    }
    
    func deleteWorkout(_ workoutId: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Delete from local storage
            deleteWorkoutLocally(workoutId)
            
            // Try to delete from Supabase
            try await deleteWorkoutFromSupabase(workoutId)
            
            workouts.removeAll { $0.id == workoutId }
        } catch {
            self.error = "Failed to delete workout: \(error.localizedDescription)"
            throw error
        }
    }
    
    // MARK: - Local Storage
    
    private func saveWorkoutLocally(_ workout: Workout) {
        do {
            var savedWorkouts = loadWorkoutsFromLocalStorage()
            if let index = savedWorkouts.firstIndex(where: { $0.id == workout.id }) {
                savedWorkouts[index] = workout
            } else {
                savedWorkouts.insert(workout, at: 0)
            }
            
            let encoded = try JSONEncoder().encode(savedWorkouts)
            userDefaults.set(encoded, forKey: workoutsKey)
        } catch {
            self.error = "Failed to save workout locally: \(error.localizedDescription)"
        }
    }
    
    private func deleteWorkoutLocally(_ workoutId: String) {
        do {
            var savedWorkouts = loadWorkoutsFromLocalStorage()
            savedWorkouts.removeAll { $0.id == workoutId }
            
            let encoded = try JSONEncoder().encode(savedWorkouts)
            userDefaults.set(encoded, forKey: workoutsKey)
        } catch {
            self.error = "Failed to delete workout locally: \(error.localizedDescription)"
        }
    }
    
    @discardableResult
    private func loadWorkoutsFromLocalStorage() -> [Workout] {
        do {
            if let data = userDefaults.data(forKey: workoutsKey) {
                let decoded = try JSONDecoder().decode([Workout].self, from: data)
                self.workouts = decoded.sorted { $0.startTime > $1.startTime }
                return self.workouts
            }
        } catch {
            self.error = "Failed to load workouts from local storage: \(error.localizedDescription)"
        }
        return []
    }
    
    // MARK: - Supabase Sync
    
    private func syncWorkoutToSupabase(_ workout: Workout) async throws {
        // Prepare workout data for Supabase
        let workoutData: [String: Any] = [
            "id": workout.id,
            "user_id": workout.userId,
            "name": workout.name,
            "start_time": ISO8601DateFormatter().string(from: workout.startTime),
            "end_time": workout.endTime.map { ISO8601DateFormatter().string(from: $0) } ?? NSNull(),
            "notes": workout.notes ?? NSNull(),
            "total_sets": workout.totalSets,
            "total_volume": workout.totalVolume
        ]
        
        // This would be implemented with actual Supabase integration
        // For now, we'll just handle local storage
    }
    
    private func syncWorkoutsFromSupabase() async throws {
        // This would fetch workouts from Supabase
        // For now, we'll just use local storage
    }
    
    private func deleteWorkoutFromSupabase(_ workoutId: String) async throws {
        // This would delete from Supabase
        // For now, we'll just handle local deletion
    }
    
    // MARK: - Statistics
    
    func getTotalVolume(for muscleGroup: MuscleGroup) -> Double {
        workouts.reduce(0.0) { total, workout in
            total + workout.exercises.reduce(0.0) { subtotal, exercise in
                guard exercise.exercise.muscleGroups.contains(muscleGroup) else { return subtotal }
                return subtotal + exercise.sets.reduce(0) { $0 + $1.volume }
            }
        }
    }
    
    func getRecentExercises(limit: Int = 10) -> [Exercise] {
        var exerciseDict: [String: Exercise] = [:]
        
        for workout in workouts {
            for exercise in workout.exercises {
                exerciseDict[exercise.exercise.id] = exercise.exercise
            }
        }
        
        return Array(exerciseDict.values).prefix(limit).map { $0 }
    }
    
    func getPersonalRecord(for exerciseId: String) -> WorkoutSet? {
        workouts.flatMap { workout in
            workout.exercises.flatMap { $0.sets }
        }
        .filter { $0.exerciseId == exerciseId }
        .max { $0.weight < $1.weight }
    }
}
