import Foundation
import HealthKit
import Combine

/// Manages HealthKit workout session and heart rate on Apple Watch.
@MainActor
class WatchWorkoutManager: ObservableObject {
    @Published var isWorkoutActive = false
    @Published var heartRate: Double = 0
    @Published var currentExercise: String = ""
    @Published var currentSetNumber: Int = 0
    @Published var totalSets: Int = 0
    @Published var restDuration: TimeInterval = 90

    // Rest timer
    @Published var restTimeRemaining: TimeInterval = 0
    @Published var isRestTimerRunning = false

    // Set logging
    @Published var lastLoggedWeight: Double = 135
    @Published var lastLoggedReps: Int = 10

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var heartRateQuery: HKAnchoredObjectQuery?
    private var restTimer: Timer?
    private var extendedSession: WKExtendedRuntimeSession?

    init() {}

    // MARK: - Workout Lifecycle

    func startWorkout() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        config.locationType = .indoor

        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            workoutBuilder = workoutSession?.associatedWorkoutBuilder()
            workoutBuilder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)

            workoutSession?.startActivity(with: Date())
            workoutBuilder?.beginCollection(withStart: Date()) { _, _ in }

            isWorkoutActive = true
            startHeartRateQuery()
            startExtendedSession()
        } catch {
            print("Failed to start workout: \(error)")
        }
    }

    func endWorkout() {
        workoutSession?.end()
        workoutBuilder?.endCollection(withEnd: Date()) { [weak self] _, _ in
            self?.workoutBuilder?.finishWorkout { _, _ in }
        }
        stopHeartRateQuery()
        stopRestTimer()
        endExtendedSession()
        isWorkoutActive = false
    }

    // MARK: - Heart Rate

    private func startHeartRateQuery() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }

        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: HKQuery.predicateForSamples(withStart: Date(), end: nil, options: .strictStartDate),
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            self?.processHeartRateSamples(samples)
        }

        query.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.processHeartRateSamples(samples)
        }

        healthStore.execute(query)
        heartRateQuery = query
    }

    private func stopHeartRateQuery() {
        if let query = heartRateQuery {
            healthStore.stop(query)
            heartRateQuery = nil
        }
    }

    private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let quantitySamples = samples as? [HKQuantitySample],
              let last = quantitySamples.last else { return }
        let bpm = last.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        Task { @MainActor in
            self.heartRate = bpm
        }
    }

    // MARK: - Rest Timer

    func startRestTimer(duration: TimeInterval? = nil) {
        let d = duration ?? restDuration
        restTimeRemaining = d
        isRestTimerRunning = true
        restTimer?.invalidate()
        restTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.restTimeRemaining > 0 {
                    self.restTimeRemaining -= 1
                } else {
                    self.restTimerFinished()
                }
            }
        }
    }

    func stopRestTimer() {
        restTimer?.invalidate()
        restTimer = nil
        isRestTimerRunning = false
        restTimeRemaining = 0
    }

    func addRestTime(_ seconds: TimeInterval) {
        restTimeRemaining += seconds
    }

    private func restTimerFinished() {
        restTimer?.invalidate()
        restTimer = nil
        isRestTimerRunning = false
        WKInterfaceDevice.current().play(.success)
    }

    // MARK: - Set Logging

    func logSet(weight: Double, reps: Int) -> [String: Any] {
        lastLoggedWeight = weight
        lastLoggedReps = reps
        currentSetNumber += 1
        WKInterfaceDevice.current().play(.click)

        let setData: [String: Any] = [
            "id": UUID().uuidString,
            "exercise": currentExercise,
            "weight": weight,
            "reps": reps,
            "setNumber": currentSetNumber,
            "completedAt": ISO8601DateFormatter().string(from: Date())
        ]

        // Send to phone
        WatchConnectivityManager.shared.sendLoggedSet(setData)

        // Auto-start rest timer
        startRestTimer()

        return setData
    }

    // MARK: - Context from Phone

    func updateFromPhone(context: [String: Any]) {
        if let exercise = context["exercise"] as? String {
            currentExercise = exercise
        }
        if let setNumber = context["setNumber"] as? Int {
            currentSetNumber = setNumber
        }
        if let total = context["totalSets"] as? Int {
            totalSets = total
        }
        if let rest = context["restDuration"] as? TimeInterval {
            restDuration = rest
        }
    }

    // MARK: - Extended Runtime Session

    private func startExtendedSession() {
        let session = WKExtendedRuntimeSession()
        session.start()
        extendedSession = session
    }

    private func endExtendedSession() {
        extendedSession?.invalidate()
        extendedSession = nil
    }
}
