//
//  ContentView.swift
//  XomfitWatch
//
//  Root watch UI. Renders the latest `WatchWorkoutState` from
//  `WatchSessionStore` and exposes a "Done Set" button that pings the iPhone.
//
//  Layout (top -> bottom):
//   - workout name + elapsed timer
//   - "Set N / M" label
//   - rest countdown ring  OR  "Paused" pill  OR  current exercise name
//   - "Done Set" button
//

import SwiftUI

struct ContentView: View {
    @Environment(WatchSessionStore.self) private var sessionStore

    /// Local haptic driver. Held here rather than in `WorkoutScreen` so it
    /// survives the view being rebuilt on every state push — a haptic engine
    /// that forgets which second it last fired for would buzz on every redraw.
    @State private var haptics = WatchRestHaptics()

    /// Created once, not in `body`.
    ///
    /// This was inline in the view body and the haptics never fired once.
    /// `body` re-evaluates on every state push from the phone, and an inline
    /// `Timer.publish(...).autoconnect()` builds a *new* publisher each time,
    /// tearing down the previous one before it reaches its first tick. A
    /// half-second timer rebuilt more often than every half second never fires
    /// at all.
    private let tick = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if let state = sessionStore.state {
                // Three pages, matching the Garmin app. `.page` rather than a
                // navigation stack: swiping between fixed screens is one
                // gesture, and a back stack between a lifter mid-set and the
                // rest countdown is the wrong shape.
                TabView {
                    WorkoutScreen(state: state) {
                        sessionStore.sendDoneSet()
                    }
                    UpNextScreen(state: state)
                    HowToScreen(state: state)
                }
                .tabViewStyle(.verticalPage)
                // Drives itself from the absolute rest end date rather than
                // waiting on a message per second — the buzz must be exact at
                // the one moment it fires, and Bluetooth is not.
                .onReceive(tick) { _ in
                    // Read through the store rather than the captured `state`,
                    // so the closure always sees the current snapshot instead of
                    // whichever one existed when this body ran.
                    guard let current = sessionStore.state else {
                        haptics.reset()
                        return
                    }
                    haptics.update(
                        restEndDate: current.isResting ? current.restEndDate : nil,
                        isPaused: current.isPaused,
                        enabled: current.wristHaptics
                    )
                }
            } else {
                EmptyWatchState()
                    .onAppear { haptics.reset() }
            }
        }
    }
}

// MARK: - Up next

/// The exercises still to come. Glanced at during rest.
private struct UpNextScreen: View {
    let state: WatchWorkoutState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("UP NEXT")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if state.upNext.isEmpty {
                Text("Last exercise")
                    .font(.body)
                    .foregroundStyle(.secondary)
            } else {
                // The immediate next lift is the one being asked about, so it is
                // the only one at full contrast.
                ForEach(Array(state.upNext.prefix(4).enumerated()), id: \.offset) { index, name in
                    Text(name)
                        .font(index == 0 ? .body : .caption)
                        .foregroundStyle(index == 0 ? .primary : .secondary)
                        .lineLimit(1)
                }
                if state.upNext.count > 4 {
                    Text("+\(state.upNext.count - 4) more")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
    }
}

// MARK: - How to

/// Form cues for the current lift.
///
/// Short phrases from the exercise's own tips, not sentences. A watch screen
/// cannot hold a sentence and a lifter mid-set will not read one.
private struct HowToScreen: View {
    let state: WatchWorkoutState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HOW TO")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if state.tips.isEmpty {
                Text("No cues for this lift")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(state.tips.enumerated()), id: \.offset) { _, tip in
                    HStack(alignment: .top, spacing: 6) {
                        Text("\u{2022}")
                            .foregroundStyle(.green)
                        Text(tip)
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
    }
}

// MARK: - Active workout screen

private struct WorkoutScreen: View {
    let state: WatchWorkoutState
    let onDoneSet: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            header
            setLabel
            targetLabel
            middleSection
            Spacer(minLength: 0)
            doneButton
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }

