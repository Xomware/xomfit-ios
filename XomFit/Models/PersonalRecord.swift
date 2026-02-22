import Foundation

struct PersonalRecord: Codable, Identifiable {
    let id: String
    var userId: String
    var exerciseId: String
    var exerciseName: String
    var weight: Double
    var reps: Int
    var date: Date
    var previousBest: Double?
    
    var improvement: Double? {
        guard let prev = previousBest else { return nil }
        return weight - prev
    }
    
    var improvementString: String? {
        guard let imp = improvement else { return nil }
        return "+\(imp.formattedWeight) lbs"
    }
}

// MARK: - Mock Data
extension PersonalRecord {
    static let mockPRs: [PersonalRecord] = [
        PersonalRecord(id: "pr-1", userId: "user-1", exerciseId: "ex-1", exerciseName: "Bench Press", weight: 235, reps: 3, date: Date(), previousBest: 225),
        PersonalRecord(id: "pr-2", userId: "user-1", exerciseId: "ex-2", exerciseName: "Squat", weight: 315, reps: 5, date: Date().addingTimeInterval(-86400 * 3), previousBest: 305),
        PersonalRecord(id: "pr-3", userId: "user-1", exerciseId: "ex-3", exerciseName: "Deadlift", weight: 405, reps: 1, date: Date().addingTimeInterval(-86400 * 7), previousBest: 395),
    ]
}
