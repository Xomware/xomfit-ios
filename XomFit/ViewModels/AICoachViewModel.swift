import Foundation
import SwiftUI

@MainActor
class AICoachViewModel: ObservableObject {
    @Published var recommendations: [AIRecommendation] = []
    @Published var performanceAnalysis: PerformanceAnalysis?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var userPreferences: UserTrainingPreferences = UserTrainingPreferences()
    @Published var selectedRecommendation: AIRecommendation?
    
    private let aiCoachService: AICoachServiceProtocol
    private let workoutStore: WorkoutStore
    
    var hasRecommendations: Bool {
        !recommendations.isEmpty
    }
    
    var topRecommendation: AIRecommendation? {
        recommendations.first
    }
    
    init(aiCoachService: AICoachServiceProtocol = AICoachService.shared, workoutStore: WorkoutStore = WorkoutStore.shared) {
        self.aiCoachService = aiCoachService
        self.workoutStore = workoutStore
    }
    
    // MARK: - Load Recommendations
    
    func loadRecommendations(userId: String, workouts: [Workout], userStats: User.UserStats) {
        Task {
            isLoading = true
            errorMessage = nil
            
            do {
                recommendations = try await aiCoachService.generateRecommendations(
                    userId: userId,
                    workouts: workouts,
                    userStats: userStats
                )
            } catch {
                errorMessage = "Failed to generate recommendations: \(error.localizedDescription)"
                recommendations = []
            }
            
            isLoading = false
        }
    }
    
    // MARK: - Analyze Performance
    
    func analyzePerformance(userId: String, workouts: [Workout]) {
        Task {
            isLoading = true
            errorMessage = nil
            
            do {
                performanceAnalysis = try await aiCoachService.analyzePerformance(userId: userId, workouts: workouts)
            } catch {
                errorMessage = "Failed to analyze performance: \(error.localizedDescription)"
                performanceAnalysis = nil
            }
            
            isLoading = false
        }
    }
    
    // MARK: - Recommendation Actions
    
    func acceptRecommendation(_ recommendation: AIRecommendation) {
        Task {
            do {
                try await aiCoachService.recordRecommendationFeedback(
                    userId: recommendation.userId,
                    recommendationId: recommendation.id,
                    accepted: true
                )
                // Remove from list
                recommendations.removeAll { $0.id == recommendation.id }
            } catch {
                errorMessage = "Failed to record feedback: \(error.localizedDescription)"
            }
        }
    }
    
    func dismissRecommendation(_ recommendation: AIRecommendation) {
        Task {
            do {
                try await aiCoachService.recordRecommendationFeedback(
                    userId: recommendation.userId,
                    recommendationId: recommendation.id,
                    accepted: false
                )
                // Remove from list
                recommendations.removeAll { $0.id == recommendation.id }
            } catch {
                errorMessage = "Failed to record feedback: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Get Personalized Program
    
    func getPersonalizedProgram(userId: String, workouts: [Workout]) {
        Task {
            isLoading = true
            errorMessage = nil
            
            do {
                let program = try await aiCoachService.getPersonalizedProgram(
                    userId: userId,
                    workouts: workouts,
                    preferences: userPreferences
                )
                
                // You could save this program or display it
                // For now, we'll create a recommendation for it
                let recommendation = AIRecommendation(
                    userId: userId,
                    type: .newProgram,
                    program: program,
                    confidence: 0.90,
                    reasoning: program.reasoning
                )
                selectedRecommendation = recommendation
            } catch {
                errorMessage = "Failed to generate program: \(error.localizedDescription)"
            }
            
            isLoading = false
        }
    }
    
    // MARK: - Preference Management
    
    func updatePreference(split: ProgramRecommendation.SplitType) {
        userPreferences.preferredSplit = split
    }
    
    func updatePreference(daysPerWeek: Int) {
        userPreferences.targetDaysPerWeek = daysPerWeek
    }
    
    func updatePreference(repRange: (min: Int, max: Int)) {
        userPreferences.repRangePreference = repRange
    }
    
    func toggleExerciseAvoidance(_ exerciseId: String) {
        if userPreferences.avoidExercises.contains(exerciseId) {
            userPreferences.avoidExercises.removeAll { $0 == exerciseId }
        } else {
            userPreferences.avoidExercises.append(exerciseId)
        }
    }
}

// MARK: - Recommendation Display Helpers

extension AIRecommendation {
    var displayTitle: String {
        switch type {
        case .exercise:
            return "Add \(exercise?.exercise.name ?? "Exercise")"
        case .repRange:
            return "Adjust Rep Range"
        case .restPeriod:
            return "Recovery Recommended"
        case .weakPoint:
            return "Address Weak Point"
        case .plateau:
            return "Break Through Plateau"
        case .volumeProgression:
            return "Volume Adjustment"
        case .exerciseSwap:
            return "Swap Exercise"
        case .newProgram:
            return "New Program: \(program?.name ?? "Recommended")"
        case .formCorrection:
            return "Form Feedback"
        }
    }
    
    var displayIcon: String {
        switch type {
        case .exercise:
            return "➕"
        case .repRange:
            return "🔄"
        case .restPeriod:
            return "😴"
        case .weakPoint:
            return "💪"
        case .plateau:
            return "⬆️"
        case .volumeProgression:
            return "📊"
        case .exerciseSwap:
            return "🔁"
        case .newProgram:
            return "📋"
        case .formCorrection:
            return "🎯"
        }
    }
    
    var confidencePercentage: Int {
        Int(confidence * 100)
    }
    
    var confidenceColor: Color {
        switch confidence {
        case 0.8...: return .green
        case 0.6...: return .yellow
        default: return .orange
        }
    }
}

// MARK: - Performance Analysis Helpers

extension PerformanceAnalysis {
    var overallScore: Double {
        let volumeTrend = volumeProgression.trend == .up ? 1.0 : (volumeProgression.trend == .down ? 0.5 : 0.75)
        let strengthTrend = strengthProgression.trend == .up ? 1.0 : (strengthProgression.trend == .down ? 0.5 : 0.75)
        let balanceScore = 1.0 - (Double(imbalances.count) * 0.1)
        
        return (volumeTrend + strengthTrend + balanceScore) / 3.0
    }
    
    var muscleGroupsSorted: [MuscleGroupAnalysis] {
        muscleGroupsAnalysis.sorted { $0.relativeVolume > $1.relativeVolume }
    }
    
    var weakMuscleGroups: [MuscleGroupAnalysis] {
        muscleGroupsAnalysis.filter { $0.status == .weak }
    }
    
    var imbalanceCount: Int {
        imbalances.filter { $0.severity != .minor }.count
    }
}
