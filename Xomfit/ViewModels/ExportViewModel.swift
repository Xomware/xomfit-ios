import Foundation
import SwiftUI

@MainActor
class ExportViewModel: ObservableObject {
    @Published var summary = WorkoutSummaryData(totalWorkouts: 0, totalVolumeLbs: 0, weeklyWorkouts: 0, topExercise: "—")
    @Published var streak = 0
    @Published var exportStartDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @Published var exportEndDate = Date()
    @Published var showShareSheet = false
    @Published var shareItems: [Any] = []
    
    private let exportService = ExportService.shared
    private let workoutStore = WorkoutStore.shared
    
    func load() {
        summary = exportService.workoutSummary()
        streak = calculateStreak()
    }
    
    func calculateStreak() -> Int {
        let workouts = workoutStore.workouts.sorted { $0.startDate > $1.startDate }
        var streak = 0
        var currentDate = Calendar.current.startOfDay(for: Date())
        
        for workout in workouts {
            let workoutDay = Calendar.current.startOfDay(for: workout.startDate)
            if workoutDay == currentDate {
                streak += 1
                currentDate = Calendar.current.date(byAdding: .day, value: -1, to: currentDate)!
            } else if workoutDay < currentDate {
                break
            }
        }
        return streak
    }
    
    func exportCSV() {
        let csv = exportService.exportWorkoutsCSV(from: exportStartDate, to: exportEndDate)
        let filename = "xomfit_workouts_\(Date().formatted(date: .abbreviated, time: .omitted)).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? csv.write(to: tempURL, atomically: true, encoding: .utf8)
        shareItems = [tempURL]
        showShareSheet = true
    }
    
    func exportJSON() {
        if let data = exportService.exportWorkoutsJSON() {
            let filename = "xomfit_workouts.json"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try? data.write(to: tempURL)
            shareItems = [tempURL]
            showShareSheet = true
        }
    }
    
    func exportPDF() {
        let data = exportService.exportPDFReport()
        let filename = "xomfit_training_log.txt"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: tempURL)
        shareItems = [tempURL]
        showShareSheet = true
    }
}
