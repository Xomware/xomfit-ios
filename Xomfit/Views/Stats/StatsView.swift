import SwiftUI

// MARK: - Stats Sections

/// Jump-to sections surfaced in the pill nav. `friends` is only shown when the
/// user actually has friends to compare against.
private enum StatsSection: String, CaseIterable, Identifiable {
    case overview
    case balance
    case volume
    case consistency
    case topLifts
    case bodyMap
    case prs
    case friends

    var id: String { rawValue }

    /// Distinct scroll anchor for the content section. Kept separate from `id`
    /// (which the pill `ForEach` reuses) so `scrollTo` doesn't ambiguously match
    /// the pill in the horizontal scroller instead of the content section.
    var anchorId: String { "section-\(rawValue)" }

    var pillTitle: String {
        switch self {
        case .overview:    "Overview"
        case .balance:     "Balance"
        case .volume:      "Volume"
        case .consistency: "Consistency"
        case .topLifts:    "Top Lifts"
        case .bodyMap:     "Body Map"
        case .prs:         "PRs"
        case .friends:     "Friends"
        }
    }

    var icon: String {
        switch self {
        case .overview:    "square.grid.2x2.fill"
        case .balance:     "hexagon.fill"
        case .volume:      "chart.bar.fill"
        case .consistency: "calendar"
        case .topLifts:    "list.number"
        case .bodyMap:     "figure.stand"
        case .prs:         "trophy.fill"
        case .friends:     "person.2.fill"
        }
    }
}

// MARK: - StatsView

/// Full stats hub reachable from the drawer (Stats destination) and pushed from
/// the profile "See All Stats" link. Scroll-based with a sticky pill nav that
/// jumps to each section.
struct StatsView: View {
    @Environment(AuthService.self) private var authService
    @State private var viewModel = StatsViewModel()

