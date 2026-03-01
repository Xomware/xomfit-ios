import Foundation
import Combine

// MARK: - Supporting Types

enum TimerMode: String {
    case countdown   // Pure countdown timer
    case hrWaiting   // Waiting for HR to drop below recovery threshold
}

enum RestExerciseType: Equatable {
    case compound              // Squats, deadlifts, bench — 3 min
    case isolation             // Curls, extensions — 1.5 min
    case cardio                // Circuits, HIIT — 1 min
    case custom(TimeInterval)  // User-specified
    
    var defaultDuration: TimeInterval {
        switch self {
        case .compound: return 180
        case .isolation: return 90
        case .cardio: return 60
        case .custom(let t): return t
        }
    }
    
    /// Maps from the existing ExerciseCategory model type.
    static func from(category: String) -> RestExerciseType {
        switch category.lowercased() {
        case "compound": return .compound
        case "isolation": return .isolation
        case "cardio": return .cardio
        default: return .compound
        }
    }
}

// MARK: - ViewModel

@MainActor
final class SmartRestTimerViewModel: ObservableObject {
    // MARK: Configuration
    @Published var defaultRestDuration: TimeInterval = 180
    @Published var recoveryThresholdPercent: Double = 0.65
    @Published var userMaxHR: Int = 190
    @Published var smartTimerEnabled: Bool = true
    
    // MARK: State
    @Published var secondsRemaining: Int = 180
    @Published var currentHR: Int? = nil
    @Published var isReady: Bool = false
    @Published var isRunning: Bool = false
    @Published var mode: TimerMode = .countdown
    @Published var peakHR: Int? = nil
    
    // MARK: Private
    private var timer: Timer?
    private var hrMonitor: HealthKitRestMonitor?
    private var hrTask: Task<Void, Never>?
    private var totalDuration: TimeInterval = 180
    
    // MARK: Computed
    
    /// BPM threshold below which the user is considered "recovered".
    var recoveryThresholdBPM: Int {
        Int(Double(userMaxHR) * recoveryThresholdPercent)
    }
    
    /// 0.0 → 1.0 progress toward recovery. 1.0 = fully recovered (HR at or below threshold).
    var readinessProgress: Double {
        guard let current = currentHR, let peak = peakHR else { return 0.0 }
        let threshold = recoveryThresholdBPM
        guard peak > threshold else { return 1.0 }
        let descent = Double(peak - current)
        let totalNeeded = Double(peak - threshold)
        return min(max(descent / totalNeeded, 0.0), 1.0)
    }
    
    /// 0.0 → 1.0 countdown progress (1.0 = full time remaining).
    var countdownProgress: Double {
        guard totalDuration > 0 else { return 0 }
        return Double(secondsRemaining) / totalDuration
    }
    
    /// Formatted MM:SS string.
    var formattedTime: String {
        let m = secondsRemaining / 60
        let s = secondsRemaining % 60
        return String(format: "%d:%02d", m, s)
    }
    
    // MARK: - Actions
    
    func start(duration: TimeInterval? = nil, exerciseType: RestExerciseType = .compound) {
        let dur = duration ?? exerciseType.defaultDuration
        totalDuration = dur
        secondsRemaining = Int(dur)
        isRunning = true
        isReady = false
        currentHR = nil
        peakHR = nil
        mode = .countdown
        
        startCountdown()
        
        if smartTimerEnabled {
            startHRMonitoring()
        }
    }
    
    func skip() {
        stop()
    }
    
    func addTime(_ seconds: Int) {
        secondsRemaining = max(0, secondsRemaining + seconds)
        totalDuration = max(totalDuration, Double(secondsRemaining))
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
        hrTask?.cancel()
        hrTask = nil
        isRunning = false
        
        Task {
            await hrMonitor?.stopMonitoring()
            hrMonitor = nil
        }
    }
    
    // MARK: - Private
    
    private func startCountdown() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                if self.secondsRemaining > 0 {
                    self.secondsRemaining -= 1
                }
                if self.secondsRemaining <= 0 && self.mode == .countdown {
                    if self.smartTimerEnabled && self.currentHR != nil && !self.isReady {
                        // Countdown finished but HR still high → switch to HR waiting
                        self.mode = .hrWaiting
                    } else {
                        // Done
                        self.isReady = true
                    }
                }
            }
        }
    }
    
    private func startHRMonitoring() {
        let monitor = HealthKitRestMonitor()
        self.hrMonitor = monitor
        
        hrTask = Task {
            let stream = await monitor.startMonitoring()
            for await bpm in stream {
                guard !Task.isCancelled else { break }
                self.currentHR = bpm
                
                // Track peak HR during rest
                if let peak = self.peakHR {
                    self.peakHR = max(peak, bpm)
                } else {
                    self.peakHR = bpm
                }
                
                // Check recovery
                if bpm <= self.recoveryThresholdBPM {
                    self.isReady = true
                }
            }
        }
    }
}
