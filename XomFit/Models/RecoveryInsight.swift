import Foundation

enum RecoveryStatus: String, Codable, CaseIterable {
    case train = "Train Hard"
    case moderate = "Train Moderate"
    case light = "Light Activity"
    case rest = "Rest Day"
    
    var emoji: String {
        switch self {
        case .train: return "🟢"
        case .moderate: return "🟡"
        case .light: return "🟠"
        case .rest: return "🔴"
        }
    }
}

enum SorenessLevel: Int, Codable, CaseIterable {
    case none = 0
    case mild = 1
    case moderate = 2
    case significant = 3
    case severe = 4
    
    var label: String {
        switch self {
        case .none: return "None"
        case .mild: return "Mild"
        case .moderate: return "Moderate"
        case .significant: return "Significant"
        case .severe: return "Severe"
        }
    }
    
    var recoveryDaysNeeded: Int {
        switch self {
        case .none: return 0
        case .mild: return 1
        case .moderate: return 2
        case .significant: return 3
        case .severe: return 4
        }
    }
}

struct MuscleSoreness: Identifiable, Codable {
    var id: UUID
    var muscleGroup: String
    var level: SorenessLevel
    var lastTrainedAt: Date?
    var estimatedRecoveryDate: Date {
        let days = level.recoveryDaysNeeded
        return Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
    }
    var isReady: Bool { level == .none || level == .mild }
    
    init(id: UUID = UUID(), muscleGroup: String, level: SorenessLevel = .none, lastTrainedAt: Date? = nil) {
        self.id = id
        self.muscleGroup = muscleGroup
        self.level = level
        self.lastTrainedAt = lastTrainedAt
    }
}

struct SleepEntry: Identifiable, Codable {
    var id: UUID
    var date: Date
    var hoursSlept: Double
    var quality: Int // 1-5
    var notes: String
    
    init(id: UUID = UUID(), date: Date = Date(), hoursSlept: Double, quality: Int, notes: String = "") {
        self.id = id
        self.date = date
        self.hoursSlept = hoursSlept
        self.quality = quality
        self.notes = notes
    }
    
    var recoveryScore: Int {
        let hourScore = min(Int(hoursSlept / 8.0 * 50), 50)
        let qualityScore = quality * 10
        return hourScore + qualityScore
    }
}

struct HRVEntry: Identifiable, Codable {
    var id: UUID
    var date: Date
    var hrv: Double // milliseconds
    var restingHR: Int // bpm
    
    init(id: UUID = UUID(), date: Date = Date(), hrv: Double, restingHR: Int) {
        self.id = id
        self.date = date
        self.hrv = hrv
        self.restingHR = restingHR
    }
}

struct DailyReadiness: Identifiable, Codable {
    var id: UUID
    var date: Date
    var score: Int // 0-100
    var status: RecoveryStatus
    var sleepScore: Int
    var sorenessScore: Int
    var trainingLoadScore: Int
    var hrvScore: Int
    
    init(id: UUID = UUID(), date: Date = Date(), score: Int, status: RecoveryStatus,
         sleepScore: Int, sorenessScore: Int, trainingLoadScore: Int, hrvScore: Int) {
        self.id = id
        self.date = date
        self.score = score
        self.status = status
        self.sleepScore = sleepScore
        self.sorenessScore = sorenessScore
        self.trainingLoadScore = trainingLoadScore
        self.hrvScore = hrvScore
    }
}