    /// Display unit for weight values. Stored values stay lbs.
    @AppStorage("weightUnit") private var weightUnitRaw: String = WeightUnit.lbs.rawValue
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .lbs }

    private var userId: String? {
        authService.currentUser?.id.uuidString.lowercased()
    }

    /// Sections actually rendered — friends section is conditional.
    private var visibleSections: [StatsSection] {
        StatsSection.allCases.filter { $0 != .friends || viewModel.hasFriends }
    }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                if viewModel.hasData {
                    sectionPills(proxy: proxy)
                }

                ScrollView {
                    if viewModel.isLoading && !viewModel.hasData {
                        loadingState
                    } else if !viewModel.hasData {
                        emptyState
                    } else {
                        content
                    }
                }
                .stats_autoScroll(proxy: proxy, ready: viewModel.hasData)
            }
        }
        .background(Theme.background)
        .task(id: userId) {
            guard let userId else { return }
            await viewModel.load(userId: userId)
        }
    }

    // MARK: - Pill Nav

    private func sectionPills(proxy: ScrollViewProxy) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(visibleSections) { section in
                    Button {
                        Haptics.selection()
                        withAnimation(.xomConfident) {
                            proxy.scrollTo(section.anchorId, anchor: .top)
                        }
                    } label: {
                        HStack(spacing: Theme.Spacing.tight) {
                            Image(systemName: section.icon)
                                .font(.caption2.weight(.semibold))
                            Text(section.pillTitle)
                                .font(.caption.weight(.semibold))
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(
                            Capsule().fill(Theme.surfaceElevated)
                        )
                        .overlay(
                            Capsule().strokeBorder(Theme.hairline, lineWidth: 0.5)
                        )
                        .foregroundStyle(Theme.textPrimary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Jump to \(section.pillTitle)")
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
        }
        .background(Theme.background)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.hairline).frame(height: 0.5)
        }
    }

    // MARK: - Content

    private var content: some View {
        VStack(spacing: Theme.Spacing.lg) {
            quickStatsSection
                .id(StatsSection.overview.anchorId)
            radarSection
                .id(StatsSection.balance.anchorId)
            volumeSection
                .id(StatsSection.volume.anchorId)
            consistencySection
                .id(StatsSection.consistency.anchorId)
            topExercisesSection
                .id(StatsSection.topLifts.anchorId)
            heatmapSection
                .id(StatsSection.bodyMap.anchorId)
            prSection
                .id(StatsSection.prs.anchorId)
            if viewModel.hasFriends {
                friendSection
                    .id(StatsSection.friends.anchorId)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.md)
    }

    // MARK: - Quick Stats

    private var quickStatsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionHeader("Quick Stats", systemImage: "square.grid.2x2.fill")

            HStack(spacing: Theme.Spacing.sm) {
                statCard(icon: "dumbbell.fill", count: viewModel.totalWorkouts, label: "Workouts", iconColor: Theme.accent)
                XomCard(padding: Theme.Spacing.sm) {
                    VStack(spacing: Theme.Spacing.tight) {
                        Image(systemName: "scalemass.fill")
                            .font(Theme.fontHeadline)
                            .foregroundStyle(Theme.accent)
                        Text(viewModel.formattedVolume)
                            .font(Theme.fontNumberLarge)
                            .foregroundStyle(Theme.textPrimary)
                        XomMetricLabel("Volume")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.xs)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(viewModel.formattedVolume) volume")
            }

            HStack(spacing: Theme.Spacing.sm) {
                statCard(icon: "trophy.fill", count: viewModel.totalPRs, label: "PRs", iconColor: Theme.prGold)
                statCard(icon: "flame.fill", count: viewModel.currentStreak, label: "Streak", iconColor: Theme.streak)
            }
        }
    }

    private func statCard(icon: String, count: Int, label: String, iconColor: Color) -> some View {
        XomCard(padding: Theme.Spacing.sm) {
            VStack(spacing: Theme.Spacing.tight) {
                Image(systemName: icon)
                    .font(Theme.fontHeadline)
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

    // MARK: - Radar

    private var radarSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionHeader("Muscle Balance", systemImage: "hexagon.fill")

            VStack(spacing: Theme.Spacing.sm) {
                RadarChartView(
                    data: Dictionary(uniqueKeysWithValues: viewModel.radarAxes.map { ($0.name, $0.value) }),
                    axisOrder: StatsViewModel.axisOrder
                )
                .frame(height: 280)
                .padding(.top, Theme.Spacing.sm)

                Text("Relative training volume by muscle group")
                    .font(Theme.fontSmall)
                    .foregroundStyle(Theme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .cardStyle()
        }
    }

    // MARK: - Volume

    @ViewBuilder
    private var volumeSection: some View {
        let total = viewModel.volumeTrend.reduce(0) { $0 + $1.volume }
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionHeader("Volume Trend", systemImage: "chart.bar.fill")

            if total > 0 {
                VolumeTrendChart(buckets: viewModel.volumeTrend)
                    .padding(Theme.Spacing.sm)
                    .cardStyle()
            } else {
                placeholderCard("Log a few workouts to see your volume trend.")
            }
        }
    }

    // MARK: - Consistency

    @ViewBuilder
    private var consistencySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                sectionHeader("Consistency", systemImage: "calendar")
                Spacer()
                Text(String(format: "Avg %.1f/wk", viewModel.avgWorkoutsPerWeek))
                    .font(Theme.fontSmall)
                    .foregroundStyle(Theme.textSecondary)
            }

            if viewModel.workoutsPerWeek.contains(where: { $0 > 0 }) {
                consistencyBars
                    .padding(Theme.Spacing.sm)
                    .cardStyle()
            } else {
                placeholderCard("No workouts logged in the last 4 weeks.")
            }
        }
    }

    private var consistencyBars: some View {
        let maxCount = max(viewModel.workoutsPerWeek.max() ?? 0, 1)
        return HStack(alignment: .bottom, spacing: Theme.Spacing.sm) {
            ForEach(Array(viewModel.workoutsPerWeek.enumerated()), id: \.offset) { _, count in
                VStack(spacing: Theme.Spacing.tight) {
                    GeometryReader { proxy in
                        VStack {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(count > 0 ? Theme.accent : Theme.hairline)
                                .frame(height: max(4, proxy.size.height * CGFloat(count) / CGFloat(maxCount)))
                        }
                    }
                    Text("\(count)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 80)
    }

    // MARK: - Top Exercises

    @ViewBuilder
    private var topExercisesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionHeader("Top Exercises", systemImage: "list.number")

            if viewModel.topExercises.isEmpty {
                placeholderCard("Your most-trained lifts will appear here.")
            } else {
                let maxVolume = viewModel.topExercises.first?.volume ?? 0
                VStack(spacing: 0) {
                    ForEach(viewModel.topExercises) { exercise in
                        TopExerciseRow(exercise: exercise, maxVolume: maxVolume)
                    }
                }
                .padding(.vertical, Theme.Spacing.xs)
                .cardStyle()
            }
        }
    }

    // MARK: - Heatmap

    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionHeader("Body Heatmap", systemImage: "figure.stand")
            FullBodyHeatmapView(workouts: viewModel.workouts)
        }
    }

    // MARK: - PRs

    @ViewBuilder
    private var prSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionHeader("Recent PRs", systemImage: "trophy.fill")

            if viewModel.recentPRs.isEmpty {
                placeholderCard("Hit a new personal record to see it here.")
            } else {
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(viewModel.recentPRs) { pr in
                        PRBadgeRow(pr: pr)
                    }
                }
                .padding(.vertical, Theme.Spacing.sm)
                .cardStyle()
            }
        }
    }

    // MARK: - Friends

    private var friendSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionHeader("Friend Comparison", systemImage: "person.2.fill")

            FriendComparisonView(
                myStats: viewModel.myComparison,
                friends: viewModel.friends,
                loadFriend: { friendId in
                    await viewModel.loadFriendComparison(friendId: friendId)
                }
            )
        }
    }

    // MARK: - Shared Pieces

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.horizontal, Theme.Spacing.tight)
    }

    private func placeholderCard(_ message: String) -> some View {
        Text(message)
            .font(Theme.fontSmall)
            .foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
            .cardStyle()
    }

    private var loadingState: some View {
        VStack(spacing: Theme.Spacing.md) {
            ForEach(0..<4, id: \.self) { _ in
                SkeletonCard(height: 100)
            }
        }
        .padding(Theme.Spacing.md)
    }

    private var emptyState: some View {
        XomEmptyState(
            icon: "chart.bar.fill",
            title: "No stats yet",
            subtitle: "Log your first workout to unlock your stats."
        )
        .padding(.top, Theme.Spacing.xxl)
    }
}

// MARK: - Debug Auto-Scroll (agent UI verification)
//
// Mirrors the `XOMFIT_INITIAL_DESTINATION` / `XOMFIT_DRAWER_OPEN` affordances
// (#372): when `XOMFIT_STATS_SECTION=<rawValue>` is set, the hub auto-scrolls
// to that section once data loads so agents can screenshot any section from a
// cold launch without scripting touches. Compiles out of Release builds.

private extension View {
    @ViewBuilder
    func stats_autoScroll(proxy: ScrollViewProxy, ready: Bool) -> some View {
        #if DEBUG
        self.task(id: ready) {
            guard ready,
                  let raw = ProcessInfo.processInfo.environment["XOMFIT_STATS_SECTION"]
            else { return }
            try? await Task.sleep(for: .milliseconds(500))
            withAnimation { proxy.scrollTo("section-\(raw)", anchor: .top) }
        }
        #else
        self
        #endif
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        StatsView()
            .environment(AuthService())
    }
    .preferredColorScheme(.dark)
}
#endif
