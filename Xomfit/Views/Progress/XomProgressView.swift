import SwiftUI
import Charts

struct XomProgressView: View {
    @Environment(AuthService.self) private var authService
    @State private var viewModel = ProgressViewModel()

    private var userId: String {
        authService.currentUser?.id.uuidString ?? ""
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
        VStack(spacing: Theme.paddingMedium) {
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
        .padding(Theme.paddingLarge)
    }

    // MARK: - Content

    private var contentView: some View {
        ScrollView {
            VStack(spacing: Theme.paddingMedium) {
                summaryCards
                liftProgressionSection
                weeklyVolumeSection
                muscleGroupSection
                recentPRsSection
            }
            .padding(Theme.paddingMedium)
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
        GridItem(.flexible(), spacing: Theme.paddingSmall),
        GridItem(.flexible(), spacing: Theme.paddingSmall),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: Theme.paddingSmall) {
            StatCard(icon: "dumbbell.fill", value: "\(totalWorkouts)", label: "Workouts")
            StatCard(icon: "flame.fill", value: "\(currentStreak)", label: "Day Streak")
            StatCard(icon: "scalemass.fill", value: formattedVolume, label: "Volume")
            StatCard(icon: "trophy.fill", value: "\(totalPRs)", label: "PRs")
        }
    }
}

private struct StatCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Theme.accent)

            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.textPrimary)

            Text(label)
                .font(Theme.fontSmall)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.paddingMedium)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Lift Progression

private struct LiftProgressionChart: View {
    let dataPoints: [StrengthDataPoint]
    let exercises: [String]
    @Binding var selectedExercise: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.paddingSmall) {
            HStack {
                Text("Strength Over Time")
                    .font(.system(size: 15, weight: .semibold))
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
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(Theme.accent)
                    }
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
                            .foregroundStyle(Theme.textSecondary.opacity(0.3))
                        AxisValueLabel()
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Theme.textSecondary.opacity(0.3))
                        AxisValueLabel()
                            .foregroundStyle(Theme.textSecondary)
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
        VStack(alignment: .leading, spacing: Theme.paddingSmall) {
            Text("Weekly Volume")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            Chart {
                ForEach(Array(data.enumerated()), id: \.offset) { _, item in
                    BarMark(
                        x: .value("Week", item.label),
                        y: .value("Volume", item.volume)
                    )
                    .foregroundStyle(Theme.accent)
                    .cornerRadius(4)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Theme.textSecondary.opacity(0.3))
                    AxisValueLabel()
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .foregroundStyle(Theme.textSecondary)
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
        VStack(alignment: .leading, spacing: Theme.paddingSmall) {
            Text("Muscle Groups")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            Chart {
                ForEach(Array(data.enumerated()), id: \.offset) { _, item in
                    BarMark(
                        x: .value("Sets", item.sets),
                        y: .value("Muscle", item.group)
                    )
                    .foregroundStyle(Theme.accent)
                    .cornerRadius(4)
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Theme.textSecondary.opacity(0.3))
                    AxisValueLabel()
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .foregroundStyle(Theme.textSecondary)
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
            selectedExercise: Bindable(viewModel).selectedExercise
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
            VStack(alignment: .leading, spacing: Theme.paddingSmall) {
                Text("Recent PRs")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)

                ForEach(viewModel.recentPRs) { pr in
                    PRBadgeRow(pr: pr)
                }
            }
            .cardStyle()
        }
    }
}
