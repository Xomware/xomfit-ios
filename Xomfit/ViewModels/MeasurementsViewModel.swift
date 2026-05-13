import Foundation

// MARK: - MeasurementsViewModel (#317)

@MainActor
@Observable
final class MeasurementsViewModel {
    // MARK: - State

    var measurements: [BodyMeasurement] = []
    var isLoading: Bool = false
    var errorMessage: String?

    /// Set during load so writes can be attributed to the right user.
    private(set) var userId: String = ""

    // MARK: - Derived

    /// Measurements grouped by kind, each list newest-first (matches `fetchAll`).
    var byKind: [MeasurementKind: [BodyMeasurement]] {
        var result: [MeasurementKind: [BodyMeasurement]] = [:]
        for measurement in measurements {
            result[measurement.kind, default: []].append(measurement)
        }
        // Already newest-first from the service, but defensively re-sort to keep the
        // grouping stable if a callsite ever appends in another order.
        for (kind, list) in result {
            result[kind] = list.sorted { $0.recordedAt > $1.recordedAt }
        }
        return result
    }

    // MARK: - Loading

    func loadAll(userId: String) async {
        self.userId = userId
        isLoading = true
        errorMessage = nil
        measurements = await MeasurementsService.shared.fetchAll(userId: userId)
        isLoading = false
    }

    // MARK: - Mutations

    /// Add a new measurement. Optimistically prepends on success; surfaces an
    /// error if the insert fails so the UI can show feedback.
    func add(
        kind: MeasurementKind,
        value: Double,
        recordedAt: Date = Date(),
        notes: String? = nil
    ) async {
        guard !userId.isEmpty else {
            errorMessage = "Sign in required to log measurements."
            return
        }

        let measurement = BodyMeasurement(
            userId: userId,
            kind: kind,
            value: value,
            recordedAt: recordedAt,
            notes: notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )

        if let saved = await MeasurementsService.shared.insert(measurement) {
            measurements.insert(saved, at: 0)
        } else {
            errorMessage = "Couldn't save measurement. Try again."
        }
    }

    /// Remove a measurement. Optimistically drops it from local state on success.
    func remove(_ measurement: BodyMeasurement) async {
        let success = await MeasurementsService.shared.delete(id: measurement.id, userId: measurement.userId)
        if success {
            measurements.removeAll { $0.id == measurement.id }
        } else {
            errorMessage = "Couldn't delete measurement."
        }
    }

    // MARK: - Convenience accessors

    /// Most recent measurement for the given kind, or nil.
    func latest(of kind: MeasurementKind) -> BodyMeasurement? {
        byKind[kind]?.first
    }

    /// Change in value over the last `days` days for `kind`. nil when fewer than two
    /// data points exist within the window or no prior data is available.
    func delta(for kind: MeasurementKind, days: Int = 30) -> Double? {
        let series = byKind[kind] ?? []
        guard let latest = series.first else { return nil }

        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? .distantPast
        // Pick the oldest point at or after the cutoff (so a 30-day delta uses the
        // first reading inside the window, not the latest one).
        let baseline = series
            .dropFirst() // exclude latest
            .filter { $0.recordedAt >= cutoff }
            .last
            ?? series.dropFirst().first

        guard let baseline else { return nil }
        return latest.value - baseline.value
    }
}

// MARK: - String helper

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
