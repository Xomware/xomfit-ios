//
//  WatchWorkoutSessionManager.swift
//  XomfitWatch
//
//  Runs an HKWorkoutSession for the duration of a lifting session.
//

import Foundation
import HealthKit

/// Owns the `HKWorkoutSession` that keeps the watch app alive during a workout.
///
/// Without a running workout session, watchOS suspends the app as soon as the
/// wrist drops — the timer stops advancing, `WCSession` messages queue up
/// instead of arriving, and heart rate is never sampled. A workout session is
/// what buys background execution and live heart rate, and it is the difference
/// between an app that mirrors the phone and one that is actually usable in a
/// gym.
///
/// Failures here are deliberately non-fatal: the watch app still mirrors the
/// phone without an active session, it just goes to sleep more eagerly. Refusing
/// to show anything because HealthKit declined would be a worse experience than
/// a slightly sleepy one.
@MainActor
@Observable
final class WatchWorkoutSessionManager: NSObject {

    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    private(set) var isRunning = false
    private(set) var heartRate: Double = 0
    private(set) var activeCalories: Double = 0
    private(set) var lastError: String?

    /// Types the watch needs while a session is live.
    private var typesToShare: Set<HKSampleType> {
        var types: Set<HKSampleType> = [HKObjectType.workoutType()]
        if let energy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(energy)
        }
        return types
    }

    private var typesToRead: Set<HKObjectType> {
        var types: Set<HKObjectType> = [HKObjectType.workoutType()]
        for id in [HKQuantityTypeIdentifier.heartRate, .activeEnergyBurned] {
            if let type = HKQuantityType.quantityType(forIdentifier: id) {
                types.insert(type)
            }
        }
        return types
    }

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        do {
            try await store.requestAuthorization(toShare: typesToShare, read: typesToRead)
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Starts a strength-training session. Safe to call when one is already
    /// running — the phone re-sends its state on reconnect, and starting a
    /// second session would end up with two builders writing overlapping
    /// workouts to Health.
    func start() {
        guard HKHealthStore.isHealthDataAvailable(), !isRunning else { return }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor

        do {
            let session = try HKWorkoutSession(healthStore: store, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(
                healthStore: store,
                workoutConfiguration: configuration
            )

            session.delegate = self
            builder.delegate = self

            let start = Date()
            session.startActivity(with: start)
            builder.beginCollection(withStart: start) { _, error in
                guard let message = error?.localizedDescription else { return }
                Task { @MainActor in self.lastError = message }
            }

            self.session = session
            self.builder = builder
            isRunning = true
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Ends the session and saves the workout to Health.
    func stop() {
        guard let session, let builder, isRunning else { return }

        let end = Date()
        session.end()
        builder.endCollection(withEnd: end) { _, _ in
            builder.finishWorkout { _, error in
                // `self` is captured strongly and the message is extracted
                // before hopping actors: capturing it weakly here made `self` a
                // mutable optional inside a concurrently-executing closure,
                // which is an error under the Swift 6 language mode. The manager
                // lives for the app's lifetime, so a strong capture cannot leak.
                let message = error?.localizedDescription
                Task { @MainActor in
                    if let message { self.lastError = message }
                    self.reset()
                }
            }
        }
    }

    private func reset() {
        session = nil
        builder = nil
        isRunning = false
        heartRate = 0
        activeCalories = 0
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WatchWorkoutSessionManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Task { @MainActor in
            // Only `.running` counts as live. `.paused` and `.prepared` both
            // still hold the background-execution assertion, but reporting them
            // as running would make the UI claim it is recording when it is not.
            isRunning = (toState == .running)
            if toState == .ended { reset() }
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        Task { @MainActor in
            lastError = error.localizedDescription
            reset()
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WatchWorkoutSessionManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        // Statistics are read here rather than polled, because the builder only
        // guarantees a value is present once it has told us it collected one.
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)
        let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)

        let bpm = heartRateType.flatMap { workoutBuilder.statistics(for: $0) }?
            .mostRecentQuantity()?
            .doubleValue(for: HKUnit.count().unitDivided(by: .minute()))

        let kcal = energyType.flatMap { workoutBuilder.statistics(for: $0) }?
            .sumQuantity()?
            .doubleValue(for: .kilocalorie())

        Task { @MainActor in
            if let bpm { heartRate = bpm }
            if let kcal { activeCalories = kcal }
        }
    }
}
