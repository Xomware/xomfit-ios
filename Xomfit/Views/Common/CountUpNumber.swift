import SwiftUI

// MARK: - Count-Up Number

/// Displays an integer that animates from 0 to `target` on first appearance.
/// Uses monospaced digits to prevent layout jitter during animation.
/// Duration defaults to 0.8s with an ease-out curve.
struct CountUpNumber: View {
    let target: Int
    var font: Font = Theme.fontNumberLarge
    var color: Color = Theme.textPrimary
    var duration: Double = 0.8

    @State private var displayed: Int = 0
    @State private var hasAppeared = false

    var body: some View {
        Text("\(displayed)")
            .font(font)
            .foregroundStyle(color)
            .monospacedDigit()
            .onAppear {
                guard !hasAppeared else { return }
                hasAppeared = true
                animateCount()
            }
    }

    private func animateCount() {
        let steps = min(target, 60)
        guard steps > 0 else {
            displayed = target
            return
        }
        let stepDuration = duration / Double(steps)
        for i in 1...steps {
            let delay = stepDuration * Double(i)
            let value = Int(Double(target) * Double(i) / Double(steps))
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                displayed = value
            }
        }
    }
}
