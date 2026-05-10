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
        /// Per-exercise rest override in seconds. nil = use the workout's global default.
        /// Optional + default keeps existing templates decodable as-is.
        var restSeconds: Int? = nil
    }

    enum TemplateCategory: String, Codable, CaseIterable {
        case push, pull, legs, upperBody, lowerBody, fullBody
        case chest, back, shoulders, arms
        case custom
        case saved

        var displayName: String {
            switch self {
            case .push: return "Push"
            case .pull: return "Pull"
            case .legs: return "Legs"
            case .upperBody: return "Upper Body"
            case .lowerBody: return "Lower Body"
            case .fullBody: return "Full Body"
            case .chest: return "Chest"
            case .back: return "Back"
            case .shoulders: return "Shoulders"
            case .arms: return "Arms"
            case .custom: return "Custom"
            case .saved: return "Saved"
            }
        }

        var icon: String {
            switch self {
            case .push: return "figure.strengthtraining.traditional"
            case .pull: return "figure.indoor.rowing"
            case .legs: return "figure.step.training"
            case .upperBody: return "figure.arms.open"
            case .lowerBody: return "figure.run"
            case .fullBody: return "figure.strengthtraining.traditional"
            case .chest: return "figure.strengthtraining.traditional"
            case .back: return "figure.indoor.rowing"
            case .shoulders: return "figure.arms.open"
            case .arms: return "dumbbell.fill"
            case .custom: return "star.fill"
            case .saved: return "bookmark.fill"
            }
        }
    }
}

// MARK: - Built-in Templates
extension WorkoutTemplate {
    // Force unwrap is intentional — these are compile-time constants referencing known IDs
    private static func ex(_ id: String) -> Exercise {
        ExerciseDatabase.all.first(where: { $0.id == id })!
    }

