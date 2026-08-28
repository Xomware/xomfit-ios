import SwiftUI

/// Typing a weight or a rep count on the wrist.
///
/// The Digital Crown rather than a keypad. The Garmin app grew a phone keypad
/// because a Garmin has nothing better — this watch has a precision input
/// device on its side, and a twelve-key grid on a 41mm screen would be worse
/// than the thing it replaced.
///
/// Tap the number to type it digit by digit anyway, for the jump from 45 to 225
/// that a crown makes tedious.
struct NumberEntryView: View {
    let title: String
    let step: Int
    let range: ClosedRange<Int>
    let onCommit: (Int) -> Void

    @State private var value: Int
    @State private var crown: Double
    @Environment(\.dismiss) private var dismiss

    init(
        title: String,
        initial: Int,
        step: Int,
        range: ClosedRange<Int>,
        onCommit: @escaping (Int) -> Void
    ) {
        self.title = title
        self.step = step
        self.range = range
        self.onCommit = onCommit
        _value = State(initialValue: initial)
        _crown = State(initialValue: Double(initial))
    }

    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text("\(value)")
                .font(.system(size: 44, weight: .semibold, design: .rounded).monospacedDigit())
                .contentTransition(.numericText())
                .focusable()
                .digitalCrownRotation(
                    $crown,
                    from: Double(range.lowerBound),
                    through: Double(range.upperBound),
                    by: Double(step),
                    sensitivity: .medium,
                    isContinuous: false,
                    isHapticFeedbackEnabled: true
                )
                .onChange(of: crown) { _, new in
                    // Snapped to the step so the crown lands on real weights
                    // rather than whatever fraction it stopped at.
                    let snapped = (Int(new.rounded()) / step) * step
                    value = min(max(snapped, range.lowerBound), range.upperBound)
                }

            HStack(spacing: 8) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    onCommit(value)
                    dismiss()
                } label: {
                    Image(systemName: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
        .padding(.horizontal, 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title). Current value \(value). Turn the crown to change.")
    }
}
