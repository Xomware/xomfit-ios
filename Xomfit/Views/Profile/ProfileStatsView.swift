import SwiftUI

struct ProfileStatsView: View {
    let totalWorkouts: Int
    let totalVolume: String
    let totalPRs: Int
    let recentPRs: [PersonalRecord]
    let muscleGroupSetsThisWeek: [String: Int]
    let muscleGroupSetsThisMonth: [String: Int]
    let volumeTrend: [ProfileViewModel.VolumeBucket]
    let workoutsPerWeek: [Int]
    let avgWorkoutsPerWeek: Double
    let topExercises: [ProfileViewModel.TopExercise]
    let prOfTheMonth: PersonalRecord?
    /// Current consecutive-day workout streak (#250).
    var currentStreak: Int = 0
    /// Longest streak across history (#250).
    var longestStreak: Int = 0
    /// Profile owner — used by the Body measurements link (#317). nil = link hidden.
    var userId: String? = nil
    /// Optional CTA fired from the "log your first workout" empty state (#311).
    /// When nil, the empty-state card hides its action button.
    var onStartWorkout: (() -> Void)? = nil

    @State private var heatmapFilter: HeatmapTimeFilter = .week

    /// Display unit for weight values. Stored values stay lbs.
    @AppStorage("weightUnit") private var weightUnitRaw: String = WeightUnit.lbs.rawValue
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .lbs }

    private var activeMuscleGroupSets: [String: Int] {
        switch heatmapFilter {
        case .week: return muscleGroupSetsThisWeek
        case .month: return muscleGroupSetsThisMonth
        }
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            // #311: when there are no workouts yet, surface a friendly empty
            // state above the (all-zero) cards so the screen doesn't feel
            // broken. Stats stay rendered below for context.
            if totalWorkouts == 0 {
                firstWorkoutEmptyState
            }
            StreakCard(currentStreak: currentStreak, longestStreak: longestStreak)
            statsCards
            bodyLink
            volumeTrendSection
            consistencySection
            topExercisesSection
            heatmapSection
            prSection
        }
        .padding(.horizontal, Theme.Spacing.md)
    }

    // MARK: - First-Workout Empty State (#311)

    private var firstWorkoutEmptyState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            XomEmptyState(
                icon: "dumbbell.fill",
                title: "No stats yet",
                subtitle: "Log your first workout to unlock stats.",
                ctaLabel: onStartWorkout != nil ? "Start Workout" : nil,
                ctaAction: onStartWorkout
            )
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No stats yet. Log your first workout to unlock stats.")
    }

    // MARK: - Body Measurements Link (#317)

    @ViewBuilder
    private var bodyLink: some View {
        if let userId, !userId.isEmpty {
            NavigationLink {
                MeasurementsView(userId: userId)
                    .hideTabBar()
            } label: {
                XomCard {
                    HStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "ruler")
                            .font(.title3)
                            .foregroundStyle(Theme.accent)
                            .frame(width: 32, height: 32)
                            .background(Theme.accentMuted)
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Body")
                                .font(Theme.fontSubheadline.weight(.semibold))
                                .foregroundStyle(Theme.textPrimary)
                            Text("Track weight, body fat, and measurements")
                                .font(Theme.fontSmall)
                                .foregroundStyle(Theme.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }
            .buttonStyle(PressableCardStyle())
            .accessibilityLabel("Body measurements")
            .accessibilityHint("Opens weight, body fat, and circumference tracker")
        }
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

    // MARK: - Volume Trend Section

    @ViewBuilder
    private var volumeTrendSection: some View {
        let totalVolume = volumeTrend.reduce(0) { $0 + $1.volume }
        if totalVolume > 0 {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Volume Trend (30d)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, Theme.Spacing.sm)

                VolumeTrendChart(buckets: volumeTrend)
                    .padding(.horizontal, Theme.Spacing.sm)
            }
            .cardStyle()
        }
    }

    // MARK: - Consistency Section

    @ViewBuilder
    private var consistencySection: some View {
        if !workoutsPerWeek.isEmpty && workoutsPerWeek.contains(where: { $0 > 0 }) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Text("Consistency")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text(String(format: "Avg %.1f/wk", avgWorkoutsPerWeek))
                        .font(Theme.fontSmall)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.horizontal, Theme.Spacing.sm)

                consistencyBars
                    .padding(.horizontal, Theme.Spacing.sm)
            }
            .cardStyle()
            .accessibilityElement(children: .combine)
            .accessibilityLabel(consistencyAccessibility)
        }
    }

    private var consistencyBars: some View {
        let maxCount = max(workoutsPerWeek.max() ?? 0, 1)
        return HStack(alignment: .bottom, spacing: Theme.Spacing.sm) {
            ForEach(Array(workoutsPerWeek.enumerated()), id: \.offset) { _, count in
                consistencyBar(count: count, maxCount: maxCount)
            }
        }
        .frame(height: 60)
    }

    private func consistencyBar(count: Int, maxCount: Int) -> some View {
        VStack(spacing: 4) {
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

    private var consistencyAccessibility: String {
        let detail = workoutsPerWeek
            .enumerated()
            .map { "Week \($0.offset + 1): \($0.element) workouts" }
            .joined(separator: ", ")
        return "Consistency. Average \(String(format: "%.1f", avgWorkoutsPerWeek)) workouts per week. \(detail)"
    }

    // MARK: - Top Exercises Section

    @ViewBuilder
    private var topExercisesSection: some View {
        if !topExercises.isEmpty {
            let maxVolume = topExercises.first?.volume ?? 0
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Top Exercises")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, Theme.Spacing.sm)

                ForEach(topExercises) { exercise in
                    TopExerciseRow(exercise: exercise, maxVolume: maxVolume)
                }
            }
            .cardStyle()
        }
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
        if recentPRs.isEmpty && prOfTheMonth == nil {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                if let pr = prOfTheMonth {
                    prOfTheMonthCard(pr: pr)
                }

                if !recentPRs.isEmpty {
                    Text("Recent PRs")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, Theme.Spacing.sm)

                    ForEach(recentPRs) { pr in
                        PRBadgeRow(pr: pr)
                    }
                }
            }
            .cardStyle()
        }
    }

    @ViewBuilder
    private func prOfTheMonthCard(pr: PersonalRecord) -> some View {
        let pctText: String? = {
            guard let prev = pr.previousBest, prev > 0 else { return nil }
            let pct = (pr.weight - prev) / prev * 100
            return String(format: "+%.1f%%", pct)
        }()

        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "crown.fill")
                    .foregroundStyle(Theme.prGold)
                XomMetricLabel("PR of the Month")
            }

            HStack(alignment: .firstTextBaseline) {
                Text(pr.exerciseName)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Spacer()
                if let pctText {
                    Text(pctText)
                        .font(Theme.fontNumberMedium)
                        .foregroundStyle(Theme.prGold)
                }
            }

            Text("\(pr.weight.formattedWeight(unit: weightUnit)) \(weightUnit.displayName) \u{00D7} \(pr.reps)")
                .font(Theme.fontNumberMedium)
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(Theme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .fill(Theme.prGold.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                        .strokeBorder(Theme.prGold.opacity(0.4), lineWidth: 0.5)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(prOfTheMonthAccessibility(pr: pr, pctText: pctText))
    }

    private func prOfTheMonthAccessibility(pr: PersonalRecord, pctText: String?) -> String {
        var parts = ["PR of the month: \(pr.exerciseName), \(pr.weight.formattedWeight(unit: weightUnit)) \(weightUnit.accessibilityName) for \(pr.reps) reps"]
        if let pctText {
            parts.append("\(pctText) improvement")
        }
        return parts.joined(separator: ", ")
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
