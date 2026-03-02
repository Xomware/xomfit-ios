import Foundation
import HealthKit

/// Streams real-time heart rate samples from HealthKit for rest-period recovery tracking.
actor HealthKitRestMonitor {
    private let healthStore = HKHealthStore()
    private var query: HKAnchoredObjectQuery?
    private var continuation: AsyncStream<Int>.Continuation?
    
    /// Begins streaming heart rate values (BPM) as they arrive from Apple Watch or other sensors.
    /// Returns an `AsyncStream<Int>` that yields each new HR reading.
    func startMonitoring() -> AsyncStream<Int> {
        // Stop any existing query first
        await stopMonitoring()
        
        return AsyncStream<Int> { continuation in
            self.continuation = continuation
            
            guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
                continuation.finish()
                return
            }
            
            let query = HKAnchoredObjectQuery(
                type: hrType,
                predicate: HKQuery.predicateForSamples(
                    withStart: Date(),
                    end: nil,
                    options: .strictStartDate
                ),
                anchor: nil,
                limit: HKObjectQueryNoLimit
            ) { [weak self] _, samples, _, _, _ in
                self?.processSamples(samples)
            }
            
            query.updateHandler = { [weak self] _, samples, _, _, _ in
                self?.processSamples(samples)
            }
            
            self.query = query
            healthStore.execute(query)
            
            continuation.onTermination = { @Sendable _ in
                Task { [weak self] in
                    await self?.stopMonitoring()
                }
            }
        }
    }
    
    /// Stops the anchored object query and closes the stream.
    func stopMonitoring() {
        if let query = query {
            healthStore.stop(query)
            self.query = nil
        }
        continuation?.finish()
        continuation = nil
    }
    
    private nonisolated func processSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample] else { return }
        let unit = HKUnit(from: "count/min")
        for sample in samples {
            let bpm = Int(sample.quantity.doubleValue(for: unit))
            Task { await self.yieldHeartRate(bpm) }
        }
    }
    
    private func yieldHeartRate(_ bpm: Int) {
        continuation?.yield(bpm)
    }
}
