import Foundation
import SwiftUI

/// Drives the guided stretch sequence runner (#388).
///
/// Wraps a list of `Stretch`es with:
/// - a per-stretch countdown that auto-advances on hitting 0
/// - skip / back controls
/// - "finished" state once the last stretch wraps up
///
/// MVVM: this is the only place the timer lives. The view binds to
/// `currentIndex` / `secondsRemaining` / `isFinished` for display.
@MainActor
@Observable
final class GuidedStretchRunnerViewModel {
    // MARK: - Inputs

    /// Resolved stretches the runner walks through. Empty arrays short-circuit
    /// straight to `isFinished` so the view can show its end card.
    let stretches: [Stretch]
    /// Friendly name surfaced on the end screen ("Nice — done with X").
    let templateName: String

    // MARK: - State

    private(set) var currentIndex: Int = 0
    private(set) var secondsRemaining: Int
    private(set) var isFinished: Bool = false
    /// True while the timer is actively ticking. `pause()` flips it false.
    private(set) var isRunning: Bool = false

    /// Tracks the total time the user actually spent in the runner (for the
    /// "X stretches in Y minutes" end screen). Increments once per tick.
    private(set) var elapsedSeconds: Int = 0

    private var timer: Timer?

    // MARK: - Init

    init(stretches: [Stretch], templateName: String) {
        self.stretches = stretches
        self.templateName = templateName
        self.secondsRemaining = stretches.first?.durationSeconds ?? 0
        if stretches.isEmpty {
            self.isFinished = true
        }
    }

    // The timer is invalidated explicitly in `pause()` / `finishEarly()` and
    // when the view calls `.pause()` on disappear. We don't touch it from
    // `deinit` because the `@MainActor`-isolated `timer` property can't be
    // referenced from a nonisolated context (Swift 6 strict concurrency).
    // The `Timer` retain cycle is broken by `[weak self]` in the scheduled
    // closure, so leaving an idle invalidated timer object is safe.

    // MARK: - Derived

    var currentStretch: Stretch? {
        guard !stretches.isEmpty, currentIndex < stretches.count else { return nil }
        return stretches[currentIndex]
    }

    var totalCount: Int { stretches.count }

    /// 0...1 — fraction of the current hold elapsed. Used to drive the ring.
    var stretchProgress: Double {
        guard let stretch = currentStretch, stretch.durationSeconds > 0 else { return 0 }
        return 1 - (Double(secondsRemaining) / Double(stretch.durationSeconds))
    }

    /// 0...1 — fraction of the sequence completed (by stretch count). Used by
    /// the top progress bar.
    var overallProgress: Double {
        guard totalCount > 0 else { return 0 }
        return min(1, Double(currentIndex) / Double(totalCount))
    }

    /// "X min Y sec" string of the time spent in the runner so far.
    var elapsedSummary: String {
        let mins = elapsedSeconds / 60
        let secs = elapsedSeconds % 60
        if mins == 0 { return "\(secs) sec" }
        if secs == 0 { return "\(mins) min" }
        return "\(mins) min \(secs) sec"
    }

    // MARK: - Controls

    func start() {
        guard !isFinished, !isRunning else { return }
        isRunning = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    func togglePause() {
        if isRunning {
            pause()
            Haptics.light()
        } else if !isFinished {
            start()
            Haptics.light()
        }
    }

    func skipForward() {
        Haptics.light()
        advance()
    }

    func skipBack() {
        Haptics.light()
        let previous = max(currentIndex - 1, 0)
        currentIndex = previous
        if let s = currentStretch {
            secondsRemaining = s.durationSeconds
        }
        // Stepping back from the end screen re-enters the running state.
        if isFinished {
            isFinished = false
            start()
        }
    }

    func finishEarly() {
        pause()
        isFinished = true
        Haptics.success()
    }

    // MARK: - Private

    @MainActor
    private func tick() {
        guard !isFinished else { return }
        elapsedSeconds += 1
        if secondsRemaining > 0 {
            secondsRemaining -= 1
        }
        if secondsRemaining <= 0 {
            advance()
        }
    }

    private func advance() {
        let next = currentIndex + 1
        if next >= stretches.count {
            isFinished = true
            pause()
            Haptics.success()
            return
        }
        currentIndex = next
        secondsRemaining = stretches[next].durationSeconds
        Haptics.selection()
    }
}
