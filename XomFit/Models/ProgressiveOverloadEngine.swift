import Foundation

// MARK: - Data Models

/// Represents a single training session for an exercise, aggregated from individual sets.
struct ExerciseSession {
    let date: Date
    let exercise: String
    let sets: [WorkoutSet]
    let targetReps: Int // the intended rep target for the session
    
    var avgRPE: Double {
        let rpeValues = sets.compactMap { $0.rpe }
        guard !rpeValues.isEmpty else { return 0 }
        return rpeValues.reduce(0, +) / Double(rpeValues.count)
    }
    
    var totalVolume: Double {
        sets.reduce(0) { $0 + $1.weight * Double($1.reps) }
    }
    
    var maxWeight: Double {
        sets.map { $0.weight }.max() ?? 0
    }
    
    var maxReps: Int {
        sets.map { $0.reps }.max() ?? 0
    }
    
    /// True if every set hit the target rep count or above.
    var completedAllTargetReps: Bool {
        sets.allSatisfy { $0.reps >= targetReps }
    }
}

/// A suggestion for how to progress on an exercise.
struct OverloadSuggestion {
    enum SuggestionType: Equatable {
        case increaseWeight(by: Double, to: Double)
        case increaseReps(by: Int)
        case deload(to: Double, reason: String)
        case maintain(reason: String)
        case volumeStagnant(suggestion: String)
    }
    
    let type: SuggestionType
    let exercise: String
    let lastWeight: Double
    let lastReps: Int
    let explanation: String
}

// MARK: - Engine

/// Pure-logic engine that decides progressive overload suggestions.
/// No SwiftUI, no networking — fully testable.
struct ProgressiveOverloadEngine {
    
    /// Main entry point. Provide the last N sessions (most recent first) and exercise category.
    func suggestion(
        for exercise: String,
        history: [ExerciseSession],
        exerciseType: ExerciseCategory
    ) -> OverloadSuggestion {
        guard !history.isEmpty else {
            return OverloadSuggestion(
                type: .maintain(reason: "No history yet — start training!"),
                exercise: exercise,
                lastWeight: 0,
                lastReps: 0,
                explanation: "No previous sessions found for \(exercise)."
            )
        }
        
        // Sort most-recent-first
        let sorted = history.sorted { $0.date > $1.date }
        let last = sorted[0]
        let lastWeight = last.maxWeight
        let lastReps = last.maxReps
        
        // Rule 1: Only 1 session → maintain
        if sorted.count < 2 {
            return OverloadSuggestion(
                type: .maintain(reason: "Need more data — keep training!"),
                exercise: exercise,
                lastWeight: lastWeight,
                lastReps: lastReps,
                explanation: "Only 1 session recorded for \(exercise). Keep at it!"
            )
        }
        
        // Rule 2: Deload — avg RPE ≥ 9 for 2+ consecutive sessions
        if detectDeload(sorted) {
            let deloadWeight = (lastWeight * 0.95).rounded(to: exerciseType == .compound ? 2.5 : 1.25)
            return OverloadSuggestion(
                type: .deload(to: deloadWeight, reason: "High fatigue detected"),
                exercise: exercise,
                lastWeight: lastWeight,
                lastReps: lastReps,
                explanation: "RPE ≥ 9 for last 2 sessions — deload to \(deloadWeight.formattedWeight) lbs."
            )
        }
        
        // Rule 3: Volume stagnation — 3+ consecutive weeks without increase
        if detectVolumeStagnation(sorted) {
            return OverloadSuggestion(
                type: .volumeStagnant(suggestion: "Try adding a set or changing rep range"),
                exercise: exercise,
                lastWeight: lastWeight,
                lastReps: lastReps,
                explanation: "Volume hasn't increased in 3+ weeks for \(exercise). Consider changing stimulus."
            )
        }
        
        // Rule 4: Weight increase — completed all target reps AND avg RPE ≤ 8
        if last.completedAllTargetReps && last.avgRPE <= 8 {
            let increment = suggestWeightIncrease(last, category: exerciseType)
            let newWeight = lastWeight + increment
            return OverloadSuggestion(
                type: .increaseWeight(by: increment, to: newWeight),
                exercise: exercise,
                lastWeight: lastWeight,
                lastReps: lastReps,
                explanation: "Last session: \(lastWeight.formattedWeight) lbs × \(lastReps) @ RPE \(String(format: "%.0f", last.avgRPE)) — ready for \(newWeight.formattedWeight) lbs"
            )
        }
        
        // Rule 5: Rep increase — didn't complete all target reps but RPE ≤ 8
        if !last.completedAllTargetReps && last.avgRPE <= 8 {
            return OverloadSuggestion(
                type: .increaseReps(by: 1),
                exercise: exercise,
                lastWeight: lastWeight,
                lastReps: lastReps,
                explanation: "Didn't hit all target reps last time at \(lastWeight.formattedWeight) lbs — try +1 rep per set."
            )
        }
        
        // Default: maintain
        return OverloadSuggestion(
            type: .maintain(reason: "Keep pushing at current weight"),
            exercise: exercise,
            lastWeight: lastWeight,
            lastReps: lastReps,
            explanation: "Stay at \(lastWeight.formattedWeight) lbs × \(lastReps) and aim for lower RPE."
        )
    }
    
    // MARK: - Internal Rules
    
    /// Returns true if avg RPE ≥ 9 for the 2 most recent consecutive sessions.
    func detectDeload(_ history: [ExerciseSession]) -> Bool {
        guard history.count >= 2 else { return false }
        return history[0].avgRPE >= 9 && history[1].avgRPE >= 9
    }
    
    /// Suggest weight increment based on exercise category.
    func suggestWeightIncrease(_ lastSession: ExerciseSession, category: ExerciseCategory) -> Double {
        switch category {
        case .compound:
            return 2.5
        case .isolation:
            return 1.25
        case .cardio, .stretching:
            return 0
        }
    }
    
    /// Returns true if total volume hasn't increased across 3+ consecutive sessions (proxy for weeks).
    func detectVolumeStagnation(_ history: [ExerciseSession]) -> Bool {
        guard history.count >= 3 else { return false }
        // Check if last 3 sessions show no volume increase (each ≤ the next older one)
        let recent = Array(history.prefix(3))
        // recent[0] is most recent, recent[2] is oldest
        return recent[0].totalVolume <= recent[1].totalVolume &&
               recent[1].totalVolume <= recent[2].totalVolume
    }
}

// MARK: - Helpers

private extension Double {
    /// Round to the nearest increment (e.g., 2.5 or 1.25).
    func rounded(to increment: Double) -> Double {
        guard increment > 0 else { return self }
        return (self / increment).rounded() * increment
    }
}