    static let builtIn: [WorkoutTemplate] = [
        // MARK: PPL Split

        WorkoutTemplate(
            id: "tpl-ppl-push", name: "Push Day", description: "Chest, shoulders, and triceps",
            exercises: [
                .init(id: "te-100", exercise: ex("ex-bench-flat"), targetSets: 4, targetReps: "5", notes: nil),
                .init(id: "te-101", exercise: ex("ex-incline-db"), targetSets: 3, targetReps: "8-12", notes: nil),
                .init(id: "te-102", exercise: ex("ex-landmine-press"), targetSets: 3, targetReps: "10-12", notes: "Close grip"),
                .init(id: "te-103", exercise: ex("ex-cable-high-fly"), targetSets: 3, targetReps: "12-15", notes: nil),
                .init(id: "te-104", exercise: ex("ex-cable-low-fly"), targetSets: 3, targetReps: "12-15", notes: nil),
            ],
            estimatedDuration: 60, category: .push, isCustom: false
        ),

        WorkoutTemplate(
            id: "tpl-ppl-pull", name: "Pull Day", description: "Back and biceps",
            exercises: [
                .init(id: "te-105", exercise: ex("ex-chest-supported-row"), targetSets: 4, targetReps: "8-10", notes: "Close grip"),
                .init(id: "te-106", exercise: ex("ex-lat-pulldown"), targetSets: 3, targetReps: "8-12", notes: nil),
                .init(id: "te-107", exercise: ex("ex-cable-reverse-fly"), targetSets: 3, targetReps: "15-20", notes: nil),
                .init(id: "te-108", exercise: ex("ex-cable-row"), targetSets: 3, targetReps: "10-12", notes: "Close grip"),
                .init(id: "te-109", exercise: ex("ex-pullover-machine"), targetSets: 3, targetReps: "10-12", notes: nil),
            ],
            estimatedDuration: 55, category: .pull, isCustom: false
        ),

        WorkoutTemplate(
            id: "tpl-ppl-legs", name: "Leg Day", description: "Quads, hamstrings, and glutes",
            exercises: [
                .init(id: "te-110", exercise: ex("ex-squat"), targetSets: 4, targetReps: "5", notes: nil),
                .init(id: "te-111", exercise: ex("ex-rdl"), targetSets: 3, targetReps: "8-10", notes: nil),
                .init(id: "te-112", exercise: ex("ex-leg-press"), targetSets: 3, targetReps: "10-12", notes: nil),
                .init(id: "te-113", exercise: ex("ex-leg-curl"), targetSets: 3, targetReps: "10-12", notes: nil),
                .init(id: "te-114", exercise: ex("ex-leg-ext"), targetSets: 3, targetReps: "10-12", notes: nil),
                .init(id: "te-115", exercise: ex("ex-calf-raise"), targetSets: 4, targetReps: "12-15", notes: nil),
            ],
            estimatedDuration: 65, category: .legs, isCustom: false
        ),

        // MARK: Bro Split

        WorkoutTemplate(
            id: "tpl-bro-chest", name: "Chest Day", description: "Full chest workout",
            exercises: [
                .init(id: "te-116", exercise: ex("ex-bench-flat"), targetSets: 4, targetReps: "5-8", notes: nil),
                .init(id: "te-117", exercise: ex("ex-incline-machine-press"), targetSets: 3, targetReps: "8-12", notes: nil),
                .init(id: "te-118", exercise: ex("ex-cable-high-fly"), targetSets: 3, targetReps: "12-15", notes: nil),
                .init(id: "te-119", exercise: ex("ex-cable-low-fly"), targetSets: 3, targetReps: "12-15", notes: nil),
                .init(id: "te-120", exercise: ex("ex-dips"), targetSets: 3, targetReps: "AMRAP", notes: nil),
            ],
            estimatedDuration: 55, category: .chest, isCustom: false
        ),

        WorkoutTemplate(
            id: "tpl-bro-back", name: "Back Day", description: "Full back workout",
            exercises: [
                .init(id: "te-121", exercise: ex("ex-chest-supported-row"), targetSets: 4, targetReps: "8-10", notes: nil),
                .init(id: "te-122", exercise: ex("ex-lat-pulldown"), targetSets: 3, targetReps: "8-12", notes: nil),
                .init(id: "te-123", exercise: ex("ex-cable-reverse-fly"), targetSets: 3, targetReps: "15-20", notes: nil),
                .init(id: "te-124", exercise: ex("ex-cable-row"), targetSets: 3, targetReps: "10-12", notes: nil),
                .init(id: "te-125", exercise: ex("ex-pullover-machine"), targetSets: 3, targetReps: "10-12", notes: nil),
            ],
            estimatedDuration: 55, category: .back, isCustom: false
        ),

        WorkoutTemplate(
            id: "tpl-bro-shoulders", name: "Shoulder Day", description: "Full shoulder workout",
            exercises: [
                .init(id: "te-126", exercise: ex("ex-machine-shoulder-press"), targetSets: 4, targetReps: "8-10", notes: nil),
                .init(id: "te-127", exercise: ex("ex-cable-lateral-raise"), targetSets: 4, targetReps: "12-15", notes: nil),
                .init(id: "te-128", exercise: ex("ex-cable-front-raise"), targetSets: 3, targetReps: "12-15", notes: nil),
                .init(id: "te-129", exercise: ex("ex-cable-rear-delt-fly"), targetSets: 3, targetReps: "15-20", notes: nil),
                .init(id: "te-130", exercise: ex("ex-db-shrugs"), targetSets: 3, targetReps: "10-12", notes: nil),
            ],
            estimatedDuration: 50, category: .shoulders, isCustom: false
        ),

        WorkoutTemplate(
            id: "tpl-bro-arms", name: "Arm Day", description: "Biceps and triceps",
            exercises: [
                .init(id: "te-131", exercise: ex("ex-barbell-curl"), targetSets: 3, targetReps: "8-10", notes: nil),
                .init(id: "te-132", exercise: ex("ex-tricep-pushdown"), targetSets: 3, targetReps: "10-12", notes: nil),
                .init(id: "te-133", exercise: ex("ex-hammer-curl"), targetSets: 3, targetReps: "10-12", notes: nil),
                .init(id: "te-134", exercise: ex("ex-skull-crusher"), targetSets: 3, targetReps: "10-12", notes: nil),
                .init(id: "te-135", exercise: ex("ex-preacher-curl"), targetSets: 3, targetReps: "10-12", notes: nil),
                .init(id: "te-136", exercise: ex("ex-cable-overhead-tri-ext"), targetSets: 3, targetReps: "12-15", notes: nil),
            ],
            estimatedDuration: 45, category: .arms, isCustom: false
        ),

        // MARK: Upper/Lower Split

        WorkoutTemplate(
            id: "tpl-ul-upper-a", name: "Upper A", description: "Strength-focused upper body",
            exercises: [
                .init(id: "te-137", exercise: ex("ex-bench-flat"), targetSets: 4, targetReps: "5", notes: nil),
                .init(id: "te-138", exercise: ex("ex-row-barbell"), targetSets: 4, targetReps: "6-8", notes: nil),
                .init(id: "te-139", exercise: ex("ex-ohp"), targetSets: 3, targetReps: "8-10", notes: nil),
                .init(id: "te-140", exercise: ex("ex-lat-pulldown"), targetSets: 3, targetReps: "8-12", notes: nil),
                .init(id: "te-141", exercise: ex("ex-barbell-curl"), targetSets: 2, targetReps: "10-12", notes: nil),
                .init(id: "te-142", exercise: ex("ex-tricep-pushdown"), targetSets: 2, targetReps: "10-12", notes: nil),
            ],
            estimatedDuration: 60, category: .upperBody, isCustom: false
        ),

        WorkoutTemplate(
            id: "tpl-ul-upper-b", name: "Upper B", description: "Hypertrophy-focused upper body",
            exercises: [
                .init(id: "te-143", exercise: ex("ex-incline-db"), targetSets: 4, targetReps: "8-10", notes: nil),
                .init(id: "te-144", exercise: ex("ex-cable-row"), targetSets: 4, targetReps: "8-10", notes: nil),
                .init(id: "te-145", exercise: ex("ex-db-shoulder-press"), targetSets: 3, targetReps: "8-12", notes: nil),
                .init(id: "te-146", exercise: ex("ex-face-pull"), targetSets: 3, targetReps: "15-20", notes: nil),
                .init(id: "te-147", exercise: ex("ex-hammer-curl"), targetSets: 2, targetReps: "10-12", notes: nil),
                .init(id: "te-148", exercise: ex("ex-dips"), targetSets: 2, targetReps: "AMRAP", notes: nil),
            ],
            estimatedDuration: 60, category: .upperBody, isCustom: false
        ),

        WorkoutTemplate(
            id: "tpl-ul-lower-a", name: "Lower A", description: "Strength-focused lower body",
            exercises: [
                .init(id: "te-149", exercise: ex("ex-squat"), targetSets: 4, targetReps: "5", notes: nil),
                .init(id: "te-150", exercise: ex("ex-rdl"), targetSets: 3, targetReps: "8-10", notes: nil),
                .init(id: "te-151", exercise: ex("ex-leg-press"), targetSets: 3, targetReps: "10-12", notes: nil),
                .init(id: "te-152", exercise: ex("ex-leg-curl"), targetSets: 3, targetReps: "10-12", notes: nil),
                .init(id: "te-153", exercise: ex("ex-calf-raise"), targetSets: 4, targetReps: "12-15", notes: nil),
            ],
            estimatedDuration: 55, category: .lowerBody, isCustom: false
        ),

        WorkoutTemplate(
            id: "tpl-ul-lower-b", name: "Lower B", description: "Hypertrophy-focused lower body",
            exercises: [
                .init(id: "te-154", exercise: ex("ex-front-squat"), targetSets: 4, targetReps: "5-8", notes: nil),
                .init(id: "te-155", exercise: ex("ex-hip-thrust"), targetSets: 3, targetReps: "8-10", notes: nil),
                .init(id: "te-156", exercise: ex("ex-bulgarian-split-squat"), targetSets: 3, targetReps: "8-10", notes: nil),
                .init(id: "te-157", exercise: ex("ex-leg-ext"), targetSets: 3, targetReps: "10-12", notes: nil),
                .init(id: "te-158", exercise: ex("ex-seated-calf-raise"), targetSets: 4, targetReps: "12-15", notes: nil),
            ],
            estimatedDuration: 55, category: .lowerBody, isCustom: false
        ),

        // MARK: Full Body

        WorkoutTemplate(
            id: "tpl-fb-a", name: "Full Body A", description: "Compound-heavy full body session",
            exercises: [
                .init(id: "te-159", exercise: ex("ex-squat"), targetSets: 3, targetReps: "5", notes: nil),
                .init(id: "te-160", exercise: ex("ex-bench-flat"), targetSets: 3, targetReps: "5", notes: nil),
                .init(id: "te-161", exercise: ex("ex-row-barbell"), targetSets: 3, targetReps: "8", notes: nil),
                .init(id: "te-162", exercise: ex("ex-ohp"), targetSets: 3, targetReps: "8", notes: nil),
                .init(id: "te-163", exercise: ex("ex-barbell-curl"), targetSets: 2, targetReps: "10-12", notes: nil),
                .init(id: "te-164", exercise: ex("ex-tricep-pushdown"), targetSets: 2, targetReps: "10-12", notes: nil),
            ],
            estimatedDuration: 70, category: .fullBody, isCustom: false
        ),

        WorkoutTemplate(
            id: "tpl-fb-b", name: "Full Body B", description: "Compound-heavy full body session",
            exercises: [
                .init(id: "te-165", exercise: ex("ex-deadlift"), targetSets: 3, targetReps: "5", notes: nil),
                .init(id: "te-166", exercise: ex("ex-incline-db"), targetSets: 3, targetReps: "8-10", notes: nil),
                .init(id: "te-167", exercise: ex("ex-lat-pulldown"), targetSets: 3, targetReps: "8-10", notes: nil),
                .init(id: "te-168", exercise: ex("ex-db-shoulder-press"), targetSets: 3, targetReps: "10-12", notes: nil),
                .init(id: "te-169", exercise: ex("ex-hammer-curl"), targetSets: 2, targetReps: "10-12", notes: nil),
                .init(id: "te-170", exercise: ex("ex-skull-crusher"), targetSets: 2, targetReps: "10-12", notes: nil),
            ],
            estimatedDuration: 70, category: .fullBody, isCustom: false
        ),
    ]
}
