import Foundation

enum WeightMode: String, Codable {
    case total      // default: weight is total (both hands on barbell)
    case perSide    // weight is per arm/leg (e.g., 25lb each arm)
}

struct WorkoutSet: Codable, Identifiable, Hashable {
    let id: String
    var exerciseId: String
    var weight: Double
    var reps: Int
    var rpe: Double? // Rate of Perceived Exertion (1-10)
    var isPersonalRecord: Bool
    var completedAt: Date
    var weightMode: WeightMode = .total

    // MARK: - Form Check Video (optional attachment)
    var videoLocalURL: URL?       // locally saved clip after recording
    var videoRemoteURL: URL?      // uploaded to Supabase Storage

    var volume: Double {
        let multiplier: Double = weightMode == .perSide ? 2 : 1
        return weight * Double(reps) * multiplier
    }
    
    var estimated1RM: Double {
        // Epley formula
        if reps == 1 { return weight }
        return weight * (1 + Double(reps) / 30.0)
    }
    
    var displayWeight: String {
        weight.formattedWeight + " lbs"
    }
    
    var displaySet: String {
        "\(weight.formattedWeight) × \(reps)"
    }
}

// MARK: - Mock Data
extension WorkoutSet {
    static let mockSets: [WorkoutSet] = [
        WorkoutSet(id: "set-1", exerciseId: "ex-1", weight: 225, reps: 5, rpe: 8, isPersonalRecord: false, completedAt: Date()),
        WorkoutSet(id: "set-2", exerciseId: "ex-1", weight: 225, reps: 5, rpe: 8.5, isPersonalRecord: false, completedAt: Date()),
        WorkoutSet(id: "set-3", exerciseId: "ex-1", weight: 235, reps: 3, rpe: 9, isPersonalRecord: true, completedAt: Date()),
    ]
}
