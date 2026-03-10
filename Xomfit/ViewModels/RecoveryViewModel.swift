import Foundation
import Combine

@MainActor
class RecoveryViewModel: ObservableObject {
    @Published var readiness: DailyReadiness?
    @Published var soreness: [MuscleSoreness] = []
    @Published var sleepLog: [SleepEntry] = []
    @Published var recoveryTimeline: [(String, Date, Bool)] = []
    @Published var isOvertrainingRisk = false
    
    // Sleep logging form
    @Published var sleepHours: Double = 7.5
    @Published var sleepQuality: Int = 3
    @Published var showSleepLogger = false
    
    // HRV form
    @Published var hrvValue: String = ""
    @Published var restingHR: String = ""
    @Published var showHRVLogger = false
    
    private let service = RecoveryService.shared
    
    func loadAll() {
        soreness = service.soreness
        sleepLog = Array(service.sleepLog.prefix(7))
        readiness = service.calculateDailyReadiness()
        recoveryTimeline = service.recoveryTimeline()
        isOvertrainingRisk = service.isOvertrainingRisk()
    }
    
    func updateSoreness(muscle: String, level: SorenessLevel) {
        service.updateSoreness(muscleGroup: muscle, level: level)
        loadAll()
    }
    
    func logSleep() {
        service.logSleep(hours: sleepHours, quality: sleepQuality)
        showSleepLogger = false
        loadAll()
    }
    
    func logHRV() {
        if let hrv = Double(hrvValue), let hr = Int(restingHR) {
            service.logHRV(hrv: hrv, restingHR: hr)
        }
        showHRVLogger = false
        loadAll()
    }
}
