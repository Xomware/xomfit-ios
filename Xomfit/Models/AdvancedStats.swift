import Foundation

enum ChartTimeframe: String, CaseIterable, Identifiable {
    case oneMonth = "1M"
    case threeMonths = "3M"
    case sixMonths = "6M"
    case oneYear = "1Y"
    case allTime = "All"

    var id: String { rawValue }

    var startDate: Date? {
        let cal = Calendar.current
        let now = Date()
        switch self {
        case .oneMonth: return cal.date(byAdding: .month, value: -1, to: now)
        case .threeMonths: return cal.date(byAdding: .month, value: -3, to: now)
        case .sixMonths: return cal.date(byAdding: .month, value: -6, to: now)
        case .oneYear: return cal.date(byAdding: .year, value: -1, to: now)
        case .allTime: return nil
        }
    }
}

struct StrengthDataPoint: Identifiable, Codable {
    var id: UUID
    var date: Date
    var value: Double // Best set weight or estimated 1RM
    var reps: Int
    var exerciseName: String
    var estimated1RM: Double { value * (1 + Double(reps) / 30.0) }
    
    init(id: UUID = UUID(), date: Date, value: Double, reps: Int, exerciseName: String) {
        self.id = id
        self.date = date
        self.value = value
        self.reps = reps
        self.exerciseName = exerciseName
    }
}

struct MuscleHeatmapData: Identifiable, Codable {
    var id: UUID
    var muscleGroup: String
    var weeklyVolume: Int // total sets this week
    var intensity: Double // 0.0 - 1.0 relative to max
    
    init(id: UUID = UUID(), muscleGroup: String, weeklyVolume: Int, intensity: Double) {
        self.id = id
        self.muscleGroup = muscleGroup
        self.weeklyVolume = weeklyVolume
        self.intensity = intensity
    }
}

struct MusclePairBalance: Identifiable, Codable {
    var id: UUID
    var primaryMuscle: String
    var antagonistMuscle: String
    var ratio: Double // primary/antagonist (1.0 = balanced)
    var primaryVolume: Int
    var antagonistVolume: Int
    
    var isBalanced: Bool { ratio >= 0.7 && ratio <= 1.3 }
    var imbalanceDescription: String {
        if ratio > 1.3 { return "\(primaryMuscle) dominant (\(String(format: "%.1f", ratio))x)" }
        if ratio < 0.7 { return "\(antagonistMuscle) dominant (\(String(format: "%.1f", 1/ratio))x)" }
        return "Balanced"
    }
    
    init(id: UUID = UUID(), primaryMuscle: String, antagonistMuscle: String,
         primaryVolume: Int, antagonistVolume: Int) {
        self.id = id
        self.primaryMuscle = primaryMuscle
        self.antagonistMuscle = antagonistMuscle
        self.primaryVolume = primaryVolume
        self.antagonistVolume = antagonistVolume
        self.ratio = Double(primaryVolume) / Double(max(antagonistVolume, 1))
    }
}

struct WorkoutFrequencyDay: Identifiable, Codable {
    var id: UUID
    var date: Date
    var count: Int // number of workouts
    var intensity: Double // 0.0 - 1.0
    
    init(id: UUID = UUID(), date: Date, count: Int, maxCount: Int) {
        self.id = id
        self.date = date
        self.count = count
        self.intensity = Double(count) / Double(max(maxCount, 1))
    }
}

struct ExercisePR: Identifiable, Codable {
    var id: UUID
    var exerciseName: String
    var weight: Double
    var reps: Int
    var date: Date
    var estimated1RM: Double { weight * (1 + Double(reps) / 30.0) }
    
    init(id: UUID = UUID(), exerciseName: String, weight: Double, reps: Int, date: Date) {
        self.id = id
        self.exerciseName = exerciseName
        self.weight = weight
        self.reps = reps
        self.date = date
    }
}
