import Foundation

// MARK: - AI Coach Models

enum FatigueLevel: String, Codable, CaseIterable {
    case fresh = "Fresh"
    case moderate = "Moderate"
    case fatigued = "Fatigued"
    case overreached = "Overreached"
    
    var color: String {
        switch self {
        case .fresh: return "green"
        case .moderate: return "yellow"
        case .fatigued: return "orange"
        case .overreached: return "red"
        }
    }
}

enum PeriodizationPhase: String, Codable, CaseIterable {
    case accumulation = "Accumulation"
    case intensification = "Intensification"
    case realization = "Realization"
    case deload = "Deload"
}

enum CoachInsightType: String, Codable {
    case volumeRecommendation = "Volume Recommendation"
    case deloadSuggestion = "Deload Suggestion"
    case exerciseSwap = "Exercise Swap"
    case progressiveOverload = "Progressive Overload"
    case recoveryAlert = "Recovery Alert"
    case prOpportunity = "PR Opportunity"
}

struct CoachInsight: Identifiable, Codable {
    var id: UUID
    var type: CoachInsightType
    var title: String
    var message: String
    var confidence: Double // 0.0 - 1.0
    var actionLabel: String?
    var priority: Int // 1 = high, 2 = medium, 3 = low
    var createdAt: Date
    
    init(id: UUID = UUID(), type: CoachInsightType, title: String, message: String,
         confidence: Double, actionLabel: String? = nil, priority: Int = 2) {
        self.id = id
        self.type = type
        self.title = title
        self.message = message
        self.confidence = confidence
        self.actionLabel = actionLabel
        self.priority = priority
        self.createdAt = Date()
    }
}

struct TrainingLoad: Codable {
    var acute: Double  // 7-day rolling average
    var chronic: Double // 28-day rolling average
    var ratio: Double { acute / max(chronic, 1) } // ACWR
    
    var riskLevel: String {
        switch ratio {
        case ..<0.8: return "Undertraining"
        case 0.8..<1.3: return "Optimal"
        case 1.3..<1.5: return "Caution"
        default: return "High Risk"
        }
    }
}

struct PeriodizationBlock: Identifiable, Codable {
    var id: UUID
    var phase: PeriodizationPhase
    var weekNumber: Int
    var targetVolume: Int // sets per week
    var targetIntensity: Double // % of 1RM
    var notes: String
    
    init(id: UUID = UUID(), phase: PeriodizationPhase, weekNumber: Int,
         targetVolume: Int, targetIntensity: Double, notes: String = "") {
        self.id = id
        self.phase = phase
        self.weekNumber = weekNumber
        self.targetVolume = targetVolume
        self.targetIntensity = targetIntensity
        self.notes = notes
    }
}

struct ReadinessScore: Codable {
    var score: Int // 0 - 100
    var fatigueLevel: FatigueLevel
    var components: ReadinessComponents
    var recommendation: String
    
    struct ReadinessComponents: Codable {
        var recentVolume: Int // 0-100
        var consistency: Int // 0-100
        var recoveryDays: Int // 0-100
        var prMomentum: Int // 0-100
    }
}

struct MuscleGroupVolume: Identifiable, Codable {
    var id: UUID
    var muscleGroup: String
    var weeklySetTarget: Int
    var currentWeeklySets: Int
    var percentOfTarget: Double { Double(currentWeeklySets) / Double(max(weeklySetTarget, 1)) }
    
    init(id: UUID = UUID(), muscleGroup: String, weeklySetTarget: Int, currentWeeklySets: Int) {
        self.id = id
        self.muscleGroup = muscleGroup
        self.weeklySetTarget = weeklySetTarget
        self.currentWeeklySets = currentWeeklySets
    }
}
