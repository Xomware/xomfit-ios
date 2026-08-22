import Foundation
import HealthKit

/// Bridges XomFit to Apple Health.
///
/// This is the single integration point for wearable data. Garmin, Whoop, Polar
/// and Zwift all write to Apple Health, so importing from HealthKit covers every
/// one of them; a direct Garmin Connect integration would require an approved
/// partnership and cover strictly less.
///
/// Every method is a no-op returning empty results when HealthKit is
/// unavailable — the iPad and the simulator both lack it — so callers never need
/// to branch on availability.
@MainActor
@Observable
final class HealthKitService {
    static let shared = HealthKitService()

    private let store = HKHealthStore()

    /// Whether HealthKit exists on this device at all.
    nonisolated var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private(set) var isAuthorized: Bool = false
    private(set) var lastImportError: String?

    // MARK: - Today's summary
    //
    // Surfaced on the home and profile screens so the app can show what the
    // user's watch already knows. Zero means "not loaded or no data" rather
    // than a separate optional state — for a daily counter those are the same
    // thing to a reader, and it keeps the call sites free of nil handling.

    private(set) var stepsToday: Double = 0
    private(set) var activeCaloriesToday: Double = 0
    private(set) var restingHR: Double = 0

    private init() {}

    /// Refreshes today's step count, active calories and resting heart rate.
    func refreshTodaySummary() async {
        guard isAvailable else { return }

        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay, end: Date(), options: .strictStartDate
        )

        async let steps = sum(.stepCount, unit: .count(), predicate: predicate)
        async let calories = sum(.activeEnergyBurned, unit: .kilocalorie(), predicate: predicate)
        // Resting HR is published once per day and often lags, so it is read as
        // the most recent value rather than restricted to today — a blank
        // reading every morning would be worse than a slightly stale one.
        async let resting = mostRecent(
            .restingHeartRate, unit: .count().unitDivided(by: .minute())
        )

