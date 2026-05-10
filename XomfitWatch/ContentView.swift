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

    var body: some View {
        Group {
            if let state = sessionStore.state {
                WorkoutScreen(state: state) {
                    sessionStore.sendDoneSet()
                }
            } else {
                EmptyWatchState()
            }
        }
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
            middleSection
            Spacer(minLength: 0)
            doneButton
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
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
