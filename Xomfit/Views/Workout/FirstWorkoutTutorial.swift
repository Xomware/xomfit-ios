import SwiftUI

// MARK: - FirstWorkoutTutorial (#310)

/// One-shot dimmed overlay that introduces the three core controls of the
/// active workout screen (set row entry, completion checkmark, focus toggle).
/// Dismissal is persisted by the caller via
/// `@AppStorage("xomfit_first_workout_tutorial_seen")` so it never re-shows.
struct FirstWorkoutTutorial: View {
    /// Called when the user dismisses the overlay (either via button or backdrop tap).
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The three callouts surfaced on the overlay. Capped at three by design —
    /// any more than that is information overload for a first-run tip sheet.
    private let callouts: [Callout] = [
        Callout(
            icon: "rectangle.and.pencil.and.ellipsis",
            title: "Tap a row to log",
            body: "Tap any set row to type in your weight and reps."
        ),
        Callout(
            icon: "checkmark.circle.fill",
            title: "Tap the check to complete",
            body: "Hit the checkmark when you finish a set. The rest timer kicks off automatically."
        ),
        Callout(
            icon: "eye",
            title: "Try Focus mode",
            body: "Tap the eye icon up top for a zoomed-in, one-set-at-a-time view."
        ),
    ]

    var body: some View {
        ZStack {
            // Backdrop — tap to dismiss
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    Haptics.light()
                    onDismiss()
                }
                .accessibilityLabel("Dismiss tutorial")
                .accessibilityAddTraits(.isButton)

            // Card
            VStack(spacing: Theme.Spacing.md) {
                // Header
                VStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundStyle(Theme.accent)
                        .accessibilityHidden(true)

                    Text("Quick tour")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)

                    Text("Three things to know before your first set.")
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, Theme.Spacing.sm)

                // Callouts
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(callouts) { callout in
                        CalloutRow(callout: callout)
                    }
                }

                // Got it
                Button {
                    Haptics.success()
                    onDismiss()
                } label: {
                    Text("Got it")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .background(Theme.accent)
                        .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss tutorial")
                .accessibilityHint("Closes the quick tour. It won't show again.")
            }
            .padding(Theme.Spacing.lg)
            .background(Theme.surface)
            .clipShape(.rect(cornerRadius: Theme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .stroke(Theme.accent.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: 8)
            .padding(.horizontal, Theme.Spacing.lg)
            .frame(maxWidth: 520)
        }
        .transition(reduceMotion
            ? .opacity
            : .opacity.combined(with: .scale(scale: 0.96)))
        .zIndex(200)
    }
}

// MARK: - Callout

private struct Callout: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let body: String
}

private struct CalloutRow: View {
    let callout: Callout

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: callout.icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 32, height: 32)
                .background(Theme.accent.opacity(0.15))
                .clipShape(Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(callout.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(callout.body)
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.sm)
        .background(Theme.surface.opacity(0.6))
        .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
        .accessibilityElement(children: .combine)
    }
}
