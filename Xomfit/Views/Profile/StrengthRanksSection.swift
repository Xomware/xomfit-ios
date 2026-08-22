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
    /// The lifter's own PRs. Empty when viewing someone else — their records are
    /// private (`personal_records` is `user_id = auth.uid()`), which is exactly
    /// why published ranks exist.
    var personalRecords: [PersonalRecord] = []
    /// Whose profile this is. Drives which source the ranks come from.
    let profileUserId: String
    let isOwnProfile: Bool

    @State private var strength = StrengthLevelService.shared
    @State private var rankService = StrengthRankService.shared
    @State private var showLifterDetails = false
    @State private var isExpanded = false

    /// Lifts shown before the "show all" disclosure. Enough to see the shape of
    /// the ladder without turning the profile into a leaderboard.
    private static let collapsedLimit = 5

    private var rankedLifts: [StrengthLevelService.RankedLift] {
        strength.rankedLifts(from: personalRecords)
    }

    /// Ranks published by whoever's profile this is. Used for other lifters,
    /// where the PRs behind the rank are not readable.
    private var publishedRanks: [PublishedRank] {
        rankService.ranks(for: profileUserId)
    }

    /// One shape for both sources. The next-tier target is own-profile only —
    /// "25 lb from Gold" would leak the weights the tier deliberately hides.
    private struct Row: Identifiable {
        let id: String
        let exerciseName: String
        let tier: StrengthTier
        let nextTierPrompt: String?
        let isTopOfLadder: Bool
    }

    private var rows: [Row] {
        if isOwnProfile {
            return rankedLifts.map {
                Row(
                    id: $0.exerciseId,
                    exerciseName: $0.exerciseName,
                    tier: $0.rank.tier,
                    nextTierPrompt: $0.rank.nextTierPrompt,
                    isTopOfLadder: $0.rank.tier == .god
                )
            }
        }
        return publishedRanks.map {
            Row(
                id: $0.exerciseId,
                exerciseName: $0.exerciseName,
                tier: $0.tier,
                nextTierPrompt: nil,
                isTopOfLadder: $0.tier == .god
            )
        }
    }

    private var distribution: [StrengthTier: Int] {
        // Derived from the same rows the list renders, so the bar and the list
        // can never disagree about how many Golds the lifter holds.
        var counts: [StrengthTier: Int] = [:]
        for row in rows { counts[row.tier, default: 0] += 1 }
        return counts
    }

    private var visibleRows: [Row] {
        isExpanded ? rows : Array(rows.prefix(Self.collapsedLimit))
    }

    /// Strongest tier the lifter holds on any lift — the headline number.
    private var topTier: StrengthTier? {
        rows.first?.tier
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            header

            if isOwnProfile && strength.bodyweight <= 0 {
                needsBodyweightState
            } else if rows.isEmpty {
                emptyState
            } else {
                // Provisional only applies to ranks computed here. Another
                // lifter's ranks were computed on their device against their
                // own attributes, so this viewer's missing details are irrelevant.
                if isOwnProfile && strength.isProvisional {
                    provisionalNotice
                }

                TierDistributionView(distribution: distribution)

                VStack(spacing: Theme.Spacing.xs) {
                    ForEach(visibleRows) { row in
                        rankRow(row)
                    }
                }

                if rows.count > Self.collapsedLimit {
                    showAllToggle
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .cardStyle()
        .sheet(isPresented: $showLifterDetails) {
            LifterDetailsSheet()
        }
        .task(id: profileUserId) {
            if isOwnProfile {
                // Publishing here rather than on every rank computation: this is
                // the one place the lifter's full PR history is already loaded,
                // and it re-runs whenever they open their profile.
                await rankService.publish(rankedLifts, userId: profileUserId)
            } else {
                await rankService.fetchRanks(userId: profileUserId)
            }
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

    private func rankRow(_ row: Row) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.exerciseName)
                    .font(Theme.fontFootnote.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                // The next-tier target is the point of a rank — a label with no
                // visible next step is just decoration. Own profile only.
                if let prompt = row.nextTierPrompt {
                    Text(prompt)
                        .font(Theme.fontCaption2)
                        .foregroundStyle(Theme.textSecondary)
                } else if row.isTopOfLadder {
                    Text("Top of the ladder")
                        .font(Theme.fontCaption2)
                        .foregroundStyle(row.tier.color)
                }
            }

            Spacer(minLength: Theme.Spacing.sm)

            StrengthTierBadge(tier: row.tier, size: .small)
        }
        .padding(.vertical, Theme.Spacing.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(row.exerciseName), \(row.tier.displayName)"
                + (row.nextTierPrompt.map { ". \($0)" } ?? "")
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
        Text(isOwnProfile ? "Log a few heavy sets to earn your first ranks." : "No ranks yet.")
            .font(Theme.fontCaption)
            .foregroundStyle(Theme.textSecondary)
            .padding(.vertical, Theme.Spacing.xs)
    }
}

#Preview {
    ScrollView {
        StrengthRanksSection(
            personalRecords: PersonalRecord.mockPRs,
            profileUserId: "preview-user",
            isOwnProfile: true
        )
            .padding()
    }
    .background(Theme.background)
}
