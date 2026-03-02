import Foundation

/// Service that fetches recent exercise sessions and generates overload suggestions.
@MainActor
class ProgressiveOverloadService: ObservableObject {
    static let shared = ProgressiveOverloadService()
    
    private let workoutService = WorkoutService.shared
    let engine = ProgressiveOverloadEngine()
    
    /// Fetch recent sessions for a given exercise name, grouped by workout date.
    func fetchRecentSessions(exercise: String, limit: Int = 5) async throws -> [ExerciseSession] {
        // Ensure workouts are loaded
        if workoutService.workouts.isEmpty {
            try await workoutService.loadWorkouts()
        }
        
        let workouts = workoutService.workouts
        
        // Find all workout exercises matching this exercise name, group by workout
        var sessions: [ExerciseSession] = []
        
        for workout in workouts {
            for workoutExercise in workout.exercises {
                guard workoutExercise.exercise.name.lowercased() == exercise.lowercased(),
                      !workoutExercise.sets.isEmpty else { continue }
                
                // Estimate target reps from the most common rep count in the session
                let repCounts = workoutExercise.sets.map { $0.reps }
                let targetReps = mostCommonElement(repCounts) ?? repCounts.first ?? 0
                
                let session = ExerciseSession(
                    date: workout.startTime,
                    exercise: workoutExercise.exercise.name,
                    sets: workoutExercise.sets,
                    targetReps: targetReps
                )
                sessions.append(session)
            }
        }
        
        // Sort most recent first, take limit
        return sessions
            .sorted { $0.date > $1.date }
            .prefix(limit)
            .map { $0 }
    }
    
    /// Generate an overload suggestion for an exercise.
    func suggestion(for exerciseName: String, category: ExerciseCategory) async throws -> OverloadSuggestion {
        let sessions = try await fetchRecentSessions(exercise: exerciseName)
        return engine.suggestion(for: exerciseName, history: sessions, exerciseType: category)
    }
    
    // MARK: - Helpers
    
    private func mostCommonElement(_ array: [Int]) -> Int? {
        guard !array.isEmpty else { return nil }
        var counts: [Int: Int] = [:]
        for element in array {
            counts[element, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }
}
