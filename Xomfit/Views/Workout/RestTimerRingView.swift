import SwiftUI

/// Extracted conic-gradient progress ring used by RestTimerView and anywhere a circular progress indicator is needed.
struct RestTimerRingView: View {
    /// Progress from 0.0 (empty) to 1.0 (full).
    let progress: Double
    /// Color of the filled arc.
    let color: Color
    /// Ring stroke width.
    var lineWidth: CGFloat = 5

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)

            // Filled arc — conic gradient
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [color.opacity(0.7), color],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(-90 + 360 * progress)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)
        }
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 24) {
        RestTimerRingView(progress: 0.25, color: Theme.accent, lineWidth: 6)
            .frame(width: 80, height: 80)
        RestTimerRingView(progress: 0.6, color: Theme.accent, lineWidth: 6)
            .frame(width: 80, height: 80)
        RestTimerRingView(progress: 1.0, color: Theme.destructive, lineWidth: 6)
            .frame(width: 80, height: 80)
    }
    .padding()
    .background(Theme.background)
}
