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
    let onSelect: () -> Void

    var body: some View {
        Button(action: {
            Haptics.light()
            onSelect()
        }) {
            if style == .row {
                rowBody
            } else {
                compactBody
            }
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityLabel("\(workout.name), \(workout.startTime.timeAgo), \(workout.exercises.count) exercises, \(workout.durationString)")
        .accessibilityAddTraits(.isButton)
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

            HStack(spacing: 8) {
                HStack(spacing: 3) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.caption2)
                    Text("\(workout.exercises.count) ex")
                }

                HStack(spacing: 3) {
                    Image(systemName: "clock")
                        .font(.caption2)
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
                .font(.headline)
                .foregroundStyle(Theme.accent)
                .frame(width: 32, height: 32)
                .background(Theme.accent.opacity(0.15))
                .clipShape(.rect(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
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
    }
}
