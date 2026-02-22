import Foundation

struct WorkoutTemplate: Codable, Identifiable {
    let id: String
    var name: String
    var description: String
    var exercises: [TemplateExercise]
    var estimatedDuration: Int // minutes
    var category: TemplateCategory
    var isCustom: Bool
    
    struct TemplateExercise: Codable, Identifiable {
        let id: String
        var exercise: Exercise
        var targetSets: Int
        var targetReps: String // "5" or "8-12"
        var notes: String?
    }
    
    enum TemplateCategory: String, Codable, CaseIterable {
        case push, pull, legs, upperBody, lowerBody, fullBody, custom
        
        var displayName: String {
            switch self {
            case .push: return "Push"
            case .pull: return "Pull"
            case .legs: return "Legs"
            case .upperBody: return "Upper Body"
            case .lowerBody: return "Lower Body"
            case .fullBody: return "Full Body"
            case .custom: return "Custom"
            }
        }
        
        var icon: String {
            switch self {
            case .push: return "figure.strengthtraining.traditional"
            case .pull: return "figure.rowing"
            case .legs: return "figure.lunges"
            case .upperBody: return "figure.boxing"
            case .lowerBody: return "figure.run"
            case .fullBody: return "figure.mixed.cardio"
            case .custom: return "star.fill"
            }
        }
    }
}

// MARK: - Built-in Templates
extension WorkoutTemplate {
    static let builtIn: [WorkoutTemplate] = [
        // Push Day
        WorkoutTemplate(
            id: "tpl-push", name: "Push Day", description: "Chest, shoulders, and triceps",
            exercises: [
                .init(id: "te-1", exercise: ExerciseDatabase.chest[0], targetSets: 4, targetReps: "5", notes: "Work up to heavy set"),
                .init(id: "te-2", exercise: ExerciseDatabase.chest[2], targetSets: 3, targetReps: "8-12", notes: nil),
                .init(id: "te-3", exercise: ExerciseDatabase.shoulders[0], targetSets: 3, targetReps: "5-8", notes: nil),
                .init(id: "te-4", exercise: ExerciseDatabase.shoulders[2], targetSets: 3, targetReps: "12-15", notes: "Light weight, strict form"),
                .init(id: "te-5", exercise: ExerciseDatabase.arms[4], targetSets: 3, targetReps: "10-12", notes: nil),
            ],
            estimatedDuration: 60, category: .push, isCustom: false
        ),
        
        // Pull Day
        WorkoutTemplate(
            id: "tpl-pull", name: "Pull Day", description: "Back and biceps",
            exercises: [
                .init(id: "te-6", exercise: ExerciseDatabase.back[0], targetSets: 3, targetReps: "5", notes: "Conventional or sumo"),
                .init(id: "te-7", exercise: ExerciseDatabase.back[1], targetSets: 4, targetReps: "6-8", notes: nil),
                .init(id: "te-8", exercise: ExerciseDatabase.back[3], targetSets: 3, targetReps: "AMRAP", notes: "Add weight if >12 reps"),
                .init(id: "te-9", exercise: ExerciseDatabase.back[7], targetSets: 3, targetReps: "15-20", notes: "Light, focus on rear delts"),
                .init(id: "te-10", exercise: ExerciseDatabase.arms[0], targetSets: 3, targetReps: "8-12", notes: nil),
            ],
            estimatedDuration: 55, category: .pull, isCustom: false
        ),
        
        // Leg Day
        WorkoutTemplate(
            id: "tpl-legs", name: "Leg Day", description: "Quads, hamstrings, and glutes",
            exercises: [
                .init(id: "te-11", exercise: ExerciseDatabase.legs[0], targetSets: 4, targetReps: "5", notes: "Work up to heavy set"),
                .init(id: "te-12", exercise: ExerciseDatabase.legs[3], targetSets: 3, targetReps: "8-10", notes: nil),
                .init(id: "te-13", exercise: ExerciseDatabase.legs[2], targetSets: 3, targetReps: "10-12", notes: nil),
                .init(id: "te-14", exercise: ExerciseDatabase.legs[5], targetSets: 3, targetReps: "10-12", notes: nil),
                .init(id: "te-15", exercise: ExerciseDatabase.legs[7], targetSets: 4, targetReps: "12-15", notes: "Pause at top"),
            ],
            estimatedDuration: 60, category: .legs, isCustom: false
        ),
        
        // Full Body
        WorkoutTemplate(
            id: "tpl-full", name: "Full Body", description: "Hit everything in one session",
            exercises: [
                .init(id: "te-16", exercise: ExerciseDatabase.legs[0], targetSets: 3, targetReps: "5", notes: nil),
                .init(id: "te-17", exercise: ExerciseDatabase.chest[0], targetSets: 3, targetReps: "5", notes: nil),
                .init(id: "te-18", exercise: ExerciseDatabase.back[1], targetSets: 3, targetReps: "8", notes: nil),
                .init(id: "te-19", exercise: ExerciseDatabase.shoulders[0], targetSets: 3, targetReps: "8", notes: nil),
                .init(id: "te-20", exercise: ExerciseDatabase.arms[0], targetSets: 2, targetReps: "10-12", notes: nil),
                .init(id: "te-21", exercise: ExerciseDatabase.arms[4], targetSets: 2, targetReps: "10-12", notes: nil),
            ],
            estimatedDuration: 70, category: .fullBody, isCustom: false
        ),
    ]
}
