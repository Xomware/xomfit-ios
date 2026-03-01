import Foundation
import SwiftUI

class ExportService {
    static let shared = ExportService()
    private let workoutStore = WorkoutStore.shared
    
    // MARK: - CSV Export
    func exportWorkoutsCSV(from startDate: Date? = nil, to endDate: Date? = nil) -> String {
        var workouts = workoutStore.workouts.sorted { $0.startDate < $1.startDate }
        
        if let start = startDate { workouts = workouts.filter { $0.startDate >= start } }
        if let end = endDate { workouts = workouts.filter { $0.startDate <= end } }
        
        var csv = "Date,Time,Exercise,Set #,Reps,Weight (lbs),Volume (lbs),Notes\n"
        
        for workout in workouts {
            let date = DateFormatter.localizedString(from: workout.startDate, dateStyle: .short, timeStyle: .none)
            let time = DateFormatter.localizedString(from: workout.startDate, dateStyle: .none, timeStyle: .short)
            
            for (setIdx, set) in workout.sets.enumerated() {
                let exercise = (set.exerciseName ?? "Unknown").replacingOccurrences(of: ",", with: ";")
                let reps = set.reps.map { "\($0)" } ?? ""
                let weight = set.weight.map { "\($0)" } ?? ""
                let volume = (set.reps ?? 0) * Int(set.weight ?? 0)
                csv += "\(date),\(time),\(exercise),\(setIdx+1),\(reps),\(weight),\(volume),\n"
            }
        }
        
        return csv
    }
    
    // MARK: - JSON Export
    func exportWorkoutsJSON() -> Data? {
        let workouts = workoutStore.workouts.sorted { $0.startDate < $1.startDate }
        
        let exportData: [[String: Any]] = workouts.map { workout in
            [
                "id": workout.id.uuidString,
                "date": ISO8601DateFormatter().string(from: workout.startDate),
                "sets": workout.sets.map { set in
                    [
                        "exercise": set.exerciseName ?? "Unknown",
                        "reps": set.reps ?? 0,
                        "weight": set.weight ?? 0
                    ]
                }
            ]
        }
        
        return try? JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
    }
    
    // MARK: - PDF Training Log
    func exportPDFReport() -> Data {
        // In production: use UIGraphicsPDFRenderer for formatted PDF
        // For now, return a text-based representation
        var report = "XomFit Training Log\n"
        report += "Generated: \(Date().formatted())\n"
        report += String(repeating: "=", count: 50) + "\n\n"
        
        let workouts = workoutStore.workouts.sorted { $0.startDate > $1.startDate }.prefix(20)
        
        for workout in workouts {
            report += "📅 \(workout.startDate.formatted(date: .abbreviated, time: .shortened))\n"
            for set in workout.sets {
                let exercise = set.exerciseName ?? "Unknown"
                let reps = set.reps.map { "\($0)" } ?? "—"
                let weight = set.weight.map { "\($0)lbs" } ?? "—"
                report += "   • \(exercise): \(weight) × \(reps)\n"
            }
            report += "\n"
        }
        
        return report.data(using: .utf8) ?? Data()
    }
    
    // MARK: - Share Card Rendering
    @MainActor
    func renderShareCard(view: some View, size: CGSize = CGSize(width: 1080, height: 1080)) -> UIImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = UIScreen.main.scale
        renderer.proposedSize = ProposedViewSize(size)
        return renderer.uiImage
    }
    
    // MARK: - Stats Summary
    func workoutSummary() -> WorkoutSummaryData {
        let workouts = workoutStore.workouts
        let totalVolume = workouts.flatMap { $0.sets }.reduce(0.0) { acc, set in
            acc + Double(set.reps ?? 0) * (set.weight ?? 0)
        }
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let weeklyWorkouts = workouts.filter { $0.startDate >= sevenDaysAgo }.count
        
        return WorkoutSummaryData(
            totalWorkouts: workouts.count,
            totalVolumeLbs: Int(totalVolume),
            weeklyWorkouts: weeklyWorkouts,
            topExercise: topExercise()
        )
    }
    
    func topExercise() -> String {
        let exercises = workoutStore.workouts.flatMap { $0.sets }.compactMap { $0.exerciseName }
        let counts = exercises.reduce(into: [:]) { $0[$1, default: 0] += 1 }
        return counts.max(by: { $0.value < $1.value })?.key ?? "—"
    }
}

struct WorkoutSummaryData {
    var totalWorkouts: Int
    var totalVolumeLbs: Int
    var weeklyWorkouts: Int
    var topExercise: String
}
