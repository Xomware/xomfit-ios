import Foundation

struct Workout: Codable, Identifiable {
    let id: String
    var userId: String
    var name: String
    var exercises: [WorkoutExercise]
    var startTime: Date
    var endTime: Date?
    var notes: String?
    var location: String?
    var rating: Int?
    
    var startDate: Date { startTime }

    var duration: TimeInterval {
        (endTime ?? Date()).timeIntervalSince(startTime)
    }
    
    var durationString: String {
        let minutes = Int(duration / 60)
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
    
    var totalVolume: Double {
        exercises.flatMap { $0.sets }.reduce(0) { $0 + $1.volume }
    }
    
    var totalSets: Int {
        exercises.reduce(0) { $0 + $1.sets.count }
    }
    
    var totalPRs: Int {
        exercises.flatMap { $0.sets }.filter { $0.isPersonalRecord }.count
    }
    
    var formattedVolume: String {
        if totalVolume >= 1000 {
            return String(format: "%.1fk", totalVolume / 1000)
        }
        return "\(Int(totalVolume))"
    }
    
    var muscleGroups: [MuscleGroup] {
        Array(Set(exercises.flatMap { $0.exercise.muscleGroups }))
    }
}

/// How the user is performing the exercise — both sides at once, one side at a time, or alternating sides.
enum Laterality: String, Codable, CaseIterable, Identifiable {
    case bilateral    // both arms/legs together (default)
    case unilateral   // one arm/leg at a time (record weight per side)
    case alternating  // alternating sides each rep

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bilateral:   return "Both"
        case .unilateral:  return "Single"
        case .alternating: return "Alternating"
        }
    }
}

struct WorkoutExercise: Codable, Identifiable {
    let id: String
    var exercise: Exercise
    var sets: [WorkoutSet]
    var notes: String?
    var selectedGrip: GripType? = nil
    var selectedAttachment: CableAttachment? = nil
    var selectedPosition: ExercisePosition? = nil
    /// Laterality selection for this exercise instance. Defaults to bilateral.
    var selectedLaterality: Laterality = .bilateral

    var bestSet: WorkoutSet? {
        sets.max(by: { $0.volume < $1.volume })
    }

    /// Total volume for this exercise. Doubles the multiplier when performing unilaterally or alternating.
    var totalVolume: Double {
        let lateralityMultiplier: Double = selectedLaterality == .bilateral ? 1.0 : 2.0
        return sets.reduce(0) { acc, set in
            acc + set.weight * Double(set.reps) * (set.weightMode == .perSide ? 2 : 1) * lateralityMultiplier
        }
    }
}

// MARK: - Mock Data
extension Workout {
    static let mock = Workout(
        id: "w-1",
        userId: "user-1",
        name: "Push Day",
        exercises: [
            WorkoutExercise(
                id: "we-1",
                exercise: .benchPress,
                sets: WorkoutSet.mockSets,
                notes: "Felt strong today"
            )
        ],
        startTime: Date().addingTimeInterval(-3600),
        endTime: Date().addingTimeInterval(-600),
        notes: "Great session"
    )
    
    static let mockFriendWorkout = Workout(
        id: "w-2",
        userId: "user-2",
        name: "Leg Day",
        exercises: [
            WorkoutExercise(
                id: "we-2",
                exercise: .squat,
                sets: [
                    WorkoutSet(id: "s-4", exerciseId: "ex-2", weight: 315, reps: 5, rpe: 9, isPersonalRecord: false, completedAt: Date()),
                    WorkoutSet(id: "s-5", exerciseId: "ex-2", weight: 335, reps: 3, rpe: 9.5, isPersonalRecord: true, completedAt: Date()),
                ],
                notes: nil
            )
        ],
        startTime: Date().addingTimeInterval(-7200),
        endTime: Date().addingTimeInterval(-3600),
        notes: nil
    )
}
