import SwiftUI
import Charts

struct XomProgressView: View {
    @Environment(AuthService.self) private var authService
    @State private var viewModel = ProgressViewModel()

    private var userId: String {
        authService.currentUser?.id.uuidString.lowercased() ?? ""
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                if viewModel.isLoading {
                    XomFitLoaderPulse()
                } else if viewModel.totalWorkouts == 0 {
                    emptyState
                } else {
                    contentView
                }
            }
            .navigationTitle("Progress")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        LeaderboardView()
                    } label: {
                        Image(systemName: "trophy.fill")
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .accessibilityLabel("Leaderboard")
                }
            }
        }
        .task {
            await viewModel.loadData(userId: userId)
        }
        .refreshable {
            await viewModel.loadData(userId: userId)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image("XomFitLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .opacity(0.6)

            Text("Log your first workout to see progress here")
                .font(Theme.fontBody)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Theme.Spacing.lg)
    }

    // MARK: - Content

    private var contentView: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                summaryCards
                liftProgressionSection
                weeklyVolumeSection
                muscleGroupSection
                recentPRsSection
            }
            .padding(Theme.Spacing.md)
        }
    }
}

// MARK: - Summary Cards

private struct SummaryCardsView: View {
    let totalWorkouts: Int
    let currentStreak: Int
    let formattedVolume: String
    let totalPRs: Int

    private let columns = [
        GridItem(.flexible(), spacing: Theme.Spacing.sm),
        GridItem(.flexible(), spacing: Theme.Spacing.sm),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: Theme.Spacing.sm) {
            CountUpStatCard(icon: "dumbbell.fill", count: totalWorkouts, label: "Workouts", iconColor: Theme.accent)
            CountUpStatCard(icon: "flame.fill", count: currentStreak, label: "Day Streak", iconColor: Theme.streak)
            StatCard(icon: "scalemass.fill", value: formattedVolume, label: "Volume")
            CountUpStatCard(icon: "trophy.fill", count: totalPRs, label: "PRs", iconColor: Theme.prGold)
        }
    }
}

private struct CountUpStatCard: View {
    let icon: String
    let count: Int
    let label: String
    let iconColor: Color

    var body: some View {
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
        .accessibilityLabel("\(label): \(count)")
    }
}

private struct StatCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        XomCard(padding: Theme.Spacing.sm) {
            XomStat(value, label: label, icon: icon, iconColor: Theme.accent)
                .padding(.vertical, Theme.Spacing.xs)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Lift Progression

private struct LiftProgressionChart: View {
    let dataPoints: [StrengthDataPoint]
    let exercises: [String]
    @Binding var selectedExercise: String
    @Binding var timeframe: ChartTimeframe

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("Strength Over Time")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)

                Spacer()

                if exercises.count > 1 {
                    Menu {
                        ForEach(exercises, id: \.self) { exercise in
                            Button(exercise) {
                                selectedExercise = exercise
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedExercise)
                                .font(Theme.fontCaption)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                        }
                        .foregroundStyle(Theme.accent)
                    }
                }
            }

            // Timeframe picker
            HStack(spacing: 6) {
                ForEach(ChartTimeframe.allCases) { tf in
                    Button {
                        withAnimation(.xomChill) { timeframe = tf }
                    } label: {
                        XomBadge(tf.rawValue, variant: .interactive, isActive: timeframe == tf)
                    }
                    .buttonStyle(.plain)
                }
            }

            if dataPoints.isEmpty {
                Text("No data for this exercise")
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 150, alignment: .center)
            } else {
                Chart(dataPoints) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Est. 1RM", point.estimated1RM)
                    )
                    .foregroundStyle(Theme.accent)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Est. 1RM", point.estimated1RM)
                    )
                    .foregroundStyle(Theme.accent)
                    .symbolSize(30)
                }
                .chartYAxisLabel("Est. 1RM (lbs)", position: .leading)
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Theme.hairline)
                        AxisValueLabel()
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Theme.hairline)
                        AxisValueLabel()
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .frame(height: 200)
            }
        }
        .cardStyle()
    }
}

// MARK: - Weekly Volume

private struct WeeklyVolumeChart: View {
    let data: [(label: String, volume: Double)]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Weekly Volume")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)

            Chart {
                ForEach(Array(data.enumerated()), id: \.offset) { _, item in
                    BarMark(
                        x: .value("Week", item.label),
                        y: .value("Volume", item.volume)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.accent, Theme.accentMuted],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(4)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Theme.hairline)
                    AxisValueLabel()
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .frame(height: 180)
        }
        .cardStyle()
    }
}

// MARK: - Muscle Group Breakdown

private struct MuscleGroupChart: View {
    let data: [(group: String, sets: Int)]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Muscle Groups")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)

            Chart {
                ForEach(Array(data.enumerated()), id: \.offset) { _, item in
                    BarMark(
                        x: .value("Sets", item.sets),
                        y: .value("Muscle", item.group)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.accent, Theme.accentMuted],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(4)
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Theme.hairline)
                    AxisValueLabel()
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .frame(height: CGFloat(max(data.count, 1)) * 32)
        }
        .cardStyle()
    }
}

// MARK: - XomProgressView Extensions

extension XomProgressView {
    fileprivate var summaryCards: some View {
        SummaryCardsView(
            totalWorkouts: viewModel.totalWorkouts,
            currentStreak: viewModel.currentStreak,
            formattedVolume: viewModel.formattedTotalVolume,
            totalPRs: viewModel.totalPRs
        )
    }

    fileprivate var liftProgressionSection: some View {
        LiftProgressionChart(
            dataPoints: viewModel.filteredStrengthData,
            exercises: viewModel.availableExercises,
            selectedExercise: Bindable(viewModel).selectedExercise,
            timeframe: Bindable(viewModel).chartTimeframe
        )
    }

    fileprivate var weeklyVolumeSection: some View {
        WeeklyVolumeChart(data: viewModel.weeklyVolumes)
    }

    @ViewBuilder
    fileprivate var muscleGroupSection: some View {
        if !viewModel.muscleGroupSets.isEmpty {
            MuscleGroupChart(data: viewModel.muscleGroupSets)
        }
    }

    @ViewBuilder
    fileprivate var recentPRsSection: some View {
        if !viewModel.recentPRs.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Recent PRs")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)

                ForEach(viewModel.recentPRs) { pr in
                    PRBadgeRow(pr: pr)
                }
            }
            .cardStyle()
        }
    }
}
