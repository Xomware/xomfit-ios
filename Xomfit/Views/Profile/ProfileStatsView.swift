import SwiftUI

struct ProfileStatsView: View {
    let totalWorkouts: Int
    let totalVolume: String
    let totalPRs: Int
    let recentPRs: [PersonalRecord]
    let muscleGroupSetsThisWeek: [String: Int]
    let muscleGroupSetsThisMonth: [String: Int]
    /// Current consecutive-day workout streak (#250).
    var currentStreak: Int = 0
    /// Longest streak across history (#250).
    var longestStreak: Int = 0

    @State private var heatmapFilter: HeatmapTimeFilter = .week

    private var activeMuscleGroupSets: [String: Int] {
        switch heatmapFilter {
        case .week: return muscleGroupSetsThisWeek
        case .month: return muscleGroupSetsThisMonth
        }
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            StreakCard(currentStreak: currentStreak, longestStreak: longestStreak)
            statsCards
            heatmapSection
            prSection
        }
        .padding(.horizontal, Theme.Spacing.md)
    }

    // MARK: - Stats Cards

    private var statsCards: some View {
        HStack(spacing: Theme.Spacing.sm) {
            countUpStatCard(icon: "dumbbell.fill", count: totalWorkouts, label: "Workouts", iconColor: Theme.accent)
            XomCard(padding: Theme.Spacing.sm) {
                XomStat(totalVolume, label: "Volume", icon: "scalemass.fill", iconColor: Theme.accent)
                    .padding(.vertical, Theme.Spacing.xs)
            }
            .accessibilityLabel("\(totalVolume) Volume")
            countUpStatCard(icon: "trophy.fill", count: totalPRs, label: "PRs", iconColor: Theme.prGold)
        }
    }

    private func countUpStatCard(icon: String, count: Int, label: String, iconColor: Color) -> some View {
        XomCard(padding: Theme.Spacing.sm) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(iconColor)
                CountUpNumber(target: count)
                XomMetricLabel(label)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.xs)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(count) \(label)")
    }

    // MARK: - Heatmap Section

    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("Muscle Heatmap")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)

                Spacer()

                Picker("Time Range", selection: $heatmapFilter) {
                    ForEach(HeatmapTimeFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
            }
            .padding(.horizontal, Theme.Spacing.sm)

            BodyHeatmapView(muscleGroupSets: activeMuscleGroupSets)
        }
        .cardStyle()
    }

    // MARK: - PR Section

    @ViewBuilder
    private var prSection: some View {
        if recentPRs.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Recent PRs")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, Theme.Spacing.sm)

                ForEach(recentPRs) { pr in
                    PRBadgeRow(pr: pr)
                }
            }
            .cardStyle()
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "trophy")
                .font(.largeTitle)
                .foregroundStyle(Theme.textSecondary)
            Text("No PRs yet")
                .font(Theme.fontBody)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No personal records yet")
    }
}
