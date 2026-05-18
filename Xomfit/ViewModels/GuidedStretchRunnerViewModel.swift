import ActivityKit
import Foundation
import SwiftUI

/// Drives the guided stretch sequence runner (#388 / polished in #398).
///
/// Wraps a list of `Stretch`es with:
/// - a per-stretch countdown that keeps ticking past 0 into negative territory
///   so the user can hold longer than the recommended time (#398)
/// - skip / back / pause controls
/// - "finished" state once the user moves past the last stretch
/// - an ActivityKit Live Activity that mirrors the workout one, surfacing the
///   current stretch + countdown in the Dynamic Island / lock screen
///
/// MVVM: this is the only place the timer + Live Activity live. The view binds
/// to `currentIndex` / `secondsRemaining` / `isFinished` for display.
@MainActor
@Observable
final class GuidedStretchRunnerViewModel {
    // MARK: - Inputs

    /// Resolved stretches the runner walks through. Empty arrays short-circuit
    /// straight to `isFinished` so the view can show its end card.
    private(set) var stretches: [Stretch]
    /// Friendly name surfaced on the end screen ("Nice — done with X") and on
    /// the Live Activity.
    let templateName: String

    // MARK: - State

    private(set) var currentIndex: Int = 0
    /// Seconds remaining on the current stretch. Goes negative once the user
    /// holds past the recommended time — the UI flips to red and the user
    /// stays in manual control (no auto-advance) until they tap Skip / Done.
    private(set) var secondsRemaining: Int
    private(set) var isFinished: Bool = false
    /// True while the timer is actively ticking. `pause()` flips it false.
    private(set) var isRunning: Bool = false

    /// Tracks the total time the user actually spent in the runner (for the
    /// "X stretches in Y minutes" end screen). Increments once per tick.
    private(set) var elapsedSeconds: Int = 0

    private var timer: Timer?
    private var liveActivity: Activity<XomfitWidgetAttributes>?

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

    /// 0...1 — fraction of the current hold elapsed. Clamped at 1 once the
    /// countdown hits zero so the ring stays full when the user holds longer
    /// than the recommended time instead of looping back around (#398).
    var stretchProgress: Double {
        guard let stretch = currentStretch, stretch.durationSeconds > 0 else { return 0 }
        let raw = 1 - (Double(secondsRemaining) / Double(stretch.durationSeconds))
        return min(1, max(0, raw))
    }

    /// True once the user is holding past the recommended hold time. Drives
    /// the red "overtime" styling in the runner and Live Activity (#398).
    var isOvertime: Bool {
        secondsRemaining < 0
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
        startLiveActivityIfNeeded()
        updateLiveActivity()
    }

    func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        updateLiveActivity()
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
        updateLiveActivity()
    }

    func finishEarly() {
        pause()
        isFinished = true
        Haptics.success()
        endLiveActivity()
    }

    /// Called by the view when the user dismisses the runner (close / Done on
    /// the end card). Tears the timer and Live Activity down.
    func teardown() {
        pause()
        endLiveActivity()
    }

    #if DEBUG
    /// Forces a single tick of the runner without going through the timer.
    /// Used only by agent screenshot flows to push the countdown into the
    /// overtime state without waiting in real time. Compiles out of Release.
    func debugTickForOvertimeScreenshot() {
        guard !isFinished else { return }
        elapsedSeconds += 1
        secondsRemaining -= 1
        updateLiveActivity()
    }
    #endif

    // MARK: - Editing (#398)

    /// Replace the current session's stretch list. Used by the detail view's
    /// edit mode to apply reorders / deletes before starting. Resets the
    /// position to the first stretch and pauses so the user can hit Play.
    func replaceStretches(_ next: [Stretch]) {
        timer?.invalidate()
        timer = nil
        isRunning = false
        stretches = next
        currentIndex = 0
        secondsRemaining = next.first?.durationSeconds ?? 0
        isFinished = next.isEmpty
        elapsedSeconds = 0
        updateLiveActivity()
    }

    // MARK: - Private

    @MainActor
    private func tick() {
        guard !isFinished else { return }
        elapsedSeconds += 1
        // Per #398: keep counting past zero. The runner does NOT auto-advance
        // — the user controls Skip / Done themselves.
        secondsRemaining -= 1
        // Push a Live Activity update every tick so the Dynamic Island
        // countdown stays in sync. Cheap because the payload is tiny.
        updateLiveActivity()
    }

    private func advance() {
        let next = currentIndex + 1
        if next >= stretches.count {
            isFinished = true
            pause()
            Haptics.success()
            endLiveActivity()
            return
        }
        currentIndex = next
        secondsRemaining = stretches[next].durationSeconds
        Haptics.selection()
        updateLiveActivity()
    }

    // MARK: - Live Activity

    private func startLiveActivityIfNeeded() {
        guard liveActivity == nil else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // End any stale stretch activities to prevent stacking. Workout
        // activities are managed by `WorkoutLoggerViewModel` — we only clean
        // up ones tagged with our stretch mode here.
        for activity in Activity<XomfitWidgetAttributes>.activities where activity.content.state.mode == .stretch {
            let finalState = activity.content.state
            Task {
                await activity.end(.init(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
            }
        }

        let attributes = XomfitWidgetAttributes(
            workoutName: templateName,
            startTime: Date()
        )
        let state = currentLiveState()

        do {
            liveActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            print("[StretchLiveActivity] Failed to start: \(error)")
        }
    }

    private func updateLiveActivity() {
        guard let activity = liveActivity else { return }
        let state = currentLiveState()
        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    private func endLiveActivity() {
        guard let activity = liveActivity else { return }
        let finalState = currentLiveState()
        Task {
            await activity.end(.init(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
        }
        liveActivity = nil
    }

    /// Snapshot of the runner state translated into the shared
    /// `ContentState`. Only the stretch-mode fields carry meaning; workout
    /// fields stay at their defaults.
    private func currentLiveState() -> XomfitWidgetAttributes.ContentState {
        XomfitWidgetAttributes.ContentState(
            elapsedSeconds: elapsedSeconds,
            completedSets: 0,
            totalSets: 0,
            currentExercise: "",
            totalExercises: 0,
            isResting: false,
            restTimeRemaining: 0,
            restEndDate: nil,
            isOvertime: false,
            isPaused: !isRunning,
            mode: .stretch,
            stretchName: currentStretch?.name ?? "",
            stretchSecondsRemaining: secondsRemaining,
            stretchIndex: min(currentIndex + 1, max(totalCount, 1)),
            stretchTotal: totalCount
        )
    }
}
