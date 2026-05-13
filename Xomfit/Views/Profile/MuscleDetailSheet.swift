import SwiftUI

/// Drill-in sheet for the full-body heatmap (#346).
///
/// Shows which exercises hit `muscle` in the selected range, ranked by volume
/// contribution. Tapping a row opens `ExerciseDetailSheet` so the user can
/// review the lift's form notes without leaving Profile > Stats.
struct MuscleDetailSheet: View {
    let muscle: MuscleGroup
    let range: HeatmapTimeRange
    let totalVolume: Double
    let exercises: [ExerciseVolumeEntry]

    @Environment(\.dismiss) private var dismiss
    @State private var detailExercise: Exercise?

    /// Display unit. Volume is shown in the user's preferred unit (Body convention).
    @AppStorage("weightUnit") private var weightUnitRaw: String = WeightUnit.lbs.rawValue
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .lbs }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        header
                        if exercises.isEmpty {
                            emptyState
                        } else {
                            exerciseList
                        }
                    }
                    .padding(Theme.Spacing.md)
                }
            }
            .navigationTitle(muscle.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.accent)
                }
            }
            .sheet(item: $detailExercise) { exercise in
                ExerciseDetailSheet(exercise: exercise)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: muscle.icon)
                    .font(.system(size: 28))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 56, height: 56)
                    .background(Theme.accentMuted)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: Theme.Spacing.tighter) {
                    Text(muscle.displayName)
                        .font(Theme.fontTitle2)
                        .foregroundStyle(Theme.textPrimary)
                    Text(range.accessibilityName)
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
            }

            HStack(spacing: Theme.Spacing.lg) {
                stat(label: "Total Volume", value: formattedVolume(totalVolume))
                stat(label: "Exercises", value: "\(exercises.count)")
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }

    private func stat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.tighter) {
            Text(label)
                .font(Theme.fontSmall)
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(Theme.fontNumberMedium)
                .foregroundStyle(Theme.textPrimary)
        }
    }

    // MARK: - Exercise List

    private var exerciseList: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Exercises")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)

            VStack(spacing: Theme.Spacing.xs) {
                ForEach(exercises) { entry in
                    Button {
                        Haptics.selection()
                        detailExercise = entry.exercise
                    } label: {
                        row(for: entry)
                    }
                    .buttonStyle(PressableCardStyle())
                    .accessibilityLabel(accessibilityLabel(for: entry))
                    .accessibilityHint("Opens exercise details")
                }
            }
        }
    }

    private func row(for entry: ExerciseVolumeEntry) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: entry.exercise.icon)
                .font(Theme.fontSubheadline)
                .foregroundStyle(Theme.accent)
                .frame(width: 36, height: 36)
                .background(Theme.accentMuted)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: Theme.Spacing.tighter) {
                Text(entry.exercise.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text("\(entry.setCount) sets · best \(bestSetText(entry))")
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: Theme.Spacing.tighter) {
                Text(formattedVolume(entry.volume))
                    .font(Theme.fontNumberMedium)
                    .foregroundStyle(Theme.textPrimary)
                Text("Volume")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(Theme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.Radius.sm))
        .contentShape(Rectangle())
    }

    // MARK: - Empty State

    private var emptyState: some View {
        XomEmptyState(
            icon: muscle.icon,
            title: "No \(muscle.displayName.lowercased()) work yet",
            subtitle: "Log a workout that hits this muscle in the selected range.",
            ctaLabel: nil,
            ctaAction: nil
        )
        .cardStyle()
    }

    // MARK: - Helpers

    private func bestSetText(_ entry: ExerciseVolumeEntry) -> String {
        let weight = entry.bestSetWeight.formattedWeight(unit: weightUnit)
        return "\(weight) \(weightUnit.displayName) \u{00D7} \(entry.bestSetReps)"
    }

    /// Volume is in lbs · reps. We show it in the user's unit and pretty-format.
    private func formattedVolume(_ volume: Double) -> String {
        let converted = volume * weightUnit.multiplierFromLbs
        if converted >= 1_000_000 {
            return String(format: "%.1fM %@", converted / 1_000_000, weightUnit.displayName)
        } else if converted >= 1_000 {
            return String(format: "%.1fk %@", converted / 1_000, weightUnit.displayName)
        }
        return String(format: "%.0f %@", converted, weightUnit.displayName)
    }

    private func accessibilityLabel(for entry: ExerciseVolumeEntry) -> String {
        let volume = formattedVolume(entry.volume)
        return "\(entry.exercise.name), \(entry.setCount) sets, \(volume) volume"
    }
}

// MARK: - Preview

#Preview {
    MuscleDetailSheet(
        muscle: .chest,
        range: .month,
        totalVolume: 24_500,
        exercises: [
            ExerciseVolumeEntry(
                exercise: .benchPress,
                setCount: 12,
                volume: 14_000,
                bestSetWeight: 225,
                bestSetReps: 5
            ),
            ExerciseVolumeEntry(
                exercise: Exercise.mockExercises[0],
                setCount: 8,
                volume: 10_500,
                bestSetWeight: 185,
                bestSetReps: 8
            ),
        ]
    )
    .preferredColorScheme(.dark)
}
