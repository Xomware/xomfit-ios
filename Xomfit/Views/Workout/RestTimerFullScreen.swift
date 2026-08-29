import SwiftUI

/// The rest countdown, taking the whole screen in focus mode.
///
/// In the list view the timer is a bar at the bottom, because the list is what
/// the lifter is reading. Focus mode is the opposite: there is one exercise on
/// screen and nothing to scan, and during rest the only thing that matters is
/// how long is left. A bar at the bottom of an otherwise empty screen was
/// wasting the whole screen to show one number small.
///
/// Minimizing drops back to the same collapsed bar the list view uses, so the
/// lifter can see the exercise underneath when they want to.
struct RestTimerFullScreen: View {
    let viewModel: WorkoutLoggerViewModel
    let onLift: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isOvertime: Bool { viewModel.restTimeRemaining <= 0 }

    private var timeText: String {
        let total = Int(abs(viewModel.restTimeRemaining))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private var progress: Double {
        guard viewModel.restDuration > 0 else { return 0 }
        let done = viewModel.restTimeRemaining / viewModel.restDuration
        return min(max(done, 0), 1)
    }

    private var tint: Color { isOvertime ? Theme.alert : Theme.accent }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: Theme.Spacing.lg) {
                header

                Spacer(minLength: 0)

                ring

                if let next = viewModel.focusExercise?.exercise.name {
                    VStack(spacing: 2) {
                        Text("UP NEXT")
                            .font(Theme.fontMetricLabel)
                            .kerning(0.6)
                            .foregroundStyle(Theme.textTertiary)
                        Text(next)
                            .font(Theme.fontHeadline)
                            .foregroundStyle(Theme.textPrimary)
                            .multilineTextAlignment(.center)
                    }
                }

                Spacer(minLength: 0)

                actions
            }
            .padding(Theme.Spacing.lg)
        }
    }

    private var header: some View {
        HStack {
            Text(isOvertime ? "OVERTIME" : "REST")
                .font(Theme.fontMetricLabel)
                .kerning(0.6)
                .foregroundStyle(Theme.textTertiary)

            Spacer()

            Button {
                Haptics.light()
                viewModel.isRestTimerMinimized = true
            } label: {
                Image(systemName: "chevron.down")
                    .font(.body.weight(.bold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Minimize rest timer")
        }
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Theme.hairline, lineWidth: 14)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .linear(duration: 1), value: progress)

            VStack(spacing: 4) {
                Text(isOvertime ? "+\(timeText)" : timeText)
                    .font(.system(size: 72, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: 280)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            isOvertime ? "Overtime by \(timeText)" : "\(timeText) of rest remaining"
        )
    }

    private var actions: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Button {
                Haptics.medium()
                onLift()
            } label: {
                Text("Lift")
                    .font(Theme.fontHeadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.sm)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .accessibilityHint("Ends rest and starts the next set.")

            Button {
                Haptics.light()
                viewModel.extendRestTimer()
            } label: {
                Text("+30s")
                    .font(Theme.fontBody)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.xs)
            }
            .buttonStyle(.bordered)
            .tint(Theme.textSecondary)
        }
    }
}
