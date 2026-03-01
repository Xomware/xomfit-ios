import Foundation
import Combine

class AdvancedStatsViewModel: ObservableObject {
    @Published var heatmapData: [MuscleHeatmapData] = []
    @Published var balanceRatios: [MusclePairBalance] = []
    @Published var strengthCurveData: [StrengthDataPoint] = []
    @Published var frequencyData: [WorkoutFrequencyDay] = []
    @Published var allTimePRs: [ExercisePR] = []
    @Published var availableExercises: [String] = []
    @Published var selectedExercise: String = ""
    @Published var isLoading = false
    @Published var selectedPeriod = 30 // days for balance
    
    private let service = AdvancedStatsService.shared
    
    func loadAll() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let heatmap = self.service.muscleHeatmap(days: 7)
            let balance = self.service.muscleBalanceRatios(days: 30)
            let frequency = self.service.workoutFrequencyHeatmap(days: 364)
            let prs = self.service.allTimePRs()
            let exercises = self.service.availableExercises()
            
            DispatchQueue.main.async {
                self.heatmapData = heatmap
                self.balanceRatios = balance
                self.frequencyData = frequency
                self.allTimePRs = prs
                self.availableExercises = exercises
                self.selectedExercise = exercises.first ?? ""
                if !self.selectedExercise.isEmpty {
                    self.loadStrengthCurve(for: self.selectedExercise)
                }
                self.isLoading = false
            }
        }
    }
    
    func loadStrengthCurve(for exercise: String) {
        let data = service.bestSetsPerDay(for: exercise, days: 90)
        DispatchQueue.main.async {
            self.strengthCurveData = data
            self.selectedExercise = exercise
        }
    }
    
    func exportCSV() -> String {
        return service.exportToCSV()
    }
}
