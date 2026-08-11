import SwiftUI

/// Compact tier chip — used on exercise cards and in lists.
struct StrengthTierBadge: View {
    let tier: StrengthTier
    var size: Size = .regular

    enum Size {
        case small, regular

        var font: Font {
            switch self {
            case .small:   return Theme.fontCaption2.weight(.bold)
            case .regular: return Theme.fontCaption.weight(.bold)
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .small:   return 9
            case .regular: return 11
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .small:   return Theme.Spacing.xs
            case .regular: return Theme.Spacing.sm
            }
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: tier.icon)
                .font(.system(size: size.iconSize, weight: .bold))
            Text(tier.displayName.uppercased())
                .font(size.font)
        }
        .foregroundStyle(tier == .unranked ? tier.color : .black.opacity(0.85))
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, 3)
        .background {
            if tier == .unranked {
                Capsule().stroke(tier.color.opacity(0.5), lineWidth: 1)
            } else {
                Capsule().fill(tier.gradient)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(tier.displayName) tier")
    }
}

/// Full rank card for the exercise detail sheet: current tier, the weight that
/// unlocks the next one, and a bar showing how far through the band the lifter
/// is. The next-tier target is the point of the whole feature — a rank with no
/// visible next step is just a label.
struct StrengthRankCard: View {
    let exerciseName: String
    let rank: StrengthRank
    /// Set when ranking used assumed attributes, so the card can offer to fix it.
    var isProvisional: Bool = false
    var onProvideDetails: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your rank")
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)
                    Text(rank.tier.displayName)
                        .font(Theme.fontTitle2.weight(.bold))
                        .foregroundStyle(rank.tier.color)
                }
                Spacer()
                Image(systemName: rank.tier.icon)
                    .font(.system(size: 34))
                    .foregroundStyle(rank.tier.gradient)
            }

            Text(rank.tier.blurb)
                .font(Theme.fontCaption)
                .foregroundStyle(Theme.textSecondary)

            if let prompt = rank.nextTierPrompt, let progress = rank.progressToNext {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    HStack {
                        Text(prompt)
                            .font(Theme.fontFootnote.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        if let next = rank.nextTier {
                            StrengthTierBadge(tier: next, size: .small)
                                .opacity(0.85)
                        }
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Theme.textSecondary.opacity(0.18))
                            Capsule()
                                .fill((rank.nextTier ?? rank.tier).gradient)
                                .frame(width: max(4, geo.size.width * progress))
                        }
                    }
                    .frame(height: 6)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(prompt)
            } else if rank.tier == .god {
                Text("Top of the ladder. Nothing left to chase here.")
                    .font(Theme.fontFootnote.weight(.semibold))
                    .foregroundStyle(rank.tier.color)
            }

            if isProvisional {
                Button {
                    onProvideDetails?()
                } label: {
                    Label("Add your details for an accurate rank", systemImage: "person.crop.circle.badge.questionmark")
                        .font(Theme.fontCaption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.accent)
                .frame(minHeight: 44)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.md))
        .accessibilityHint("Strength rank for \(exerciseName)")
    }
}

/// Tier breakdown across all ranked lifts — the profile-level view of where a
/// lifter stands overall.
struct TierDistributionView: View {
    let distribution: [StrengthTier: Int]

    private var total: Int { distribution.values.reduce(0, +) }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Strength ranks")
                .font(Theme.fontHeadline)
                .foregroundStyle(Theme.textPrimary)

            if total == 0 {
                Text("Log a few lifts to earn your first ranks.")
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                ForEach(StrengthTier.ranked.reversed()) { tier in
                    let count = distribution[tier] ?? 0
                    if count > 0 {
                        HStack(spacing: Theme.Spacing.sm) {
                            StrengthTierBadge(tier: tier, size: .small)
                            GeometryReader { geo in
                                Capsule()
                                    .fill(tier.gradient)
                                    .frame(width: max(6, geo.size.width * (Double(count) / Double(total))))
                            }
                            .frame(height: 8)
                            Text("\(count)")
                                .font(Theme.fontCaption.monospacedDigit())
                                .foregroundStyle(Theme.textSecondary)
                                .frame(width: 24, alignment: .trailing)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(count) \(tier.displayName) lifts")
                    }
                }
            }
        }
    }
}
