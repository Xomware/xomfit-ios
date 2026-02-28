import Foundation

enum PRType: String, Codable {
    case oneRM = "1RM"
    case threeRM = "3RM"
    case fiveRM = "5RM"
    
    var requiredReps: Int {
        switch self {
        case .oneRM: return 1
        case .threeRM: return 3
        case .fiveRM: return 5
        }
    }
}

struct PRDetectionResult {
    let isNewPR: Bool
    let prType: PRType?
    let previousBest: Double?
    let newWeight: Double
    let improvement: Double?
    
    var improvementString: String? {
        guard let imp = improvement else { return nil }
        return String(format: "+%.1f lbs", imp)
    }
}

/// Utility for detecting new personal records from workout sets
class PRCalculator {
    // MARK: - Detection Logic
    
    /// Detects if a set is a new PR based on rep scheme
    static func detectNewPR(
        set: WorkoutSet,
        existingPRs: [PersonalRecord]
    ) -> PRDetectionResult {
        // Determine PR type based on reps
        let prType = determinePRType(reps: set.reps)
        guard let prType = prType else {
            return PRDetectionResult(
                isNewPR: false,
                prType: nil,
                previousBest: nil,
                newWeight: set.weight,
                improvement: nil
            )
        }
        
        // Find previous best for this exercise at this rep range
        let previousBest = findPreviousBest(
            exerciseId: set.exerciseId,
            reps: prType.requiredReps,
            existingPRs: existingPRs
        )
        
        let isNewPR = previousBest == nil || set.weight > previousBest!
        let improvement = previousBest.map { set.weight - $0 }
        
        return PRDetectionResult(
            isNewPR: isNewPR,
            prType: isNewPR ? prType : nil,
            previousBest: previousBest,
            newWeight: set.weight,
            improvement: improvement
        )
    }
    
    /// Detects all new PRs in a completed workout
    static func detectPRsInWorkout(
        workout: Workout,
        existingPRs: [PersonalRecord]
    ) -> [WorkoutSet: PRDetectionResult] {
        var results: [WorkoutSet: PRDetectionResult] = [:]
        
        for exercise in workout.exercises {
            for set in exercise.sets {
                let detection = detectNewPR(set: set, existingPRs: existingPRs)
                if detection.isNewPR {
                    results[set] = detection
                }
            }
        }
        
        return results
    }
    
    /// Creates PersonalRecord entries from detected PRs
    static func createPersonalRecords(
        from workout: Workout,
        detections: [WorkoutSet: PRDetectionResult]
    ) -> [PersonalRecord] {
        detections.compactMap { set, detection -> PersonalRecord? in
            guard let prType = detection.prType else { return nil }
            
            // Find the exercise name from the workout
            let exerciseName = workout.exercises
                .first { $0.sets.contains { $0.id == set.id } }?
                .exercise.name ?? "Unknown"
            
            return PersonalRecord(
                id: UUID().uuidString,
                userId: workout.userId,
                exerciseId: set.exerciseId,
                exerciseName: exerciseName,
                weight: set.weight,
                reps: prType.requiredReps,
                date: set.completedAt,
                previousBest: detection.previousBest
            )
        }
    }
    
    /// Calculates estimated 1RM based on a given weight and reps
    static func estimatedOneRM(weight: Double, reps: Int) -> Double {
        if reps == 1 { return weight }
        return weight * (1 + Double(reps) / 30.0)
    }
    
    // MARK: - Helper Methods
    
    private static func determinePRType(reps: Int) -> PRType? {
        switch reps {
        case 1: return .oneRM
        case 3: return .threeRM
        case 5: return .fiveRM
        default: return nil
        }
    }
    
    private static func findPreviousBest(
        exerciseId: String,
        reps: Int,
        existingPRs: [PersonalRecord]
    ) -> Double? {
        existingPRs
            .filter { $0.exerciseId == exerciseId && $0.reps == reps }
            .max { $0.weight < $1.weight }?
            .weight
    }
}
