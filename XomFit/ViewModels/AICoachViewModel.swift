import Foundation
import Combine

@MainActor
class AICoachViewModel: ObservableObject {
    // Coach tab (Views/Coach/)
    @Published var insights: [CoachInsight] = []
    @Published var readiness: ReadinessScore?
    @Published var periodizationPlan: [PeriodizationBlock] = []
    @Published var trainingLoad: TrainingLoad?
    @Published var muscleVolumes: [MuscleGroupVolume] = []

    // AI recommendations (Views/AICoach/)
    @Published var recommendations: [AIRecommendation] = []
    @Published var performanceAnalysis: PerformanceAnalysis?
    @Published var userPreferences = UserTrainingPreferences()
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedPhase: PeriodizationPhase = .accumulation

    private let service: AICoachService

    var topRecommendation: AIRecommendation? {
        recommendations.first
    }

    var hasRecommendations: Bool {
        !recommendations.isEmpty
    }

    init(service: AICoachService = .shared) {
        self.service = service
    }

    // MARK: - Coach Tab Loading
    func loadAll() {
        isLoading = true
        let store = WorkoutStore.shared
        Task.detached { [weak self] in
            guard let self else { return }
            let workouts = await store.workouts
            let insights = self.service.generateInsights(from: workouts)
            let readiness = self.service.calculateReadiness(from: workouts)
            let plan = self.service.generatePeriodizationPlan()
            let load = self.service.calculateTrainingLoad(from: workouts)
            let volumes = self.service.calculateMuscleGroupVolumes(from: workouts)

            await MainActor.run {
                self.insights = insights
                self.readiness = readiness
                self.periodizationPlan = plan
                self.trainingLoad = load
                self.muscleVolumes = volumes
                self.isLoading = false
            }
        }
    }

    // MARK: - AI Coach Tab Loading
    func loadRecommendations(userId: String, workouts: [Workout], userStats: User.UserStats? = nil) {
        isLoading = true
        errorMessage = nil
        Task.detached { [weak self] in
            guard let self else { return }
            let recs = self.service.generateRecommendations(userId: userId, workouts: workouts, userStats: userStats)
            await MainActor.run {
                self.recommendations = recs
                self.isLoading = false
            }
        }
    }

    func analyzePerformance(userId: String, workouts: [Workout]) {
        Task.detached { [weak self] in
            guard let self else { return }
            let analysis = self.service.analyzePerformance(userId: userId, workouts: workouts)
            await MainActor.run {
                self.performanceAnalysis = analysis
            }
        }
    }

    func acceptRecommendation(_ rec: AIRecommendation) {
        service.recordFeedback(recommendationId: rec.id, accepted: true)
        recommendations.removeAll { $0.id == rec.id }
    }

    func dismissRecommendation(_ rec: AIRecommendation) {
        service.recordFeedback(recommendationId: rec.id, accepted: false)
        recommendations.removeAll { $0.id == rec.id }
    }

    func dismissInsight(_ insight: CoachInsight) {
        insights.removeAll { $0.id == insight.id }
    }

    func currentPhaseBlock() -> PeriodizationBlock? {
        periodizationPlan.first { $0.phase == selectedPhase }
    }
}
