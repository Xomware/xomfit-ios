import SwiftUI

/// Horizontal rest timer banner shown between sets.
/// Circular countdown ring on the left, time display and controls on the right.
struct RestTimerView: View {
    let restTimeRemaining: Double
    let restDuration: Double
    let onSkip: () -> Void
    let onExtend: () -> Void

    private var isOvertime: Bool {
        restTimeRemaining <= 0
    }

    private var progress: Double {
        guard restDuration > 0 else { return 0 }
        if isOvertime { return 1.0 }
        return 1 - (restTimeRemaining / restDuration)
    }

    private var ringColor: Color {
        isOvertime ? Theme.destructive : Theme.accent
    }

    private var timeString: String {
        if isOvertime {
            let total = Int(abs(restTimeRemaining))
            let mins = total / 60
            let secs = total % 60
            return String(format: "-%d:%02d", mins, secs)
        }
        let total = Int(restTimeRemaining)
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }

    var body: some View {
        HStack(spacing: Theme.paddingMedium) {
            // Circular countdown ring
            ZStack {
                Circle()
                    .stroke(
                        Theme.textSecondary.opacity(0.3),
                        lineWidth: 5
                    )

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        ringColor,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)

                Text(timeString)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(isOvertime ? Theme.destructive : Theme.accent)
            }
            .frame(width: 64, height: 64)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(isOvertime ? "Rest timer, \(timeString) overtime" : "Rest timer, \(timeString) remaining")

            // Label + controls
            VStack(alignment: .leading, spacing: 8) {
                Text("Rest")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)

                HStack(spacing: 10) {
                    Button {
                        onSkip()
                    } label: {
                        Text("Skip")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Theme.textSecondary.opacity(0.2))
                            .clipShape(.capsule)
                    }
                    .accessibilityLabel("Skip rest timer")

                    Button {
                        onExtend()
                    } label: {
                        Text("+30s")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Theme.accent.opacity(0.12))
                            .clipShape(.capsule)
                    }
                    .accessibilityLabel("Add 30 seconds to rest timer")
                }
            }

            Spacer()
        }
        .padding(Theme.paddingMedium)
        .background(Theme.cardBackground)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }
}
