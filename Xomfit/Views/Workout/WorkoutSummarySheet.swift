import SwiftUI

/// Post-workout recap, shown once after a session is saved.
///
/// The numbers alone are already in workout history, so they are not the point
/// — the achievements are. PRs and tier promotions are announced mid-set by a
/// banner that auto-dismisses in five seconds and is easy to miss under a bar,
/// and badge unlocks were never announced at all. This is the one place a
/// lifter reliably sees what the session earned them.
struct WorkoutSummarySheet: View {
    let summary: WorkoutSummary
    let onDone: () -> Void

    @AppStorage("weightUnit") private var weightUnitRaw: String = WeightUnit.lbs.rawValue
    private var unitLabel: String {
        (WeightUnit(rawValue: weightUnitRaw) ?? .lbs).displayName
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        header
                        statsGrid

                        if summary.hasAchievements {
                            achievements
                        }
                    }
                    .padding(Theme.Spacing.md)
                }
            }
            .navigationTitle("Workout Complete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { onDone() }
                        .foregroundStyle(Theme.accent)
                        .fontWeight(.semibold)
                }
            }
        }
        .interactiveDismissDisabled()
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(Theme.accent)

            Text(summary.workoutName)
                .font(Theme.fontTitle2.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, Theme.Spacing.md)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Stats

    private var statsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: Theme.Spacing.sm
        ) {
            statTile("Time", summary.durationString, icon: "clock.fill")
            statTile("Volume", "\(summary.volumeString) \(unitLabel)", icon: "scalemass.fill")
            statTile("Sets", "\(summary.totalSets)", icon: "list.number")
            statTile("Exercises", "\(summary.exerciseCount)", icon: "dumbbell.fill")

            // Only shown when it happened at all — a permanent "0" tile turns a
            // recap into a scoreboard the lifter is losing.
            if summary.beatTheClockSets > 0 {
                statTile(
                    "Beat the clock",
                    "\(summary.beatTheClockSets)",
                    icon: "timer"
                )
            }
        }
    }

    private func statTile(_ label: String, _ value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.tighter) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(Theme.accent)
                Text(label.uppercased())
                    .font(Theme.fontMetricLabel)
                    .kerning(0.6)
                    .foregroundStyle(Theme.textTertiary)
            }
            Text(value)
                .font(Theme.fontTitle3.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.md))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - Achievements

    private var achievements: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Earned this session")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)

            // Ordered rarest-first: tier promotions move a handful of times a
            // year, PRs move most weeks.
            ForEach(Array(summary.tierUps.enumerated()), id: \.offset) { _, tierUp in
                achievementRow(
                    icon: tierUp.tier.icon,
                    tint: tierUp.tier.color,
                    title: "\(tierUp.tier.displayName) — \(tierUp.exerciseName)",
                    detail: tierUp.tier.blurb
                )
            }

            ForEach(summary.personalRecords) { pr in
                achievementRow(
                    icon: "trophy.fill",
                    tint: Theme.prGold,
                    title: pr.exerciseName,
                    detail: "\(pr.weight.formattedWeight) \(unitLabel) × \(pr.reps)"
                )
            }

            ForEach(summary.newBadges) { badge in
                achievementRow(
                    icon: badge.iconSystemName,
                    tint: Theme.accent,
                    title: badge.title,
                    detail: badge.description
                )
            }
        }
    }

    private func achievementRow(
        icon: String,
        tint: Color,
        title: String,
        detail: String
    ) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.fontFootnote.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(detail)
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.md))
        .accessibilityElement(children: .combine)
    }
}
