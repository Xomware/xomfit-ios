import SwiftUI

// MARK: - AIRecommendation View Helpers
extension AIRecommendation {
    var displayTitle: String {
        switch type {
        case .exercise: return exercise?.exercise.name ?? "Exercise Suggestion"
        case .repRange: return "Rep Range Adjustment"
        case .restPeriod: return "Recovery Recommendation"
        case .weakPoint: return "Weak Point: \(exercise?.exercise.muscleGroups.first?.displayName ?? "Unknown")"
        case .plateau: return "Plateau Breaker"
        case .volumeProgression: return "Volume Adjustment"
        case .exerciseSwap: return "Exercise Swap"
        case .newProgram: return program?.name ?? "New Program"
        case .formCorrection: return "Form Check"
        }
    }

    var displayIcon: String {
        switch type {
        case .exercise: return "🏋️"
        case .repRange: return "🔢"
        case .restPeriod: return "😴"
        case .weakPoint: return "🎯"
        case .plateau: return "📈"
        case .volumeProgression: return "📊"
        case .exerciseSwap: return "🔄"
        case .newProgram: return "📋"
        case .formCorrection: return "✅"
        }
    }

    var confidencePercentage: Int {
        Int(confidence * 100)
    }

    var confidenceColor: Color {
        switch confidence {
        case 0.8...: return .green
        case 0.6..<0.8: return .yellow
        default: return .orange
        }
    }
}

// MARK: - PerformanceAnalysis View Helpers
extension PerformanceAnalysis {
    var overallScore: Double {
        var score = 0.5

        // Volume trend
        switch volumeProgression.trend {
        case .up: score += 0.15
        case .stable: score += 0.05
        case .down: score -= 0.1
        }

        // Strength trend
        switch strengthProgression.trend {
        case .up: score += 0.15
        case .stable: score += 0.05
        case .down: score -= 0.1
        }

        // PRs bonus
        if strengthProgression.prsSinceDate > 0 {
            score += min(Double(strengthProgression.prsSinceDate) * 0.03, 0.15)
        }

        // Imbalance penalty
        score -= Double(imbalances.count) * 0.05

        return max(0, min(score, 1.0))
    }

    var imbalanceCount: Int {
        imbalances.count
    }

    var weakMuscleGroups: [MuscleGroupAnalysis] {
        muscleGroupsAnalysis.filter { $0.status == .weak }
    }

    var muscleGroupsSorted: [MuscleGroupAnalysis] {
        muscleGroupsAnalysis.sorted { $0.relativeVolume > $1.relativeVolume }
    }
}

// MARK: - Identifiable Conformances
extension PerformanceAnalysis.MuscleGroupAnalysis: Identifiable {
    var id: String { muscleGroup.rawValue }
}

extension PerformanceAnalysis.Imbalance: Identifiable {
    var id: String { "\(muscleGroup1.rawValue)-\(muscleGroup2.rawValue)" }
}

extension PerformanceAnalysis.ExerciseMax: Identifiable {
    var id: String { exerciseId }
}

// MARK: - AIRecommendation Hashable (for NavigationLink)
extension AIRecommendation: Hashable {
    static func == (lhs: AIRecommendation, rhs: AIRecommendation) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - UserTrainingPreferences Slider Binding Helpers
extension UserTrainingPreferences {
    var minRepsDouble: Double {
        get { Double(repRangeMin) }
        set { repRangeMin = Int(newValue) }
    }

    var maxRepsDouble: Double {
        get { Double(repRangeMax) }
        set { repRangeMax = Int(newValue) }
    }
}
