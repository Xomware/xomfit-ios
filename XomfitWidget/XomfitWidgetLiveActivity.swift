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

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: XomfitWidgetAttributes.self) { context in
            // Lock screen / banner UI
            lockScreenView(context: context)
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
                    Text(context.attributes.startTime, style: .timer)
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Self.accentGreen)
                        .multilineTextAlignment(.trailing)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.isResting ? "Resting" : context.state.currentExercise)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    expandedBottomView(state: context.state)
                }
            } compactLeading: {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Self.accentGreen)
            } compactTrailing: {
                if context.state.isResting, let endDate = context.state.restEndDate {
                    Text(timerInterval: Date.now...endDate, countsDown: true)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(restColor(context.state))
                        .multilineTextAlignment(.trailing)
                } else {
                    Text(context.attributes.startTime, style: .timer)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Self.accentGreen)
                        .multilineTextAlignment(.trailing)
                }
            } minimal: {
                if context.state.isResting, let endDate = context.state.restEndDate {
                    Text(timerInterval: Date.now...endDate, countsDown: true)
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
            .widgetURL(URL(string: "xomfit://workout"))
            .keylineTint(restColor(context.state))
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

                Text(context.attributes.startTime, style: .timer)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Self.accentGreen)
                    .multilineTextAlignment(.trailing)
            }

            // Middle row: current exercise + set/exercise progress
            HStack(spacing: 0) {
                if state.isResting, let endDate = state.restEndDate {
                    HStack(spacing: 4) {
                        Text("Resting")
                        Text(timerInterval: Date.now...endDate, countsDown: true)
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
            if state.isResting, let endDate = state.restEndDate {
                HStack {
                    Image(systemName: "timer")
                        .font(.system(size: 11))
                        .foregroundStyle(restColor(state))
                    Text("Rest:")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(restColor(state))
                    Text(timerInterval: Date.now...endDate, countsDown: true)
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

    // MARK: - Helpers

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
}

#Preview("Notification", as: .content, using: XomfitWidgetAttributes.preview) {
    XomfitWidgetLiveActivity()
} contentStates: {
    XomfitWidgetAttributes.ContentState.midWorkout
    XomfitWidgetAttributes.ContentState.nearEnd
}
