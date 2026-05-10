import SwiftUI

/// Single row within the "Top Exercises" section: name, lifetime volume,
/// set count, and a thin accent capsule showing relative volume vs. the leader.
struct TopExerciseRow: View {
    let exercise: ProfileViewModel.TopExercise
    /// Max volume across the whole list — used to scale the capsule width.
    let maxVolume: Double

    private var fillFraction: CGFloat {
        guard maxVolume > 0 else { return 0 }
        return CGFloat(min(1, exercise.volume / maxVolume))
    }

    private var formattedVolume: String {
        if exercise.volume >= 1_000_000 {
            return String(format: "%.1fM", exercise.volume / 1_000_000)
        } else if exercise.volume >= 1000 {
            return String(format: "%.1fk", exercise.volume / 1000)
        }
        return "\(Int(exercise.volume))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Text(exercise.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                Spacer()

                VStack(alignment: .trailing, spacing: Theme.Spacing.tighter) {
                    Text("\(formattedVolume) lbs")
                        .font(Theme.fontNumberMedium)
                        .foregroundStyle(Theme.textPrimary)
                    XomMetricLabel("\(exercise.setCount) sets")
                }
            }

            // Relative-volume capsule
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.hairline)
                    Capsule()
                        .fill(Theme.accent.opacity(0.3))
                        .frame(width: proxy.size.width * fillFraction)
                }
            }
            .frame(height: Theme.Spacing.tight)
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(exercise.name), \(formattedVolume) pounds, \(exercise.setCount) sets")
    }
}

#Preview {
    VStack {
        TopExerciseRow(
            exercise: .init(name: "Bench Press", volume: 24_500, setCount: 64),
            maxVolume: 24_500
        )
        TopExerciseRow(
            exercise: .init(name: "Squat", volume: 18_200, setCount: 48),
            maxVolume: 24_500
        )
        TopExerciseRow(
            exercise: .init(name: "Deadlift", volume: 15_900, setCount: 32),
            maxVolume: 24_500
        )
    }
    .padding()
    .background(Theme.background)
}
