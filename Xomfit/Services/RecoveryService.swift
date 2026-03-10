import Foundation

@MainActor
class RecoveryService: ObservableObject {
    static let shared = RecoveryService()
    
    @Published var soreness: [MuscleSoreness] = []
    @Published var sleepLog: [SleepEntry] = []
    @Published var hrvLog: [HRVEntry] = []
    @Published var readinessHistory: [DailyReadiness] = []
    
    private let sorenessKey = "xomfit_soreness"
    private let sleepKey = "xomfit_sleep_log"
    private let hrvKey = "xomfit_hrv_log"
    
    let muscleGroups = ["Chest", "Back", "Shoulders", "Biceps", "Triceps",
                        "Quads", "Hamstrings", "Glutes", "Calves", "Core"]
    
    init() {
        load()
        if soreness.isEmpty { initializeSoreness() }
    }
    
    private func initializeSoreness() {
        soreness = muscleGroups.map { MuscleSoreness(muscleGroup: $0) }
        persistSoreness()
    }
    
    // MARK: - Soreness
    func updateSoreness(muscleGroup: String, level: SorenessLevel) {
        if let idx = soreness.firstIndex(where: { $0.muscleGroup == muscleGroup }) {
            soreness[idx].level = level
            soreness[idx].lastTrainedAt = level != .none ? Date() : nil
        }
        persistSoreness()
    }
    
    // MARK: - Sleep
    func logSleep(hours: Double, quality: Int, notes: String = "") {
        let entry = SleepEntry(hoursSlept: hours, quality: quality, notes: notes)
        sleepLog.insert(entry, at: 0)
        if let data = try? JSONEncoder().encode(sleepLog) {
            UserDefaults.standard.set(data, forKey: sleepKey)
        }
    }
    
    func lastNightSleep() -> SleepEntry? {
        sleepLog.first
    }
    
    // MARK: - HRV
    func logHRV(hrv: Double, restingHR: Int) {
        let entry = HRVEntry(hrv: hrv, restingHR: restingHR)
        hrvLog.insert(entry, at: 0)
        if let data = try? JSONEncoder().encode(hrvLog) {
            UserDefaults.standard.set(data, forKey: hrvKey)
        }
    }
    
    func averageHRV(days: Int = 7) -> Double {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let recent = hrvLog.filter { $0.date >= cutoff }
        guard !recent.isEmpty else { return 0 }
        return recent.map { $0.hrv }.reduce(0, +) / Double(recent.count)
    }
    
    // MARK: - Readiness Calculation
    func calculateDailyReadiness() -> DailyReadiness {
        // Sleep score
        let sleep = lastNightSleep()
        let sleepScore = sleep?.recoveryScore ?? 50
        
        // Soreness score (inverse: more sore = lower score)
        let avgSoreness = Double(soreness.map { $0.level.rawValue }.reduce(0, +)) / Double(max(soreness.count, 1))
        let sorenessScore = max(0, Int(100 - avgSoreness * 20))
        
        // Training load score (from AI coach)
        let workoutStore = WorkoutStore.shared
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let recentWorkouts = workoutStore.workouts.filter { $0.startDate >= sevenDaysAgo }.count
        let loadScore = max(0, 100 - recentWorkouts * 15) // Penalize high frequency
        
        // HRV score
        let avgHrv = averageHRV()
        let hrvScore = avgHrv > 0 ? min(Int(avgHrv / 1.0), 100) : 60 // Default 60 if no HRV data
        
        let overall = (sleepScore + sorenessScore + loadScore + min(hrvScore, 100)) / 4
        
        let status: RecoveryStatus
        switch overall {
        case 75...: status = .train
        case 60..<75: status = .moderate
        case 40..<60: status = .light
        default: status = .rest
        }
        
        return DailyReadiness(
            score: overall,
            status: status,
            sleepScore: sleepScore,
            sorenessScore: sorenessScore,
            trainingLoadScore: loadScore,
            hrvScore: min(hrvScore, 100)
        )
    }
    
    // MARK: - Overtraining Detection
    func isOvertrainingRisk() -> Bool {
        let workoutStore = WorkoutStore.shared
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let recentWorkouts = workoutStore.workouts.filter { $0.startDate >= sevenDaysAgo }
        
        let consecutiveDays = recentWorkouts.count
        let avgSoreness = Double(soreness.map { $0.level.rawValue }.reduce(0, +)) / Double(max(soreness.count, 1))
        
        return consecutiveDays >= 5 && avgSoreness > 2.5
    }
    
    // MARK: - Recovery Timeline
    func recoveryTimeline() -> [(String, Date, Bool)] {
        soreness.map { muscle in
            (muscle.muscleGroup, muscle.estimatedRecoveryDate, muscle.isReady)
        }.sorted { $0.1 < $1.1 }
    }
    
    // MARK: - Persistence
    private func persistSoreness() {
        if let data = try? JSONEncoder().encode(soreness) {
            UserDefaults.standard.set(data, forKey: sorenessKey)
        }
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: sorenessKey),
           let decoded = try? JSONDecoder().decode([MuscleSoreness].self, from: data) {
            soreness = decoded
        }
        if let data = UserDefaults.standard.data(forKey: sleepKey),
           let decoded = try? JSONDecoder().decode([SleepEntry].self, from: data) {
            sleepLog = decoded
        }
        if let data = UserDefaults.standard.data(forKey: hrvKey),
           let decoded = try? JSONDecoder().decode([HRVEntry].self, from: data) {
            hrvLog = decoded
        }
    }
}
