import SwiftUI

/// Layout style for `RecentWorkoutCard`.
///
/// `.compact` keeps the legacy fixed-width card used inside horizontal carousels.
/// `.row` expands to fill its container for vertical lists.
enum RecentWorkoutCardStyle {
    case compact
    case row
}

struct RecentWorkoutCard: View {
    let workout: Workout
    var style: RecentWorkoutCardStyle = .compact

    /// Tap handler. When `nil`, the card renders as plain visual content with no
    /// embedded Button -- intended for cases where the parent wraps this view in
    /// a `NavigationLink` (or similar) and needs the inner content to NOT consume
    /// taps.
    let onSelect: (() -> Void)?

    init(workout: Workout, style: RecentWorkoutCardStyle = .compact, onSelect: (() -> Void)? = nil) {
        self.workout = workout
        self.style = style
        self.onSelect = onSelect
    }

    var body: some View {
        if let onSelect {
            Button(action: {
                Haptics.light()
                onSelect()
            }) {
                cardContent
            }
            .buttonStyle(PressableCardStyle())
            .accessibilityLabel("\(workout.name), \(workout.startTime.timeAgo), \(workout.exercises.count) exercises, \(workout.durationString)")
            .accessibilityAddTraits(.isButton)
        } else {
            cardContent
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(workout.name), \(workout.startTime.timeAgo), \(workout.exercises.count) exercises, \(workout.durationString)")
        }
    }

    @ViewBuilder
    private var cardContent: some View {
        if style == .row {
            rowBody
        } else {
            compactBody
        }
    }

    private var compactBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(workout.name)
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)

            Text(workout.startTime.timeAgo)
                .font(Theme.fontSmall)
                .foregroundStyle(Theme.textSecondary)

            HStack(spacing: Theme.Spacing.sm) {
                HStack(spacing: 3) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(Theme.fontCaption2)
                    Text("\(workout.exercises.count) ex")
                }

                HStack(spacing: 3) {
                    Image(systemName: "clock")
                        .font(Theme.fontCaption2)
                    Text(workout.durationString)
                        .foregroundStyle(Theme.accent)
                }
            }
            .font(Theme.fontSmall)
            .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 160, alignment: .leading)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .strokeBorder(Theme.hairline, lineWidth: 0.5)
        )
    }

    private var rowBody: some View {
        HStack(spacing: 10) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(Theme.fontHeadline)
                .foregroundStyle(Theme.accent)
                .frame(width: Theme.Spacing.xl, height: Theme.Spacing.xl)
                .background(Theme.accent.opacity(0.15))
                .clipShape(.rect(cornerRadius: 6))

            VStack(alignment: .leading, spacing: Theme.Spacing.tighter) {
                Text(workout.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(workout.startTime.timeAgo)
                    Text("•")
                        .foregroundStyle(Theme.textTertiary)
                    Text("\(workout.exercises.count) ex")
                    Text("•")
                        .foregroundStyle(Theme.textTertiary)
                    Text(workout.durationString)
                        .foregroundStyle(Theme.accent)
                }
                .font(Theme.fontSmall)
                .foregroundStyle(Theme.textSecondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .strokeBorder(Theme.hairline, lineWidth: 0.5)
        )
        .contentShape(Rectangle())
    }
}
