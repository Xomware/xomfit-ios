import SwiftUI

/// The single rest-timer presentation, shared by list mode and focus mode.
///
/// Before this, one rest timer rendered three different ways: an inline card in
/// the list, a full-screen overlay in focus mode, and a separate in-flow banner
/// when minimized. Beyond the duplication, it meant the same moment in a workout
/// looked and behaved differently depending on which view you happened to be in
/// — a large part of why moving between the two felt like switching apps.
///
/// It docks as a `.safeAreaInset(edge: .bottom)` so it never overlaps content
/// (the layout genuinely shortens), and expands in place to the big countdown
/// when tapped. `viewModel.isRestTimerMinimized` drives which state it's in, so
/// the choice survives navigating between list and focus.
struct RestTimerBar: View {
    let viewModel: WorkoutLoggerViewModel
    let onSkip: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isOvertime: Bool { viewModel.restTimeRemaining <= 0 }

    private var tint: Color { isOvertime ? Theme.destructive : Theme.accent }

    private var progress: Double {
        guard viewModel.restDuration > 0 else { return 0 }
        if isOvertime { return 1 }
        return 1 - (viewModel.restTimeRemaining / viewModel.restDuration)
    }

    private var timeString: String {
        let total = Int(abs(viewModel.restTimeRemaining))
        let mins = total / 60
        let secs = total % 60
        return (isOvertime ? "-" : "") + String(format: "%d:%02d", mins, secs)
    }

    /// Name of the exercise the lifter is heading into, when it differs from
    /// the one they just finished. Turns dead rest time into a cue.
    private var upNext: String? {
        guard let ex = viewModel.focusExercise else { return nil }
        return ex.exercise.name
    }

    var body: some View {
        Group {
            if viewModel.isRestTimerMinimized {
                collapsedBar
            } else {
                expandedPanel
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.sm)
        .animation(.xomConfident, value: viewModel.isRestTimerMinimized)
    }

    // MARK: - Collapsed

    private var collapsedBar: some View {
        Button {
            Haptics.light()
            viewModel.isRestTimerMinimized = false
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "timer")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(tint)
                    .symbolEffect(.pulse, options: reduceMotion ? .nonRepeating : .repeating)

                Text(timeString)
                    .font(Theme.fontNumberLarge)
                    .foregroundStyle(tint)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.xomSnappy, value: viewModel.restTimeRemaining)

                if let upNext {
                    Text(upNext)
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: Theme.Spacing.sm)

                Text("Skip")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, Theme.Spacing.md)
                    .frame(minHeight: 34)
                    .background(Theme.textSecondary.opacity(0.18), in: .capsule)
                    .onTapGesture {
                        Haptics.light()
                        onSkip()
                    }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .frame(maxWidth: .infinity)
            .xomGlass(in: .rect(cornerRadius: Theme.Radius.lg))
            .overlay(alignment: .bottom) {
                // Hairline progress fill along the bottom edge — reads at a
                // glance without asking the lifter to parse a number.
                GeometryReader { proxy in
                    Capsule()
                        .fill(tint)
                        .frame(width: proxy.size.width * progress, height: 2)
                        .animation(.linear(duration: 1), value: progress)
                }
                .frame(height: 2)
                .padding(.horizontal, Theme.Spacing.md)
            }
            .contentShape(.rect(cornerRadius: Theme.Radius.lg))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rest timer, \(timeString) remaining")
        .accessibilityHint("Tap to expand the full countdown")
    }

    // MARK: - Expanded

    private var expandedPanel: some View {
        VStack(spacing: Theme.Spacing.md) {
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
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 44, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Minimize rest timer")
            }

            ZStack {
                Circle()
                    .stroke(Theme.hairline, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(tint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)

                VStack(spacing: 2) {
                    Text(timeString)
                        .font(Theme.fontDisplay)
                        .foregroundStyle(tint)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.xomSnappy, value: viewModel.restTimeRemaining)
                    if let upNext {
                        Text("Up next: \(upNext)")
                            .font(Theme.fontCaption2)
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(width: 150, height: 150)

            HStack(spacing: Theme.Spacing.md) {
                Button {
                    Haptics.light()
                    viewModel.extendRestTimer()
                } label: {
                    Text("+30s")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .background(Theme.textSecondary.opacity(0.18), in: .capsule)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add 30 seconds to rest")

                Button {
                    Haptics.light()
                    onSkip()
                } label: {
                    Text("Skip Rest")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .background(tint, in: .capsule)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Skip rest and continue")
            }
        }
        .padding(Theme.Spacing.card)
        .frame(maxWidth: .infinity)
        .xomGlass(in: .rect(cornerRadius: Theme.Radius.xl))
    }
}