    /// Planned weight x reps. Absent when the phone has not said — a target of
    /// "0 x 0" reads as a bug rather than a blank.
    @ViewBuilder
    private var targetLabel: some View {
        if state.reps != nil || state.weight != nil {
            Text(targetText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var targetText: String {
        let weight = state.weight.map { $0 == $0.rounded() ? String(Int($0)) : String(format: "%.1f", $0) }
        switch (weight, state.reps) {
        case let (w?, r?): return "\(w) × \(r)"
        case let (w?, nil): return "\(w) lb"
        case let (nil, r?): return "\(r) reps"
        default: return ""
        }
    }

    private var header: some View {
        VStack(spacing: 2) {
            Text(state.workoutName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(formatElapsed(state.elapsedSeconds))
                .font(.system(.title3, design: .rounded).monospacedDigit())
                .foregroundStyle(.primary)
        }
        .accessibilityElement(children: .combine)
    }

    private var setLabel: some View {
        Text("Set \(state.setNumber) / \(max(state.totalSets, state.setNumber))")
            .font(.system(.title2, design: .rounded).weight(.bold))
            .foregroundStyle(.primary)
            .accessibilityLabel("Set \(state.setNumber) of \(max(state.totalSets, state.setNumber))")
    }

    @ViewBuilder
    private var middleSection: some View {
        if state.isPaused {
            PausedPill()
        } else if state.isResting, let endDate = state.restEndDate {
            RestRing(endDate: endDate)
        } else {
            Text(state.currentExercise)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)
        }
    }

    private var doneButton: some View {
        Button(action: onDoneSet) {
            Text("Done Set")
                .font(.system(.body, design: .rounded).weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.green)
        .accessibilityHint("Marks the current set as complete on your iPhone.")
    }

    private func formatElapsed(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        let h = m / 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m % 60, s)
        }
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Rest countdown ring

private struct RestRing: View {
    /// When the rest interval will end (sent from iOS).
    let endDate: Date

    var body: some View {
        // SwiftUI's TimelineView keeps the watch UI ticking without us managing
        // a Timer. The ring fills as time runs out and turns red on overtime.
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let now = context.date
            let remaining = endDate.timeIntervalSince(now)
            let overtime = remaining <= 0

            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.25), lineWidth: 6)

                Circle()
                    .trim(from: 0, to: progress(remaining: remaining))
                    .stroke(
                        overtime ? Color.red : Color.green,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.5), value: remaining)

                Text(formatRemaining(remaining))
                    .font(.system(.title3, design: .rounded).monospacedDigit().weight(.bold))
                    .foregroundStyle(overtime ? .red : .primary)
            }
            .frame(width: 80, height: 80)
            .accessibilityLabel(overtime ? "Rest overtime" : "Rest remaining \(formatRemaining(remaining))")
        }
    }

    private func progress(remaining: TimeInterval) -> CGFloat {
        // We don't know the original duration here, so approximate fill from a
        // soft-cap of 180s. Watch UI doesn't need pixel-perfect accuracy — the
        // ring is a cue, the number is the truth.
        let cap: TimeInterval = 180
        let clamped = max(0, min(remaining, cap))
        return CGFloat(clamped / cap)
    }

    private func formatRemaining(_ remaining: TimeInterval) -> String {
        let absSec = Int(abs(remaining.rounded()))
        let m = absSec / 60
        let s = absSec % 60
        let prefix = remaining < 0 ? "+" : ""
        return String(format: "%@%d:%02d", prefix, m, s)
    }
}

// MARK: - Paused pill

private struct PausedPill: View {
    var body: some View {
        Text("Paused")
            .font(.system(.callout, design: .rounded).weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.orange, in: .capsule)
            .accessibilityLabel("Workout paused")
    }
}

// MARK: - Empty state

private struct EmptyWatchState: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "iphone.gen3")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Start a workout on your iPhone")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
