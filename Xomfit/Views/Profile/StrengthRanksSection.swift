import SwiftUI

/// Profile section showing where the lifter stands on the Bronze → God ladder.
///
/// The ranking engine (`StrengthLevelService`, `StrengthTier`,
/// `StrengthStandards`) and both display components (`TierDistributionView`,
/// `StrengthTierBadge`) already existed — they were only ever reachable from an
/// individual exercise's detail sheet, so a lifter had no way to see their
/// ladder as a whole. This is the profile-level view of it.
///
/// Ranks are bodyweight-relative, so they are only as good as the attributes
/// behind them. Two states matter and are handled distinctly:
///
///   * **No bodyweight** — nothing can be ranked at all. Show the prompt, not an
///     empty list, or the section reads as "you have no ranks" when the truth is
///     "we can't tell yet".
///   * **Provisional** — bodyweight is known but sex and/or age aren't, so
///     ranking falls back to midpoint standards. The rank shows, labelled, with
///     a way to fix it. Silently showing a confident Gold that's actually wrong
///     is how this feature loses trust on first view.
struct StrengthRanksSection: View {
    let personalRecords: [PersonalRecord]

    @State private var strength = StrengthLevelService.shared
    @State private var showLifterDetails = false
    @State private var isExpanded = false

    /// Lifts shown before the "show all" disclosure. Enough to see the shape of
    /// the ladder without turning the profile into a leaderboard.
    private static let collapsedLimit = 5

    private var rankedLifts: [StrengthLevelService.RankedLift] {
        strength.rankedLifts(from: personalRecords)
    }

    private var distribution: [StrengthTier: Int] {
        // Derived from the same pass as `rankedLifts`, so the bar and the list
        // can never disagree about how many Golds the lifter holds.
        var counts: [StrengthTier: Int] = [:]
        for lift in rankedLifts { counts[lift.rank.tier, default: 0] += 1 }
        return counts
    }

    private var visibleLifts: [StrengthLevelService.RankedLift] {
        isExpanded ? rankedLifts : Array(rankedLifts.prefix(Self.collapsedLimit))
    }

    /// Strongest tier the lifter holds on any lift — the headline number.
    private var topTier: StrengthTier? {
        rankedLifts.first?.rank.tier
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            header

            if strength.bodyweight <= 0 {
                needsBodyweightState
            } else if rankedLifts.isEmpty {
                emptyState
            } else {
                if strength.isProvisional {
                    provisionalNotice
                }

                TierDistributionView(distribution: distribution)

                VStack(spacing: Theme.Spacing.xs) {
                    ForEach(visibleLifts) { lift in
                        rankRow(lift)
                    }
                }

                if rankedLifts.count > Self.collapsedLimit {
                    showAllToggle
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .cardStyle()
        .sheet(isPresented: $showLifterDetails) {
            LifterDetailsSheet()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Strength Ranks")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            if let topTier {
                StrengthTierBadge(tier: topTier, size: .small)
            }
        }
    }

    // MARK: - Rows

    private func rankRow(_ lift: StrengthLevelService.RankedLift) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(lift.exerciseName)
                    .font(Theme.fontFootnote.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                // The next-tier target is the point of a rank — a label with no
                // visible next step is just decoration.
                if let prompt = lift.rank.nextTierPrompt {
                    Text(prompt)
                        .font(Theme.fontCaption2)
                        .foregroundStyle(Theme.textSecondary)
                } else if lift.rank.tier == .god {
                    Text("Top of the ladder")
                        .font(Theme.fontCaption2)
                        .foregroundStyle(lift.rank.tier.color)
                }
            }

            Spacer(minLength: Theme.Spacing.sm)

            StrengthTierBadge(tier: lift.rank.tier, size: .small)
        }
        .padding(.vertical, Theme.Spacing.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(lift.exerciseName), \(lift.rank.tier.displayName)"
                + (lift.rank.nextTierPrompt.map { ". \($0)" } ?? "")
        )
    }

    private var showAllToggle: some View {
        Button {
            Haptics.selection()
            withAnimation(.xomChill) { isExpanded.toggle() }
        } label: {
            HStack(spacing: 4) {
                Text(isExpanded ? "Show less" : "Show all \(rankedLifts.count)")
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption2.weight(.bold))
            }
            .font(Theme.fontCaption.weight(.semibold))
            .foregroundStyle(Theme.accent)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
    }

    // MARK: - States

    private var provisionalNotice: some View {
        Button {
            Haptics.selection()
            showLifterDetails = true
        } label: {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "person.crop.circle.badge.questionmark")
                Text("Provisional — add your sex and age for an accurate rank")
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .font(Theme.fontCaption)
            .foregroundStyle(Theme.accent)
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
    }

    private var needsBodyweightState: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Ranks are relative to your bodyweight, so we need that first.")
                .font(Theme.fontCaption)
                .foregroundStyle(Theme.textSecondary)

            Button {
                Haptics.selection()
                showLifterDetails = true
            } label: {
                Label("Add your details", systemImage: "person.crop.circle.badge.plus")
                    .font(Theme.fontCaption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
        }
    }

    private var emptyState: some View {
        Text("Log a few heavy sets to earn your first ranks.")
            .font(Theme.fontCaption)
            .foregroundStyle(Theme.textSecondary)
            .padding(.vertical, Theme.Spacing.xs)
    }
}

#Preview {
    ScrollView {
        StrengthRanksSection(personalRecords: PersonalRecord.mockPRs)
            .padding()
    }
    .background(Theme.background)
}
