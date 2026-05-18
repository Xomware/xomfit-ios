//
//  XomfitWidgetLiveActivity.swift
//  XomfitWidget
//
//  Created by Dominick Giordano on 3/31/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Live Activity Widget
//
// NOTE: XomfitWidgetAttributes is defined in XomfitWidgetAttributes.swift
// which lives in BOTH the XomfitWidget/ folder and Xomfit/Models/ folder
// so each target compiles its own copy. Keep them in sync.

struct XomfitWidgetLiveActivity: Widget {
    private static let accentGreen = Color(red: 0.2, green: 1.0, blue: 0.4)     // #33FF66
    private static let darkBackground = Color(red: 0.039, green: 0.039, blue: 0.059) // #0A0A0F

    private func restColor(_ state: XomfitWidgetAttributes.ContentState) -> Color {
        state.isOvertime ? .red : Self.accentGreen
    }

    /// Renders the rest-timer countdown, switching to a "+M:SS" count-up display
    /// when overtime so SwiftUI's `Text(timerInterval:countsDown:true)` doesn't
    /// blow up on a past endDate (issue #303).
    @ViewBuilder
    private func restTimerCountdown(endDate: Date, isOvertime: Bool) -> some View {
        if isOvertime || endDate <= Date.now {
            HStack(spacing: 0) {
                Text("+")
                Text(endDate, style: .timer)
            }
        } else {
            Text(timerInterval: Date.now...endDate, countsDown: true)
        }
    }

