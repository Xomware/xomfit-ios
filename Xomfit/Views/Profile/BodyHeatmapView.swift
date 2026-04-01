import SwiftUI

// MARK: - Time Filter

enum HeatmapTimeFilter: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"

    var id: String { rawValue }
}

// MARK: - Body Heatmap View

struct BodyHeatmapView: View {
    let muscleGroupSets: [String: Int]

    private static let frontMuscles = ["Chest", "Shoulders", "Biceps", "Abs", "Quads"]
    private static let backMuscles = ["Traps", "Back", "Lats", "Triceps", "Glutes", "Hamstrings", "Calves"]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                // Front column
                VStack(spacing: Theme.Spacing.sm) {
                    Text("Front")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.textSecondary)

                    ForEach(Self.frontMuscles, id: \.self) { muscle in
                        muscleCell(name: muscle, sets: muscleGroupSets[muscle] ?? 0)
                    }
                }
                .frame(maxWidth: .infinity)

                // Back column
                VStack(spacing: Theme.Spacing.sm) {
                    Text("Back")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.textSecondary)

                    ForEach(Self.backMuscles, id: \.self) { muscle in
                        muscleCell(name: muscle, sets: muscleGroupSets[muscle] ?? 0)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            // Legend
            heatmapLegend
                .padding(.top, Theme.Spacing.sm)
        }
    }

    // MARK: - Muscle Cell

    private func muscleCell(name: String, sets: Int) -> some View {
        HStack {
            Text(name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(sets > 0 ? Theme.textPrimary : Theme.textSecondary)

            Spacer()

            Text("\(sets)")
                .font(.caption.weight(.bold).monospaced())
                .foregroundStyle(sets > 0 ? Theme.textPrimary : Theme.textSecondary)
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, 10)
        .background(heatColor(for: sets))
        .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name): \(sets) sets")
    }

    // MARK: - Heat Color

    /// Maps set count to intensity color:
    /// 0 = card background (not hit), 1-3 = green (light), 4-8 = yellow, 9-15 = orange, 16+ = red
    private func heatColor(for sets: Int) -> Color {
        switch sets {
        case 0:
            return Theme.surface
        case 1...3:
            return Theme.accent.opacity(0.3)
        case 4...8:
            return Color.yellow.opacity(0.3)
        case 9...15:
            return Color.orange.opacity(0.3)
        default:
            return Theme.destructive.opacity(0.3)
        }
    }

    // MARK: - Legend

    private var heatmapLegend: some View {
        HStack(spacing: Theme.Spacing.sm) {
            legendItem(color: Theme.surface, label: "None")
            legendItem(color: Theme.accent.opacity(0.3), label: "Light")
            legendItem(color: Color.yellow.opacity(0.3), label: "Some")
            legendItem(color: Color.orange.opacity(0.3), label: "Moderate")
            legendItem(color: Theme.destructive.opacity(0.3), label: "Heavy")
        }
        .frame(maxWidth: .infinity)
    }

    private func legendItem(color: Color, label: String) -> some View {
        VStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 20, height: 12)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Theme.textSecondary.opacity(0.2), lineWidth: 0.5)
                )
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Theme.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) intensity")
    }
}
