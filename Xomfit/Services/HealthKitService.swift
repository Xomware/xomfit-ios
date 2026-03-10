import Foundation
import HealthKit

@MainActor
class HealthKitService: ObservableObject {
    static let shared = HealthKitService()
    
    private let healthStore = HKHealthStore()
    
    @Published var isAuthorized = false
    @Published var lastSyncDate: Date?
    @Published var stepsToday: Int = 0
    @Published var sleepHoursLast: Double = 0
    @Published var restingHR: Double = 0
    @Published var activeCaloriesToday: Int = 0
    
    // MARK: - Types to Read
    var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = []
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) { types.insert(steps) }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { types.insert(sleep) }
        if let hr = HKObjectType.quantityType(forIdentifier: .restingHeartRate) { types.insert(hr) }
        if let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) { types.insert(hrv) }
        if let calories = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { types.insert(calories) }
        if let weight = HKObjectType.quantityType(forIdentifier: .bodyMass) { types.insert(weight) }
        return types
    }
    
    // MARK: - Types to Write
    var writeTypes: Set<HKSampleType> {
        var types: Set<HKSampleType> = []
        if let workout = HKObjectType.workoutType() as? HKSampleType { types.insert(workout) }
        if let calories = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { types.insert(calories) }
        if let hr = HKObjectType.quantityType(forIdentifier: .heartRate) { types.insert(hr) }
        return types
    }
    
    // MARK: - Request Authorization
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, nil)
            return
        }
        
        healthStore.requestAuthorization(toShare: writeTypes, read: readTypes) { success, error in
            DispatchQueue.main.async {
                self.isAuthorized = success
                if success { self.fetchAllData() }
                completion(success, error)
            }
        }
    }
    
    // MARK: - Fetch Data
    func fetchAllData() {
        fetchStepsToday()
        fetchRestingHR()
        fetchActiveCaloriesToday()
        lastSyncDate = Date()
    }
    
    func fetchStepsToday() {
        guard let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: stepsType, quantitySamplePredicate: predicate,
                                      options: .cumulativeSum) { _, result, _ in
            DispatchQueue.main.async {
                self.stepsToday = Int(result?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
            }
        }
        healthStore.execute(query)
    }
    
    func fetchRestingHR() {
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return }
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: hrType, predicate: nil, limit: 1,
                                  sortDescriptors: [sortDescriptor]) { _, samples, _ in
            guard let sample = samples?.first as? HKQuantitySample else { return }
            DispatchQueue.main.async {
                self.restingHR = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
            }
        }
        healthStore.execute(query)
    }
    
    func fetchActiveCaloriesToday() {
        guard let caloriesType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: caloriesType, quantitySamplePredicate: predicate,
                                      options: .cumulativeSum) { _, result, _ in
            DispatchQueue.main.async {
                self.activeCaloriesToday = Int(result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0)
            }
        }
        healthStore.execute(query)
    }
    
    // MARK: - Write Workout to Health
    func writeWorkout(startDate: Date, endDate: Date, calories: Double,
                      completion: @escaping (Bool, Error?) -> Void) {
        let workout = HKWorkout(
            activityType: .traditionalStrengthTraining,
            start: startDate,
            end: endDate,
            duration: endDate.timeIntervalSince(startDate),
            totalEnergyBurned: HKQuantity(unit: .kilocalorie(), doubleValue: calories),
            totalDistance: nil,
            metadata: ["source": "XomFit"]
        )
        
        healthStore.save(workout) { success, error in
            DispatchQueue.main.async {
                completion(success, error)
            }
        }
    }
    
    // MARK: - Health data summary for Recovery module
    func fetchHRVForRecovery(completion: @escaping (Double?) -> Void) {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            completion(nil)
            return
        }
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: hrvType, predicate: nil, limit: 1,
                                  sortDescriptors: [sortDescriptor]) { _, samples, _ in
            guard let sample = samples?.first as? HKQuantitySample else {
                completion(nil)
                return
            }
            completion(sample.quantity.doubleValue(for: HKUnit(from: "ms")))
        }
        healthStore.execute(query)
    }
    
    // MARK: - HealthKit Availability
    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }
}
