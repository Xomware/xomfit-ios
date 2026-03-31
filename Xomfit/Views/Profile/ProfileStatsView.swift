import SwiftUI

struct ProfileStatsView: View {
    let totalWorkouts: Int
    let totalVolume: String
    let totalPRs: Int
    let recentPRs: [PersonalRecord]
    let muscleGroupSetsThisWeek: [String: Int]
    let muscleGroupSetsThisMonth: [String: Int]

    @State private var heatmapFilter: HeatmapTimeFilter = .week

    private var activeMuscleGroupSets: [String: Int] {
        switch heatmapFilter {
        case .week: return muscleGroupSetsThisWeek
        case .month: return muscleGroupSetsThisMonth
        }
    }

    var body: some View {
        VStack(spacing: Theme.paddingSmall) {
            statsCards
            heatmapSection
            prSection
        }
        .padding(.horizontal, Theme.paddingMedium)
    }

    // MARK: - Stats Cards

    private var statsCards: some View {
        HStack(spacing: Theme.paddingSmall) {
            statCard(icon: "dumbbell.fill", value: "\(totalWorkouts)", label: "Workouts", color: Theme.accent)
            statCard(icon: "scalemass.fill", value: totalVolume, label: "Volume", color: Theme.accent)
            statCard(icon: "trophy.fill", value: "\(totalPRs)", label: "PRs", color: Theme.prGold)
        }
    }

    private func statCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(Theme.fontSmall)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.paddingMedium)
        .background(Theme.cardBackground)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }

    // MARK: - Heatmap Section

    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: Theme.paddingSmall) {
            HStack {
                Text("Muscle Heatmap")
                    .font(.system(size: 15, weight: .semibold))
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
            .padding(.horizontal, Theme.paddingSmall)

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
            VStack(alignment: .leading, spacing: Theme.paddingSmall) {
                Text("Recent PRs")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, Theme.paddingSmall)

                ForEach(recentPRs) { pr in
                    PRBadgeRow(pr: pr)
                }
            }
            .cardStyle()
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.paddingSmall) {
            Image(systemName: "trophy")
                .font(.system(size: 36))
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
