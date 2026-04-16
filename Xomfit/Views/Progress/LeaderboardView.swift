import SwiftUI

struct LeaderboardView: View {
    @Environment(AuthService.self) private var authService
    @State private var viewModel = LeaderboardViewModel()

    private var userId: String {
        authService.currentUser?.id.uuidString.lowercased() ?? ""
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                filterBar
                XomDivider()

                if viewModel.isLoading {
                    Spacer()
                    ProgressView().tint(Theme.accent)
                    Spacer()
                } else if let error = viewModel.errorMessage {
                    Spacer()
                    XomEmptyState(
                        icon: "exclamationmark.triangle",
                        title: "Failed to load",
                        subtitle: error,
                        ctaLabel: "Retry",
                        ctaAction: { Task { await viewModel.loadLeaderboard(userId: userId) } }
                    )
                    Spacer()
                } else if viewModel.entries.isEmpty {
                    Spacer()
                    XomEmptyState(
                        icon: "trophy",
                        title: "No data yet",
                        subtitle: "Complete workouts to appear on the leaderboard"
                    )
                    Spacer()
                } else {
                    leaderboardList
                }
            }
        }
        .navigationTitle("Leaderboard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .hideTabBar()
        .task {
            await viewModel.loadLeaderboard(userId: userId)
        }
        .onChange(of: viewModel.selectedMetric) { _, _ in
            Task { await viewModel.loadLeaderboard(userId: userId) }
        }
        .onChange(of: viewModel.selectedTimeframe) { _, _ in
            Task { await viewModel.loadLeaderboard(userId: userId) }
        }
        .onChange(of: viewModel.selectedScope) { _, _ in
            Task { await viewModel.loadLeaderboard(userId: userId) }
        }
        .onChange(of: viewModel.selectedMuscleGroup) { _, _ in
            Task { await viewModel.loadLeaderboard(userId: userId) }
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        VStack(spacing: 8) {
            // Metric + Timeframe row
            HStack(spacing: 8) {
                filterMenu(
                    label: viewModel.selectedMetric.rawValue,
                    icon: "chart.bar.fill"
                ) {
                    ForEach(LeaderboardMetric.allCases, id: \.self) { metric in
                        Button {
                            viewModel.selectedMetric = metric
                        } label: {
                            Label(metric.rawValue, systemImage: metricIcon(metric))
                        }
                    }
                }

                filterMenu(
                    label: viewModel.selectedTimeframe.rawValue,
                    icon: "calendar"
                ) {
                    ForEach(LeaderboardTimeframe.allCases, id: \.self) { tf in
                        Button {
                            viewModel.selectedTimeframe = tf
                        } label: {
                            Text(tf.rawValue)
                        }
                    }
                }

                filterMenu(
                    label: viewModel.selectedScope.rawValue,
                    icon: "person.2.fill"
                ) {
                    ForEach(LeaderboardScope.allCases, id: \.self) { scope in
                        Button {
                            viewModel.selectedScope = scope
                        } label: {
                            Text(scope.rawValue)
                        }
                    }
                }
            }

            // Muscle group filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Button { viewModel.selectedMuscleGroup = nil } label: {
                        XomBadge("All", variant: .interactive, isActive: viewModel.selectedMuscleGroup == nil)
                    }
                    .buttonStyle(.plain)
                    ForEach(MuscleGroup.allCases) { group in
                        Button { viewModel.selectedMuscleGroup = group } label: {
                            XomBadge(group.displayName, variant: .interactive, isActive: viewModel.selectedMuscleGroup == group)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.surface.opacity(0.5))
    }

    // MARK: - Leaderboard List

    private var leaderboardList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Podium for top 3
                if viewModel.entries.count >= 3 {
                    podiumView
                        .padding(.vertical, Theme.Spacing.md)
                }

                // Full list
                ForEach(viewModel.entries) { entry in
                    leaderboardRow(entry: entry)
                    if entry.id != viewModel.entries.last?.id {
                        XomDivider()
                            .padding(.leading, 60)
                    }
                }
            }
        }
    }

    // MARK: - Podium

    private var podiumView: some View {
        HStack(alignment: .bottom, spacing: Theme.Spacing.md) {
            if viewModel.entries.count >= 2 {
                podiumColumn(entry: viewModel.entries[1], height: 80)
            }
            if !viewModel.entries.isEmpty {
                podiumColumn(entry: viewModel.entries[0], height: 110)
            }
            if viewModel.entries.count >= 3 {
                podiumColumn(entry: viewModel.entries[2], height: 60)
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
    }

    private func podiumColumn(entry: LeaderboardEntry, height: CGFloat) -> some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text(entry.badge ?? "")
                .font(.title)

            XomAvatar(name: entry.displayName, size: entry.rank == 1 ? 56 : 44)

            Text(entry.displayName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)

            Text(entry.scoreFormatted)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Theme.accent)

            RoundedRectangle(cornerRadius: 8)
                .fill(entry.rank == 1 ? Theme.accent.opacity(0.3) : Theme.surface)
                .frame(height: height)
                .overlay(
                    Text("#\(entry.rank)")
                        .font(Theme.fontDisplay)
                        .foregroundStyle(entry.rank == 1 ? Theme.accent : Theme.textSecondary)
                )
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Row

    private func leaderboardRow(entry: LeaderboardEntry) -> some View {
        let isCurrentUser = entry.userId == userId
        return HStack(spacing: 0) {
            // Current-user leading accent stripe
            if isCurrentUser {
                Rectangle()
                    .fill(Theme.accent)
                    .frame(width: 3)
            }

            HStack(spacing: Theme.Spacing.sm) {
                // Rank number at fontNumberLarge
                Text("\(entry.rank)")
                    .font(Theme.fontNumberLarge)
                    .foregroundStyle(entry.rank <= 3 ? Theme.accent : Theme.textSecondary)
                    .frame(width: 36, alignment: .center)

                XomAvatar(name: entry.displayName, size: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.displayName)
                        .font(.subheadline.weight(isCurrentUser ? .bold : .medium))
                        .foregroundStyle(isCurrentUser ? Theme.textPrimary : Theme.textPrimary)
                        .lineLimit(1)

                    if entry.rankChange != 0 {
                        Text(entry.rankChangeSymbol)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(entry.rankChange > 0 ? Theme.accent : Theme.destructive)
                    }
                }

                Spacer()

                Text(entry.scoreFormatted)
                    .font(Theme.fontNumberMedium)
                    .foregroundStyle(Theme.textPrimary)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
        }
        .background(isCurrentUser ? Theme.accent.opacity(0.06) : .clear)
    }

    // MARK: - Helpers

    private func filterMenu<Content: View>(
        label: String,
        icon: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        Menu {
            content()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(label)
                    .font(.caption.weight(.semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Theme.surface)
            .clipShape(.capsule)
        }
    }

    private func metricIcon(_ metric: LeaderboardMetric) -> String {
        switch metric {
        case .weeklyVolume: return "scalemass"
        case .personalRecords: return "trophy.fill"
        case .workoutStreak: return "flame.fill"
        case .totalWorkouts: return "figure.strengthtraining.traditional"
        }
    }
}