    /// Static "Paused" label used in place of live timers when the workout is paused.
    @ViewBuilder
    private func pausedLabel(font: Font) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "pause.fill")
                .font(font)
            Text("Paused")
                .font(font)
        }
        .foregroundStyle(.white.opacity(0.85))
    }

    /// Color used for the per-stretch countdown. Goes red once the user holds
    /// past the recommended time (#398).
    private func stretchColor(_ state: XomfitWidgetAttributes.ContentState) -> Color {
        state.stretchSecondsRemaining < 0 ? .red : Self.accentGreen
    }

    /// Per-stretch countdown text (e.g. "12s", "-5s"). The negative `Int`
    /// renders its own minus sign for the overtime case.
    private func stretchCountdownText(_ state: XomfitWidgetAttributes.ContentState) -> String {
        "\(state.stretchSecondsRemaining)s"
    }

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: XomfitWidgetAttributes.self) { context in
            // Lock screen / banner UI
            Group {
                if context.state.mode == .stretch {
                    stretchLockScreenView(context: context)
                } else {
                    lockScreenView(context: context)
                }
            }
            .activityBackgroundTint(Self.darkBackground)
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.workoutName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.mode == .stretch {
                        Text(stretchCountdownText(context.state))
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundStyle(stretchColor(context.state))
                            .monospacedDigit()
                            .multilineTextAlignment(.trailing)
                    } else if context.state.isPaused {
                        pausedLabel(font: .system(size: 14, weight: .semibold))
                    } else {
                        Text(context.attributes.startTime, style: .timer)
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Self.accentGreen)
                            .multilineTextAlignment(.trailing)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(centerText(for: context.state))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.mode == .stretch {
                        stretchExpandedBottom(state: context.state)
                    } else {
                        expandedBottomView(state: context.state)
                    }
                }
            } compactLeading: {
                if context.state.mode == .stretch {
                    Image(systemName: "figure.flexibility")
                        .font(.system(size: 12))
                        .foregroundStyle(Self.accentGreen)
                } else {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Self.accentGreen)
                }
            } compactTrailing: {
                if context.state.mode == .stretch {
                    Text(stretchCountdownText(context.state))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(stretchColor(context.state))
                        .multilineTextAlignment(.trailing)
                        .monospacedDigit()
                } else if context.state.isPaused {
                    pausedLabel(font: .system(size: 12, weight: .semibold))
                } else if context.state.isResting, let endDate = context.state.restEndDate {
                    restTimerCountdown(endDate: endDate, isOvertime: context.state.isOvertime)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(restColor(context.state))
                        .multilineTextAlignment(.trailing)
                        .monospacedDigit()
                } else {
                    Text(context.attributes.startTime, style: .timer)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Self.accentGreen)
                        .multilineTextAlignment(.trailing)
                }
            } minimal: {
                if context.state.mode == .stretch {
                    Text(stretchCountdownText(context.state))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(stretchColor(context.state))
                        .multilineTextAlignment(.center)
                        .monospacedDigit()
                } else if context.state.isPaused {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                } else if context.state.isResting, let endDate = context.state.restEndDate {
                    restTimerCountdown(endDate: endDate, isOvertime: context.state.isOvertime)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(restColor(context.state))
                        .multilineTextAlignment(.center)
                        .monospacedDigit()
                } else {
                    Text(context.attributes.startTime, style: .timer)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Self.accentGreen)
                        .multilineTextAlignment(.center)
                        .monospacedDigit()
                }
            }
            .widgetURL(URL(string: context.state.mode == .stretch ? "xomfit://stretch" : "xomfit://workout"))
            .keylineTint(context.state.mode == .stretch ? stretchColor(context.state) : restColor(context.state))
        }
    }

    // MARK: - Lock Screen View

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<XomfitWidgetAttributes>) -> some View {
        let state = context.state
        let setProgress: Double = state.totalSets > 0
            ? Double(state.completedSets) / Double(state.totalSets)
            : 0

        VStack(alignment: .leading, spacing: 8) {
            // Top row: workout name + elapsed time
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Self.accentGreen)
                    Text(context.attributes.workoutName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                Spacer()

                if state.isPaused {
                    pausedLabel(font: .system(size: 15, weight: .semibold))
                } else {
                    Text(context.attributes.startTime, style: .timer)
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Self.accentGreen)
                        .multilineTextAlignment(.trailing)
                }
            }

            // Middle row: current exercise + set/exercise progress
            HStack(spacing: 0) {
                if state.isPaused {
                    Text("Paused")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                } else if state.isResting, let endDate = state.restEndDate {
                    HStack(spacing: 4) {
                        Text("Resting")
                        restTimerCountdown(endDate: endDate, isOvertime: state.isOvertime)
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(restColor(state))
                    .lineLimit(1)
                } else {
                    Text(state.currentExercise)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }

                Text("  \u{2022}  ")
                    .foregroundStyle(.white.opacity(0.4))

                Text("Set \(state.completedSets)/\(state.totalSets)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))

                Text("  \u{2022}  ")
                    .foregroundStyle(.white.opacity(0.4))

                let currentExNum = min(state.totalExercises, max(1, exerciseNumber(state: state)))
                Text("\(currentExNum)/\(state.totalExercises) ex")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.white.opacity(0.15))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(Self.accentGreen)
                        .frame(width: max(0, geo.size.width * setProgress), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Dynamic Island Expanded Bottom

    @ViewBuilder
    private func expandedBottomView(state: XomfitWidgetAttributes.ContentState) -> some View {
        let setProgress: Double = state.totalSets > 0
            ? Double(state.completedSets) / Double(state.totalSets)
            : 0

        VStack(alignment: .leading, spacing: 6) {
            if state.isPaused {
                HStack {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.85))
                    Text("Paused")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                }
            } else if state.isResting, let endDate = state.restEndDate {
                HStack {
                    Image(systemName: "timer")
                        .font(.system(size: 11))
                        .foregroundStyle(restColor(state))
                    Text("Rest:")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(restColor(state))
                    restTimerCountdown(endDate: endDate, isOvertime: state.isOvertime)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(restColor(state))
                    Spacer()
                }
            }

            HStack(spacing: 0) {
                Text(state.currentExercise)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)

                Spacer()

                Text("Set \(state.completedSets)/\(state.totalSets)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }

            // Progress bar
            ProgressView(value: setProgress)
                .tint(Self.accentGreen)
                .scaleEffect(y: 1.5, anchor: .center)
        }
    }

    // MARK: - Stretch Live Activity (#398)

    /// Lock-screen card for the guided stretch sequence. Mirrors the workout
    /// lock-screen layout (top row, middle row, progress bar) but swaps the
    /// content for the active stretch + countdown.
    @ViewBuilder
    private func stretchLockScreenView(context: ActivityViewContext<XomfitWidgetAttributes>) -> some View {
        let state = context.state
        let progress: Double = state.stretchTotal > 0
            ? min(1, max(0, Double(state.stretchIndex) / Double(state.stretchTotal)))
            : 0

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "figure.flexibility")
                        .font(.system(size: 14))
                        .foregroundStyle(Self.accentGreen)
                    Text(context.attributes.workoutName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                Spacer()

                Text(stretchCountdownText(state))
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(stretchColor(state))
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
            }

            HStack(spacing: 0) {
                Text(state.stretchName.isEmpty ? " " : state.stretchName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)

                Text("  \u{2022}  ")
                    .foregroundStyle(.white.opacity(0.4))

                Text("\(state.stretchIndex)/\(state.stretchTotal)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.white.opacity(0.15))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Self.accentGreen)
                        .frame(width: max(0, geo.size.width * progress), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    /// Bottom region for the expanded Dynamic Island when in stretch mode.
    /// Shows current stretch name, sequence progress, and a small label that
    /// flips red when the user is past the recommended hold time.
    @ViewBuilder
    private func stretchExpandedBottom(state: XomfitWidgetAttributes.ContentState) -> some View {
        let progress: Double = state.stretchTotal > 0
            ? min(1, max(0, Double(state.stretchIndex) / Double(state.stretchTotal)))
            : 0

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 0) {
                Text(state.stretchName.isEmpty ? " " : state.stretchName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)

                Spacer()

                Text("\(state.stretchIndex)/\(state.stretchTotal)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }

            if state.stretchSecondsRemaining < 0 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 11))
                    Text("Holding past target")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.red)
            }

            ProgressView(value: progress)
                .tint(Self.accentGreen)
                .scaleEffect(y: 1.5, anchor: .center)
        }
    }

    // MARK: - Helpers

    private func centerText(for state: XomfitWidgetAttributes.ContentState) -> String {
        if state.mode == .stretch {
            return state.stretchName.isEmpty ? "Stretching" : state.stretchName
        }
        if state.isPaused { return "Paused" }
        if state.isResting { return "Resting" }
        return state.currentExercise
    }

    private func formatTime(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Rough estimate of which exercise number we're on based on completed sets distribution.
    private func exerciseNumber(state: XomfitWidgetAttributes.ContentState) -> Int {
        guard state.totalExercises > 0, state.totalSets > 0 else { return 1 }
        let avgSetsPerExercise = Double(state.totalSets) / Double(state.totalExercises)
        guard avgSetsPerExercise > 0 else { return 1 }
        return Int(Double(state.completedSets) / avgSetsPerExercise) + 1
    }
}

// MARK: - Preview Data

extension XomfitWidgetAttributes {
    fileprivate static var preview: XomfitWidgetAttributes {
        XomfitWidgetAttributes(workoutName: "Push Day", startTime: Date().addingTimeInterval(-754))
    }
}

extension XomfitWidgetAttributes.ContentState {
    fileprivate static var midWorkout: XomfitWidgetAttributes.ContentState {
        XomfitWidgetAttributes.ContentState(
            elapsedSeconds: 754,
            completedSets: 7,
            totalSets: 18,
            currentExercise: "Bench Press",
            totalExercises: 6
        )
    }

    fileprivate static var nearEnd: XomfitWidgetAttributes.ContentState {
        XomfitWidgetAttributes.ContentState(
            elapsedSeconds: 3421,
            completedSets: 16,
            totalSets: 18,
            currentExercise: "Lateral Raises",
            totalExercises: 6
        )
    }

    fileprivate static var stretchMid: XomfitWidgetAttributes.ContentState {
        XomfitWidgetAttributes.ContentState(
            elapsedSeconds: 120,
            completedSets: 0,
            totalSets: 0,
            currentExercise: "",
            totalExercises: 0,
            mode: .stretch,
            stretchName: "Pigeon Pose",
            stretchSecondsRemaining: 18,
            stretchIndex: 3,
            stretchTotal: 6
        )
    }

    fileprivate static var stretchOvertime: XomfitWidgetAttributes.ContentState {
        XomfitWidgetAttributes.ContentState(
            elapsedSeconds: 220,
            completedSets: 0,
            totalSets: 0,
            currentExercise: "",
            totalExercises: 0,
            mode: .stretch,
            stretchName: "Couch Stretch",
            stretchSecondsRemaining: -7,
            stretchIndex: 4,
            stretchTotal: 6
        )
    }
}

#Preview("Notification", as: .content, using: XomfitWidgetAttributes.preview) {
    XomfitWidgetLiveActivity()
} contentStates: {
    XomfitWidgetAttributes.ContentState.midWorkout
    XomfitWidgetAttributes.ContentState.nearEnd
    XomfitWidgetAttributes.ContentState.stretchMid
    XomfitWidgetAttributes.ContentState.stretchOvertime
}
