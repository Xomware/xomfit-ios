import SwiftUI

/// How many lifts sit in each tier, and what it would take to move them up.
///
/// The profile showed a distribution bar and a flat list of ranked lifts. It
/// answered "what am I" but not "how many of each" or "what is closest" — the
/// two questions a lifter actually has when looking at ranks.
///
/// Every tier is computed from the full personal-record history, so this is
/// backfilled by construction: there is no stored tier to migrate, and a lift
/// set years ago counts the same as one from this morning.
struct TierBreakdownSection: View {
    let personalRecords: [PersonalRecord]

    @State private var expandedTier: StrengthTier?

    private var strength: StrengthLevelService { .shared }

    private var rankedLifts: [StrengthLevelService.RankedLift] {
        strength.rankedLifts(from: personalRecords)
    }

    private var byTier: [StrengthTier: [StrengthLevelService.RankedLift]] {
        Dictionary(grouping: rankedLifts, by: \.rank.tier)
    }

    /// Strongest first — the tier a lifter is proudest of should not be at the
    /// bottom of a list they have to scroll.
    private var populatedTiers: [StrengthTier] {
        StrengthTier.ranked.reversed().filter { (byTier[$0]?.isEmpty == false) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Your Tiers")
                .font(Theme.fontHeadline)
                .foregroundStyle(Theme.textPrimary)

            if rankedLifts.isEmpty {
                Text("Log a few lifts to earn your first ranks.")
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                ForEach(populatedTiers) { tier in
                    tierRow(tier)
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }

    private func tierRow(_ tier: StrengthTier) -> some View {
        let lifts = byTier[tier] ?? []
        let isExpanded = expandedTier == tier

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                Haptics.selection()
                withAnimation(.xomSnappy) {
                    expandedTier = isExpanded ? nil : tier
                }
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    StrengthTierBadge(tier: tier, size: .small)

                    Text("\(lifts.count)")
                        .font(Theme.fontBodyEmphasized.monospacedDigit())
                        .foregroundStyle(Theme.textPrimary)

                    Text(lifts.count == 1 ? "lift" : "lifts")
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(.vertical, Theme.Spacing.sm)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(lifts.count) \(tier.displayName) lifts")
            .accessibilityHint(isExpanded ? "Collapses the list" : "Shows which lifts")

            if isExpanded {
                VStack(alignment: .leading, spacing: Theme.Spacing.tight) {
                    ForEach(lifts) { lift in
                        liftRow(lift)
                    }
                }
                .padding(.bottom, Theme.Spacing.sm)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func liftRow(_ lift: StrengthLevelService.RankedLift) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: Theme.Spacing.tight) {
                Text(lift.exerciseName)
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(lift.rank.estimated1RM.formattedWeight)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.textSecondary)
            }

            // The gap is stated in estimated 1RM, which is the unit the
            // thresholds are in. Left unlabelled it reads as bar weight and
            // makes the tier look wrong.
            if let prompt = lift.rank.nextTierPrompt {
                Text(prompt)
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
            }

            if let progress = lift.rank.progressToNext {
                ProgressView(value: progress)
                    .tint((lift.rank.nextTier ?? lift.rank.tier).color)
            }
        }
        .padding(.leading, Theme.Spacing.md)
        .accessibilityElement(children: .combine)
    }
}
