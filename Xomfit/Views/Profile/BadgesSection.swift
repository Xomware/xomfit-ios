import SwiftUI

/// Profile section showing progression badges from `BadgeCatalog` (#320).
/// Renders a pill grid of all catalog entries; locked entries dim and show a
/// padlock overlay. Tapping a pill opens a detail sheet with the unlock criteria.
struct BadgesSection: View {
    let workouts: [Workout]
    let firstPRDate: Date?

    @State private var selectedBadge: ActivityBadge?

    private var unlockedIds: Set<String> {
        Set(BadgeEvaluator.unlocked(for: workouts, firstPRDate: firstPRDate).map(\.id))
    }

    private let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 96), spacing: Theme.Spacing.sm)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("Badges")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("\(unlockedIds.count) / \(BadgeCatalog.all.count)")
                    .font(Theme.fontSmall)
                    .foregroundStyle(Theme.textSecondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, Theme.Spacing.sm)

            LazyVGrid(columns: columns, spacing: Theme.Spacing.sm) {
                ForEach(BadgeCatalog.all) { badge in
                    BadgePill(
                        badge: badge,
                        isUnlocked: unlockedIds.contains(badge.id)
                    ) {
                        Haptics.selection()
                        selectedBadge = badge
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.sm)
        }
        .cardStyle()
        .sheet(item: $selectedBadge) { badge in
            BadgeDetailSheet(
                badge: badge,
                isUnlocked: unlockedIds.contains(badge.id)
            )
        }
    }
}

// MARK: - Badge Pill

private struct BadgePill: View {
    let badge: ActivityBadge
    let isUnlocked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isUnlocked ? Theme.accent.opacity(0.18) : Theme.surfaceElevated)
                        .frame(width: 44, height: 44)
                    Image(systemName: badge.iconSystemName)
                        .font(.title3)
                        .foregroundStyle(isUnlocked ? Theme.accent : Theme.textTertiary)
                    if !isUnlocked {
                        Image(systemName: "lock.fill")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Theme.textSecondary)
                            .padding(4)
                            .background(Circle().fill(Theme.background))
                            .offset(x: 16, y: 16)
                    }
                }

                Text(badge.title)
                    .font(Theme.fontSmall)
                    .foregroundStyle(isUnlocked ? Theme.textPrimary : Theme.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(.vertical, Theme.Spacing.xs)
            .frame(minHeight: 96)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityLabel(isUnlocked
            ? "\(badge.title), unlocked. \(badge.description)"
            : "\(badge.title), locked. \(badge.description)"
        )
    }
}

// MARK: - Badge Detail Sheet

private struct BadgeDetailSheet: View {
    let badge: ActivityBadge
    let isUnlocked: Bool

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: Theme.Spacing.lg) {
                    ZStack {
                        Circle()
                            .fill(isUnlocked ? Theme.accent.opacity(0.18) : Theme.surfaceElevated)
                            .frame(width: 120, height: 120)
                        Image(systemName: badge.iconSystemName)
                            .font(.system(size: 56))
                            .foregroundStyle(isUnlocked ? Theme.accent : Theme.textTertiary)
                    }
                    .padding(.top, Theme.Spacing.xl)

                    VStack(spacing: Theme.Spacing.sm) {
                        Text(badge.title)
                            .font(Theme.fontTitle)
                            .foregroundStyle(Theme.textPrimary)
                            .multilineTextAlignment(.center)

                        Text(badge.description)
                            .font(Theme.fontBody)
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Theme.Spacing.lg)
                    }

                    XomCard(padding: Theme.Spacing.md, variant: .elevated) {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            XomMetricLabel("Unlock criteria")
                            Text(criteriaDescription)
                                .font(Theme.fontBody)
                                .foregroundStyle(Theme.textPrimary)

                            HStack(spacing: 6) {
                                Image(systemName: isUnlocked ? "checkmark.seal.fill" : "lock.fill")
                                    .foregroundStyle(isUnlocked ? Theme.accent : Theme.textSecondary)
                                Text(isUnlocked ? "Unlocked" : "Locked")
                                    .font(Theme.fontSmall.weight(.semibold))
                                    .foregroundStyle(isUnlocked ? Theme.accent : Theme.textSecondary)
                            }
                            .padding(.top, Theme.Spacing.xs)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, Theme.Spacing.md)

                    Spacer()
                }
            }
            .navigationTitle("Badge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.accent)
                }
            }
        }
    }

    private var criteriaDescription: String {
        switch badge.unlockCriteria {
        case .firstWorkout:
            return "Log your first workout."
        case .streakDays(let days):
            return "Reach a \(days)-day workout streak."
        case .totalWorkouts(let n):
            return "Log \(n) total workouts."
        case .totalVolumeLbs(let lbs):
            let formatted: String
            if lbs >= 1000 {
                formatted = String(format: "%.0fk", lbs / 1000)
            } else {
                formatted = String(format: "%.0f", lbs)
            }
            return "Lift \(formatted) lbs total."
        case .firstPR:
            return "Set your first personal record."
        }
    }
}
