import SwiftUI

struct RecentWorkoutCard: View {
    let workout: Workout
    let onSelect: () -> Void

    var body: some View {
        Button(action: {
            Haptics.light()
            onSelect()
        }) {
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
        .buttonStyle(PressableCardStyle())
        .accessibilityLabel("\(workout.name), \(workout.startTime.timeAgo), \(workout.exercises.count) exercises, \(workout.durationString)")
        .accessibilityAddTraits(.isButton)
    }
}
