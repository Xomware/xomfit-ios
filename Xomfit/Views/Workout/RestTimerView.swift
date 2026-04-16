import SwiftUI

/// Horizontal rest timer banner shown between sets.
/// Circular conic-gradient progress ring on the left, display-sized countdown, and controls.
struct RestTimerView: View {
    let restTimeRemaining: Double
    let restDuration: Double
    let onSkip: () -> Void
    let onExtend: () -> Void

    @State private var breatheScale: CGFloat = 1.0
    @State private var completionFlash: Bool = false
    @State private var prevRemaining: Double = 0

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
        HStack(spacing: Theme.Spacing.md) {
            // Conic-gradient progress ring
            ZStack {
                RestTimerRingView(progress: progress, color: ringColor, lineWidth: 5)

                Text(timeString)
                    .font(Theme.fontDisplay)
                    .foregroundStyle(isOvertime ? Theme.destructive : Theme.textPrimary)
                    .scaleEffect(breatheScale)
                    .animation(
                        .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                        value: breatheScale
                    )
                    .monospacedDigit()
            }
            .frame(width: 80, height: 80)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(isOvertime ? "Rest timer, \(timeString) overtime" : "Rest timer, \(timeString) remaining")
            .onAppear {
                breatheScale = 1.02
            }

            // Label + controls
            VStack(alignment: .leading, spacing: 8) {
                XomMetricLabel("Rest")

                HStack(spacing: 10) {
                    Button {
                        Haptics.light()
                        onSkip()
                    } label: {
                        Text("Skip")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.textPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Theme.surfaceElevated)
                            .clipShape(.capsule)
                            .overlay(
                                Capsule().strokeBorder(Theme.hairline, lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Skip rest timer")

                    Button {
                        Haptics.light()
                        onExtend()
                    } label: {
                        Text("+30s")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Theme.accentMuted)
                            .clipShape(.capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add 30 seconds to rest timer")
                }
            }

            Spacer()
        }
        .padding(Theme.Spacing.md)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .strokeBorder(Theme.hairline, lineWidth: 0.5)
        )
        .overlay(
            // Completion flourish: accent flash at T=0
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .fill(Theme.accent.opacity(completionFlash ? 0.15 : 0))
                .allowsHitTesting(false)
        )
        .onAppear {
            prevRemaining = restTimeRemaining
        }
        .onChange(of: restTimeRemaining) { _, newValue in
            // Fire flourish exactly once when timer crosses zero
            if prevRemaining > 0 && newValue <= 0 && !completionFlash {
                withAnimation(.easeIn(duration: 0.2)) {
                    completionFlash = true
                }
                withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
                    completionFlash = false
                }
            }
            prevRemaining = newValue
        }
    }
}
