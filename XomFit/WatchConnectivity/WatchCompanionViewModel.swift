import Foundation
import Combine

/// Bridges WorkoutLoggerViewModel ↔ PhoneConnectivityManager for Watch sync.
@MainActor
class WatchCompanionViewModel: ObservableObject {
    @Published var isWatchConnected = false
    @Published var setsLoggedFromWatch: Int = 0

    private let connectivity = PhoneConnectivityManager.shared
    private var cancellables = Set<AnyCancellable>()
    private weak var workoutLogger: WorkoutLoggerViewModel?

    init(workoutLogger: WorkoutLoggerViewModel? = nil) {
        self.workoutLogger = workoutLogger
        setupBindings()
    }

    private func setupBindings() {
        // Track watch reachability
        connectivity.$isWatchReachable
            .assign(to: &$isWatchConnected)

        // Handle sets received from Watch
        connectivity.onSetReceived = { [weak self] setData in
            Task { @MainActor in
                self?.handleWatchSet(setData)
            }
        }
    }

    // MARK: - Send Context to Watch

    func syncCurrentExercise(name: String, setNumber: Int, totalSets: Int, restDuration: Int) {
        connectivity.sendWorkoutContext(
            exercise: name,
            setNumber: setNumber,
            totalSets: totalSets,
            restDuration: restDuration
        )
    }

    func notifyWorkoutStarted(name: String) {
        connectivity.sendWorkoutStarted(workoutName: name)
    }

    // MARK: - Handle Watch Input

    private func handleWatchSet(_ data: [String: Any]) {
        setsLoggedFromWatch += 1

        guard let weight = data["weight"] as? Double,
              let reps = data["reps"] as? Int else { return }

        // Bridge to workout logger
        workoutLogger?.inputWeight = "\(Int(weight))"
        workoutLogger?.inputReps = "\(reps)"
        // Caller can trigger workoutLogger.logSet() if desired
    }
}
