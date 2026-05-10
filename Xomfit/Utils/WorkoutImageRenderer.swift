import SwiftUI
import UIKit

/// Renders a branded workout summary card to a `UIImage` for sharing (#320).
/// Uses iOS 17 `ImageRenderer`. The card layout intentionally lives inside this
/// file so the share output is stable and doesn't drift with `WorkoutDetailView`.
@MainActor
enum WorkoutImageRenderer {
    /// Renders a workout card and returns the rendered image, or nil if rendering fails.
    static func render(workout: Workout, scale: CGFloat = 3.0) -> UIImage? {
        let card = WorkoutShareCard(workout: workout)
            .frame(width: 1080)
            .background(Theme.background)

        let renderer = ImageRenderer(content: card)
        renderer.scale = scale
        // Force the renderer into dark mode so brand colours stay correct
        // even when the user's OS is in light mode.
        renderer.proposedSize = ProposedViewSize(width: 1080, height: nil)
        return renderer.uiImage
    }
}

// MARK: - Share Card

/// Internal layout used only for image rendering. Sized for a 1080-wide card.
private struct WorkoutShareCard: View {
    let workout: Workout

    private var formattedVolume: String {
        if workout.totalVolume >= 1000 {
            return String(format: "%.1fk", workout.totalVolume / 1000)
        }
        return "\(Int(workout.totalVolume))"
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: workout.startTime)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            header
            statsRow
            exerciseList
            footer
        }
        .padding(48)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.background)
        .environment(\.colorScheme, .dark)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 8) {
                Text(dateString)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Theme.accent)
                Text(workout.name)
                    .font(.system(size: 56, weight: .heavy))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
        }
    }

    private var statsRow: some View {
        HStack(spacing: 16) {
            statCard(value: "\(workout.exercises.count)", label: "EXERCISES")
            statCard(value: "\(workout.totalSets)", label: "SETS")
            statCard(value: "\(formattedVolume) lbs", label: "VOLUME", highlight: true)
            if workout.totalPRs > 0 {
                statCard(value: "\(workout.totalPRs)", label: "PRs", color: Theme.prGold)
            }
        }
    }

    private func statCard(
        value: String,
        label: String,
        highlight: Bool = false,
        color: Color = Theme.textPrimary
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.system(size: 40, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(highlight ? Theme.accent : color)
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
    }

    private var exerciseList: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("EXERCISES")
                .font(.system(size: 14, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(Theme.textSecondary)

            VStack(spacing: 12) {
                ForEach(Array(workout.exercises.prefix(6).enumerated()), id: \.element.id) { index, exercise in
                    exerciseRow(index: index + 1, exercise: exercise)
                }
                if workout.exercises.count > 6 {
                    Text("+ \(workout.exercises.count - 6) more")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.top, 4)
                }
            }
        }
    }

    private func exerciseRow(index: Int, exercise: WorkoutExercise) -> some View {
        let hasPR = exercise.sets.contains(where: { $0.isPersonalRecord })
        return HStack(spacing: 16) {
            Text("\(index)")
                .font(.system(size: 20, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(Theme.accent)
                .frame(width: 40, height: 40)
                .background(Theme.accent.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.exercise.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text("\(exercise.sets.count) sets")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            if hasPR {
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                    Text("PR")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(Theme.prGold)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Theme.prGold.opacity(0.15))
                .clipShape(Capsule())
            }
        }
        .padding(16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var footer: some View {
        HStack {
            Image("XomFitLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
            Text("XomFit")
                .font(.system(size: 24, weight: .heavy))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Text(workout.durationString)
                .font(.system(size: 22, weight: .bold).monospacedDigit())
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Theme.accent.opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(.top, 8)
    }
}

// MARK: - UIActivityViewController helper

/// SwiftUI wrapper presenting `UIActivityViewController` with the rendered image (#320).
struct WorkoutShareSheet: UIViewControllerRepresentable {
    let image: UIImage

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [image], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