        stepsToday = await steps ?? 0
        activeCaloriesToday = await calories ?? 0
        restingHR = await resting ?? 0
    }

    private func sum(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        predicate: NSPredicate
    ) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                continuation.resume(returning: statistics?.sumQuantity()?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    private func mostRecent(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit
    ) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: nil,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, _ in
                let sample = (samples as? [HKQuantitySample])?.first
                continuation.resume(returning: sample?.quantity.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    // MARK: - Types

    /// Data XomFit reads. Kept narrow deliberately — asking for permissions the
    /// app does not use is the fastest way to get a permission sheet declined.
    var readTypes: Set<HKObjectType> {
        guard isAvailable else { return [] }
        var types: Set<HKObjectType> = [HKObjectType.workoutType()]
        let quantities: [HKQuantityTypeIdentifier] = [
            .activeEnergyBurned,
            .heartRate,
            .restingHeartRate,
            .distanceWalkingRunning,
            .distanceCycling,
            .stepCount,
            .bodyMass
        ]
        for id in quantities {
            if let type = HKQuantityType.quantityType(forIdentifier: id) {
                types.insert(type)
            }
        }
        return types
    }

    /// Data XomFit writes back, so a lifted session shows up in the Health app
    /// and closes the user's activity rings.
    var writeTypes: Set<HKSampleType> {
        guard isAvailable else { return [] }
        var types: Set<HKSampleType> = [HKObjectType.workoutType()]
        if let energy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(energy)
        }
        if let bodyMass = HKQuantityType.quantityType(forIdentifier: .bodyMass) {
            types.insert(bodyMass)
        }
        return types
    }

    // MARK: - Authorization

    @discardableResult
    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
            // HealthKit deliberately never reveals read permission status, to
            // avoid leaking that a user has no data of a given type. A
            // successful request only means the sheet was handled — actual
            // access is discovered by querying and seeing what comes back.
            isAuthorized = true
            return true
        } catch {
            lastImportError = error.localizedDescription
            return false
        }
    }

    // MARK: - Importing cardio

    /// Cardio sessions recorded by any Health-connected source since a date.
    ///
    /// Sessions XomFit itself wrote are filtered out, so importing does not
    /// duplicate what the user already logged here.
    func importCardioSessions(
        userId: String,
        since startDate: Date,
        limit: Int = 100
    ) async -> [CardioSession] {
        guard isAvailable else { return [] }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate, end: Date(), options: .strictStartDate
        )

        let workouts: [HKWorkout] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: limit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error {
                    Task { @MainActor in self.lastImportError = error.localizedDescription }
                }
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            store.execute(query)
        }

        let ownBundleId = Bundle.main.bundleIdentifier
        return workouts.compactMap { workout in
            guard workout.sourceRevision.source.bundleIdentifier != ownBundleId else { return nil }
            return session(from: workout, userId: userId)
        }
    }

    // MARK: - Automatic import
    //
    // The manual "Import from Health" button walks a 30-day date window every
    // time it is tapped. That is fine for a button and wrong for anything
    // automatic: a window re-reads the same samples on every run and silently
    // hides anything older than the window. The automatic path uses an
    // `HKQueryAnchor` instead, which is HealthKit's own "what have I not seen
    // yet" cursor and is the only thing that makes repeated imports idempotent.

    /// Cap on how far back the *first* automatic import reaches.
    ///
    /// With no stored anchor an anchored query returns a lifter's entire Health
    /// history, which for a long-time Garmin user is thousands of workouts on
    /// first launch. A year is enough to make the feature obviously work without
    /// that. Subsequent runs are anchored and unbounded.
    private static let firstImportWindow: TimeInterval = 365 * 24 * 60 * 60

    private static let anchorKey = "health.cardioImportAnchor"

    private var storedAnchor: HKQueryAnchor? {
        guard let data = UserDefaults.standard.data(forKey: Self.anchorKey) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
    }

    /// Advances the cursor. Called **only** after every session in the batch has
    /// been persisted — advancing on fetch instead would drop samples for good
    /// the moment a save failed.
    func commitCardioAnchor(_ anchor: HKQueryAnchor) {
        guard let data = try? NSKeyedArchiver.archivedData(
            withRootObject: anchor, requiringSecureCoding: true
        ) else { return }
        UserDefaults.standard.set(data, forKey: Self.anchorKey)
    }

    /// Clears the cursor so the next automatic import re-reads the full window.
    func resetCardioAnchor() {
        UserDefaults.standard.removeObject(forKey: Self.anchorKey)
    }

    /// Cardio sessions HealthKit has not handed us before.
    ///
    /// Returns the new anchor alongside the sessions rather than storing it, so
    /// the caller can persist it only once the sessions are safely saved.
    func newCardioSessions(
        userId: String
    ) async -> (sessions: [CardioSession], anchor: HKQueryAnchor?) {
        guard isAvailable else { return ([], nil) }

        let anchor = storedAnchor
        // The date predicate applies to the first run only. Once anchored,
        // bounding by date would re-introduce exactly the blind spot the anchor
        // exists to remove.
        let predicate: NSPredicate? = anchor == nil
            ? HKQuery.predicateForSamples(
                withStart: Date().addingTimeInterval(-Self.firstImportWindow),
                end: nil,
                options: .strictStartDate
              )
            : nil

        let result: ([HKWorkout], HKQueryAnchor?) = await withCheckedContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: HKObjectType.workoutType(),
                predicate: predicate,
                anchor: anchor,
                limit: HKObjectQueryNoLimit
            ) { _, samples, _, newAnchor, error in
                if let error {
                    Task { @MainActor in self.lastImportError = error.localizedDescription }
                    // No anchor on failure — a partial read must not advance the
                    // cursor past samples we never saw.
                    continuation.resume(returning: ([], nil))
                    return
                }
                continuation.resume(returning: ((samples as? [HKWorkout]) ?? [], newAnchor))
            }
            store.execute(query)
        }

        let ownBundleId = Bundle.main.bundleIdentifier
        let sessions = result.0.compactMap { workout -> CardioSession? in
            guard workout.sourceRevision.source.bundleIdentifier != ownBundleId else { return nil }
            return session(from: workout, userId: userId)
        }
        return (sessions, result.1)
    }

    private func session(from workout: HKWorkout, userId: String) -> CardioSession? {
        let isIndoor = (workout.metadata?[HKMetadataKeyIndoorWorkout] as? Bool) ?? false
        guard let modality = CardioModality.from(
            healthKitType: workout.workoutActivityType,
            isIndoor: isIndoor
        ) else {
            // Strength training and everything else Health knows about is not
            // cardio; skipping is correct, not a failure.
            return nil
        }

        let distanceType: HKQuantityTypeIdentifier =
            modality.healthKitType == .cycling ? .distanceCycling : .distanceWalkingRunning

        let distance = workout.statistics(
            for: HKQuantityType.quantityType(forIdentifier: distanceType)!
        )?.sumQuantity()?.doubleValue(for: .mile())

        let calories = workout.statistics(
            for: HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        )?.sumQuantity()?.doubleValue(for: .kilocalorie())

        let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
        let heartRateStats = workout.statistics(
            for: HKQuantityType.quantityType(forIdentifier: .heartRate)!
        )

        return CardioSession(
            id: UUID().uuidString,
            userId: userId,
            modality: modality,
            startTime: workout.startDate,
            endTime: workout.endDate,
            durationSeconds: workout.duration,
            distanceMiles: modality.tracksDistance ? distance : nil,
            activeCalories: calories,
            averageHeartRate: heartRateStats?.averageQuantity()?.doubleValue(for: heartRateUnit),
            maxHeartRate: heartRateStats?.maximumQuantity()?.doubleValue(for: heartRateUnit),
            elevationGainFeet: elevationGain(from: workout),
            notes: nil,
            healthKitUUID: workout.uuid.uuidString,
            sourceName: workout.sourceRevision.source.name
        )
    }

    private func elevationGain(from workout: HKWorkout) -> Double? {
        // Reported in meters by every source that reports it at all.
        guard let quantity = workout.metadata?[HKMetadataKeyElevationAscended] as? HKQuantity else {
            return nil
        }
        return quantity.doubleValue(for: .foot())
    }

    // MARK: - Exporting

    /// Writes a completed strength session to Health so it counts toward the
    /// user's rings and shows up alongside their other training.
    @discardableResult
    func exportStrengthWorkout(
        start: Date,
        end: Date,
        activeCalories: Double?
    ) async -> Bool {
        guard isAvailable, end > start else { return false }

        let builder = HKWorkoutBuilder(
            healthStore: store,
            configuration: {
                let config = HKWorkoutConfiguration()
                config.activityType = .traditionalStrengthTraining
                return config
            }(),
            device: .local()
        )

        do {
            try await builder.beginCollection(at: start)

            if let activeCalories, activeCalories > 0,
               let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
                let sample = HKQuantitySample(
                    type: energyType,
                    quantity: HKQuantity(unit: .kilocalorie(), doubleValue: activeCalories),
                    start: start,
                    end: end
                )
                try await builder.addSamples([sample])
            }

            try await builder.endCollection(at: end)
            _ = try await builder.finishWorkout()
            return true
        } catch {
            lastImportError = error.localizedDescription
            return false
        }
    }

    // MARK: - Bodyweight

    /// Most recent bodyweight from Health, in pounds.
    ///
    /// Lets strength ranks work for someone who weighs in on a smart scale but
    /// has never logged a measurement in XomFit.
    func latestBodyweightLbs() async -> Double? {
        guard isAvailable,
              let type = HKQuantityType.quantityType(forIdentifier: .bodyMass)
        else { return nil }

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: nil,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, _ in
                let sample = (samples as? [HKQuantitySample])?.first
                continuation.resume(returning: sample?.quantity.doubleValue(for: .pound()))
            }
            store.execute(query)
        }
    }
}
