import Foundation
import Combine

class AICoachViewModel: ObservableObject {
    @Published var insights: [CoachInsight] = []
    @Published var readiness: ReadinessScore?
    @Published var periodizationPlan: [PeriodizationBlock] = []
    @Published var trainingLoad: TrainingLoad?
    @Published var muscleVolumes: [MuscleGroupVolume] = []
    @Published var isLoading = false
    @Published var selectedPhase: PeriodizationPhase = .accumulation
    
    private let service = AICoachService.shared
    
    func loadAll() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let insights = self.service.generateInsights()
            let readiness = self.service.calculateReadiness()
            let plan = self.service.generatePeriodizationPlan()
            let load = self.service.calculateTrainingLoad()
            let volumes = self.service.calculateMuscleGroupVolumes()
            
            DispatchQueue.main.async {
                self.insights = insights
                self.readiness = readiness
                self.periodizationPlan = plan
                self.trainingLoad = load
                self.muscleVolumes = volumes
                self.isLoading = false
            }
        }
    }
    
    func dismissInsight(_ insight: CoachInsight) {
        insights.removeAll { $0.id == insight.id }
    }
    
    func currentPhaseBlock() -> PeriodizationBlock? {
        periodizationPlan.first { $0.phase == selectedPhase }
    }
}
