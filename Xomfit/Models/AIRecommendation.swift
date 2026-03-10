import Foundation

// MARK: - AI Recommendation Models

struct AIRecommendation: Codable, Identifiable {
    let id: String
    let userId: String
    let type: RecommendationType
    let exercise: ExerciseRecommendation?
    let program: ProgramRecommendation?
    let analysis: PerformanceAnalysis?
    let timestamp: Date
    let confidence: Double // 0-1
    let reasoning: String
    
    init(
        id: String = UUID().uuidString,
        userId: String,
        type: RecommendationType,
        exercise: ExerciseRecommendation? = nil,
        program: ProgramRecommendation? = nil,
        analysis: PerformanceAnalysis? = nil,
        confidence: Double,
        reasoning: String
    ) {
        self.id = id
        self.userId = userId
        self.type = type
        self.exercise = exercise
        self.program = program
        self.analysis = analysis
        self.timestamp = Date()
        self.confidence = confidence
        self.reasoning = reasoning
    }
}

enum RecommendationType: String, Codable {
    case exercise         // Recommend a specific exercise
    case repRange         // Adjust reps for current exercise
    case restPeriod       // Suggest rest day or deload
    case weakPoint        // Address muscle group weakness
    case plateau          // Break through a plateau
    case volumeProgression // Increase/decrease volume
    case exerciseSwap     // Replace exercise with similar
    case newProgram       // Full program recommendation
    case formCorrection   // Fix form/technique
}

struct ExerciseRecommendation: Codable {
    let exercise: Exercise
    let reps: IntRange
    let sets: Int
    let restSeconds: Int
    let reasoning: String
    let replacesExercise: String? // Exercise ID this replaces
    
    struct IntRange: Codable {
        let min: Int
        let max: Int
    }
}

struct ProgramRecommendation: Codable {
    let name: String
    let weekDuration: Int
    let splitType: SplitType
    let focusAreas: [MuscleGroup]
    let estimatedDaysPerWeek: Int
    let reasoning: String
    let estimatedDurationWeeks: Int
    
    enum SplitType: String, Codable {
        case upperLower = "upper_lower"
        case pushPullLegs = "push_pull_legs"
        case fullBody = "full_body"
        case bodypartSplit = "bodypart"
        case custom = "custom"
        
        var displayName: String {
            switch self {
            case .upperLower: return "Upper/Lower"
            case .pushPullLegs: return "Push/Pull/Legs"
            case .fullBody: return "Full Body"
            case .bodypartSplit: return "Bodypart Split"
            case .custom: return "Custom"
            }
        }
    }
}

struct PerformanceAnalysis: Codable {
    let muscleGroupsAnalysis: [MuscleGroupAnalysis]
    let volumeProgression: VolumeProgress
    let strengthProgression: StrengthProgress
    let imbalances: [Imbalance]
    let estimatedMaxes: [ExerciseMax]
    
    struct MuscleGroupAnalysis: Codable {
        let muscleGroup: MuscleGroup
        let lastWorked: Date?
        let frequency: ExerciseFrequency
        let relativeVolume: Double // 0-1, where 1 is balanced
        let status: TrainingStatus
    }
    
    struct VolumeProgress: Codable {
        let totalLastMonth: Double
        let totalLastThreeMonths: Double
        let trend: Trend // up, down, stable
        let recommendation: String
    }
    
    struct StrengthProgress: Codable {
        let prsSinceDate: Int
        let averageRPELastMonth: Double
        let rpe9PlusCount: Int
        let trend: Trend
    }
    
    struct Imbalance: Codable {
        let muscleGroup1: MuscleGroup
        let muscleGroup2: MuscleGroup
        let volumeRatio: Double // e.g., 1.5 means 50% more volume on first
        let severity: SeverityLevel
        let recommendation: String
    }
    
    struct ExerciseMax: Codable {
        let exerciseId: String
        let exerciseName: String
        let estimatedMax: Double
        let basedOnSets: Int
        let confidence: Double
    }
    
    enum Trend: String, Codable {
        case up, down, stable
    }
    
    enum SeverityLevel: String, Codable {
        case minor, moderate, severe
    }
}

enum ExerciseFrequency: String, Codable {
    case rare        // < 1x per month
    case occasional  // 1-2x per month
    case regular     // 1-2x per week
    case frequent    // 3+ per week
    
