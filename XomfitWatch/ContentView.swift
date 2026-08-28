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
                    WorkoutScreen(
                        state: state,
                        onDoneSet: { sessionStore.sendDoneSet() },
                        onLogSet: { sessionStore.sendLogSet(weight: $0, reps: $1) },
                        onAdjust: { sessionStore.sendAdjustSet(weight: $0, reps: $1) },
                        onLift: { sessionStore.sendSkipRest() },
                        onExtendRest: { sessionStore.sendExtendRest() }
                    )
                    PlanScreen(
                        state: state,
                        onJump: { sessionStore.sendJumpToExercise(index: $0) },
                        onNextExercise: { sessionStore.sendNextExercise() },
                        onTogglePause: { sessionStore.sendTogglePause() }
                    )
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

/// The whole session: every exercise, how much of it is done, and a tap to
/// work on any of it.
///
/// Replaces a flat list of the names still to come. That list answered "what is
/// next" and nothing else — not how far through the session the lifter was, and
/// not letting them go back to an exercise they skipped.
private struct PlanScreen: View {
    let state: WatchWorkoutState
    let onJump: (Int) -> Void
    let onNextExercise: () -> Void
    let onTogglePause: () -> Void

    var body: some View {
        List {
            if state.plan.isEmpty {
                // An older phone build sends no plan. Fall back rather than
                // showing an empty screen: the two ship independently and
                // routinely disagree about which fields exist. The actions
                // below stay either way — they do not depend on the plan.
                legacyUpNext
            } else {
                Section {
                    ForEach(Array(state.plan.enumerated()), id: \.offset) { index, row in
                        Button {
                            onJump(index)
                        } label: {
                            PlanRowLabel(row: row, isCurrent: index == state.currentIndex)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text(summary)
                        .font(.caption2)
                }
            }

                // Below the plan rather than on the workout screen: these need
                // reading before pressing, and the main screen is read at arm's
                // length mid-set.
                Section {
                    Button(action: onNextExercise) {
                        Label("Next Exercise", systemImage: "forward.end")
                            .font(.caption)
                    }
                    Button(action: onTogglePause) {
                        Label(
                            state.isPaused ? "Resume" : "Pause",
                            systemImage: state.isPaused ? "play.fill" : "pause.fill"
                        )
                        .font(.caption)
                    }
                }
        }
    }

    @ViewBuilder
    private var legacyUpNext: some View {
        if state.upNext.isEmpty {
            Section {
                Text("Last exercise")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            Section("Up next") {
                ForEach(state.upNext, id: \.self) { name in
                    Text(name)
                        .font(.caption)
                        .lineLimit(1)
                }
            }
        }
    }

    /// Sets done across the whole session. The headline answer before any
    /// per-exercise detail.
    private var summary: String {
        let done = state.plan.reduce(0) { $0 + $1.done }
        let total = state.plan.reduce(0) { $0 + $1.total }
        return "\(done) of \(total) sets"
    }
}

private struct PlanRowLabel: View {
    let row: WatchWorkoutState.PlanRow
    let isCurrent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text(row.name)
                    .font(.caption)
                    .foregroundStyle(isCurrent ? .primary : .secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("\(row.done)/\(row.total)")
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            // A filled proportion answers "how much is left" without being
            // read, which is what a screen glanced at between sets needs.
            ProgressView(value: row.fraction)
                .tint(isCurrent ? .green : .gray)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(row.name), \(row.done) of \(row.total) sets"
                + (isCurrent ? ", current exercise" : "")
        )
        .accessibilityHint("Tap to work on this exercise.")
    }
}

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
    let onLogSet: (Int, Int) -> Void
    let onAdjust: (Int?, Int?) -> Void
    let onLift: () -> Void
    let onExtendRest: () -> Void

    @State private var editing: EditingField?

    /// Which number the crown sheet is editing, if any.
    private enum EditingField: Identifiable {
        case weight, reps
        var id: Int { self == .weight ? 0 : 1 }
    }

    /// Resting or about to lift.
    ///
    /// Every element on the screen means something different depending on
    /// which, and drawing both at once is how the Garmin app ended up with a
    /// button that said "Log Set" all the way through the rest countdown.
    private var isResting: Bool {
        state.isResting && !state.isPaused
    }

    var body: some View {
        VStack(spacing: 6) {
            header
            setLabel

            if isResting {
                middleSection
            } else {
                entryFields
            }

            Spacer(minLength: 0)

            if isResting {
                // Needing longer is at least as common as being ready early,
                // and the watch had no way to say so at all.
                HStack(spacing: 6) {
                    Button(action: onExtendRest) {
                        Text("+30s")
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityHint("Adds thirty seconds to the rest timer.")

                    primaryButton
                }
            } else {
                primaryButton
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .sheet(item: $editing) { field in
            switch field {
            case .weight:
                NumberEntryView(
                    title: "WEIGHT",
                    initial: Int(state.weight ?? 45),
                    step: 5,
                    range: 0...995
                ) { onAdjust($0, nil) }
            case .reps:
                NumberEntryView(
                    title: "REPS",
                    initial: state.reps ?? 8,
                    step: 1,
                    range: 0...99
                ) { onAdjust(nil, $0) }
            }
        }
    }

    /// The two numbers about to be lifted, each its own target.
    ///
    /// They were one muted line of text that nothing could change from the
    /// wrist — the watch could say a set was done but never say what it was.
    private var entryFields: some View {
        HStack(spacing: 6) {
            fieldButton(
                label: "LB",
                value: state.weight.map { String(Int($0)) } ?? "--"
            ) { editing = .weight }

            fieldButton(
                label: "REPS",
                value: state.reps.map(String.init) ?? "--"
            ) { editing = .reps }
        }
    }

    private func fieldButton(
        label: String, value: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Text(value)
                    .font(.system(.title3, design: .rounded).weight(.semibold).monospacedDigit())
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("\(label) \(value). Tap to change.")
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

    /// The one action, labelled for what pressing it does right now.
    ///
    /// While resting that is ending rest, not logging a set — the button used
    /// to say "Done Set" throughout the countdown, which is the wrong action at
    /// the one moment there is time to read it.
    private var primaryButton: some View {
        Button {
            if isResting {
                onLift()
            } else if let weight = state.weight, let reps = state.reps {
                // Log what the screen is showing, which the lifter may have
                // just changed. Falling back to Done Set when the phone has not
                // said what the target is.
                onLogSet(Int(weight), reps)
            } else {
                onDoneSet()
            }
        } label: {
            Text(isResting ? "Lift" : "Log Set")
                .font(.system(.body, design: .rounded).weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.green)
        .accessibilityHint(
            isResting
                ? "Ends rest and starts the next set."
                : "Records this set on your iPhone and starts rest."
        )
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
