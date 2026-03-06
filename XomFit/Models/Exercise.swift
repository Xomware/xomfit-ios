import Foundation

struct Exercise: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var muscleGroups: [MuscleGroup]
    var equipment: Equipment
    var category: ExerciseCategory
    var description: String
    var tips: [String]
}

enum MuscleGroup: String, Codable, CaseIterable {
    case chest, back, shoulders, biceps, triceps
    case quads, hamstrings, glutes, calves
    case abs, forearms, traps, lats
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var icon: String {
        switch self {
        case .chest: return "figure.strengthtraining.traditional"
        case .back, .lats: return "figure.rowing"
        case .shoulders, .traps: return "figure.boxing"
        case .biceps, .triceps, .forearms: return "figure.curling"
        case .quads, .hamstrings, .glutes, .calves: return "figure.lunges"
        case .abs: return "figure.core.training"
        }
    }
}

enum Equipment: String, Codable, CaseIterable {
    case barbell, dumbbell, machine, cable
    case bodyweight, kettlebell, bands, other
    
    var displayName: String {
        rawValue.capitalized
    }
}

enum ExerciseCategory: String, Codable {
    case compound, isolation, cardio, stretching
    
    var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - Mock Data
extension Exercise {
    static let mockExercises: [Exercise] = [
        Exercise(
            id: "ex-1", name: "Bench Press",
            muscleGroups: [.chest, .triceps, .shoulders],
            equipment: .barbell, category: .compound,
            description: "Lie on a flat bench, grip the bar slightly wider than shoulder width, lower to chest, press up.",
            tips: ["Keep your feet flat on the floor", "Arch your back slightly", "Touch the bar to your mid-chest"]
        ),
        Exercise(
            id: "ex-2", name: "Squat",
            muscleGroups: [.quads, .glutes, .hamstrings],
            equipment: .barbell, category: .compound,
            description: "Bar on upper back, feet shoulder width, sit back and down until thighs are parallel, drive up.",
            tips: ["Keep your chest up", "Push knees out over toes", "Drive through your heels"]
        ),
        Exercise(
            id: "ex-3", name: "Deadlift",
            muscleGroups: [.back, .hamstrings, .glutes, .traps],
            equipment: .barbell, category: .compound,
            description: "Stand with feet hip width, grip bar outside knees, lift by extending hips and knees together.",
            tips: ["Keep the bar close to your body", "Neutral spine throughout", "Lock out at the top"]
        ),
        Exercise(
            id: "ex-4", name: "Overhead Press",
            muscleGroups: [.shoulders, .triceps],
            equipment: .barbell, category: .compound,
            description: "Press the bar overhead from shoulder height to full lockout.",
            tips: ["Brace your core", "Press slightly back at the top", "Full lockout overhead"]
        ),
        Exercise(
            id: "ex-5", name: "Barbell Row",
            muscleGroups: [.back, .lats, .biceps],
            equipment: .barbell, category: .compound,
            description: "Hinge at the hips, pull the bar to your lower chest/upper abs.",
            tips: ["Keep your back flat", "Pull with your elbows", "Squeeze your shoulder blades"]
        ),
    ]
    
    static let benchPress = mockExercises[0]
    static let squat = mockExercises[1]
    static let deadlift = mockExercises[2]
}

// MARK: - 1RM Estimation
extension Exercise {
    /// Epley formula for estimated 1RM
    static func estimateMax(weight: Double, reps: Int, rpe: Double? = nil) -> Double {
        guard reps > 0 else { return weight }
        if reps == 1 { return weight }
        return weight * (1.0 + Double(reps) / 30.0)
    }
}