    var displayName: String {
        switch self {
        case .rare: return "Rarely"
        case .occasional: return "Occasionally"
        case .regular: return "Regularly"
        case .frequent: return "Frequently"
        }
    }
}

enum TrainingStatus: String, Codable {
    case weak        // Underdeveloped
    case balanced    // Appropriate training
    case overworked  // Too much volume
    case plateaued   // No recent progress
    
    var displayName: String {
        switch self {
        case .weak: return "Needs Work"
        case .balanced: return "Balanced"
        case .overworked: return "Overworked"
        case .plateaued: return "Plateaued"
        }
    }
    
    var icon: String {
        switch self {
        case .weak: return "↘️"
        case .balanced: return "✅"
        case .overworked: return "⚠️"
        case .plateaued: return "➡️"
        }
    }
}

// MARK: - Learning Engine State
struct RecommendationLearning: Codable {
    var acceptedRecommendations: [String] = [] // Recommendation IDs user accepted
    var rejectedRecommendations: [String] = [] // IDs user skipped
    var userPreferences: UserTrainingPreferences = UserTrainingPreferences()
    var recommendationEffectiveness: [String: Double] = [:] // Exercise ID -> effectiveness score
    
    mutating func recordFeedback(recommendationId: String, accepted: Bool) {
        if accepted {
            acceptedRecommendations.append(recommendationId)
        } else {
            rejectedRecommendations.append(recommendationId)
        }
    }
}

struct UserTrainingPreferences: Codable {
    var preferredSplit: ProgramRecommendation.SplitType = .upperLower
    var targetDaysPerWeek: Int = 4
    var avoidExercises: [String] = [] // Exercise IDs to avoid
    var preferredEquipment: [Equipment] = [.barbell, .dumbbell]
    var repRangeMin: Int = 5
    var repRangeMax: Int = 12
    var restPeriodSeconds: Int = 90
    var enableAutoDeload: Bool = true
    var deloadFrequencyWeeks: Int = 8
}

// MARK: - Mock Data
extension AIRecommendation {
    static let mockExerciseRecommendation = AIRecommendation(
        userId: "user-1",
        type: .exercise,
        exercise: ExerciseRecommendation(
            exercise: .benchPress,
            reps: ExerciseRecommendation.IntRange(min: 8, max: 12),
            sets: 4,
            restSeconds: 120,
            reasoning: "Your bench press form looks solid. Increase reps to build hypertrophy.",
            replacesExercise: nil
        ),
        confidence: 0.92,
        reasoning: "Analysis shows strong chest development. Recommend hypertrophy work to maximize muscle growth."
    )
    
    static let mockWeakPointRecommendation = AIRecommendation(
        userId: "user-1",
        type: .weakPoint,
        exercise: ExerciseRecommendation(
            exercise: Exercise(
                id: "ex-leg-press",
                name: "Leg Press",
                muscleGroups: [.quads, .glutes],
                equipment: .machine,
                category: .compound,
                description: "Machine leg press for quad strength.",
                tips: ["Full range of motion", "Control the descent", "Drive through heels"]
            ),
            reps: ExerciseRecommendation.IntRange(min: 8, max: 12),
            sets: 3,
            restSeconds: 120,
            reasoning: "Your quad volume is significantly lower than hamstrings. Add leg press to balance.",
            replacesExercise: nil
        ),
        confidence: 0.85,
        reasoning: "Detected imbalance: Hamstring training is 40% more frequent than quads. Recommend adding quad-dominant exercise."
    )
    
    static let mockProgramRecommendation = AIRecommendation(
        userId: "user-1",
        type: .newProgram,
        program: ProgramRecommendation(
            name: "Balanced Upper/Lower Progression",
            weekDuration: 4,
            splitType: .upperLower,
            focusAreas: [.chest, .back, .shoulders, .quads, .hamstrings],
            estimatedDaysPerWeek: 4,
            reasoning: "Based on your history and goals, a 4-day upper/lower split will optimize hypertrophy while managing recovery.",
            estimatedDurationWeeks: 12
        ),
        confidence: 0.88,
        reasoning: "Current volume and frequency suggest you can handle a structured 4-day split with good recovery."
    )
}
