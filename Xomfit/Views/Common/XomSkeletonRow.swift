import SwiftUI

struct XomSkeletonRow: View {
    var style: SkeletonStyle = .card

    enum SkeletonStyle {
        case card
        case feedPost
        case profileHeader
        case stat
    }

    var body: some View {
        Group {
            switch style {
            case .card:
                cardSkeleton
            case .feedPost:
                feedPostSkeleton
            case .profileHeader:
                profileHeaderSkeleton
            case .stat:
                statSkeleton
            }
        }
        .shimmer()
    }

    private var cardSkeleton: some View {
        RoundedRectangle(cornerRadius: Theme.cornerRadius)
            .fill(Theme.surface)
            .frame(height: 80)
    }

    private var feedPostSkeleton: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Header row
            HStack(spacing: Theme.Spacing.sm) {
                Circle()
                    .fill(Theme.surfaceElevated)
                    .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.surfaceElevated)
                        .frame(width: 120, height: 14)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.surfaceElevated)
                        .frame(width: 80, height: 10)
                }
                Spacer()
            }

            // Content area
            RoundedRectangle(cornerRadius: 8)
                .fill(Theme.surfaceElevated)
                .frame(height: Theme.Spacing.md)
            RoundedRectangle(cornerRadius: 8)
                .fill(Theme.surfaceElevated)
                .frame(width: 200, height: 16)

            // Stats row
            HStack(spacing: Theme.Spacing.md) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Theme.surfaceElevated)
                        .frame(height: 40)
                }
            }

            // Action bar
            HStack {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.surfaceElevated)
                        .frame(width: 60, height: 20)
                }
                Spacer()
            }
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .fill(Theme.surface)
        )
    }

    private var profileHeaderSkeleton: some View {
        VStack(spacing: Theme.Spacing.md) {
            Circle()
                .fill(Theme.surfaceElevated)
                .frame(width: 96, height: 96)

            VStack(spacing: Theme.Spacing.xs) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.surfaceElevated)
                    .frame(width: 140, height: 18)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.surfaceElevated)
                    .frame(width: 100, height: 14)
            }

            HStack(spacing: Theme.Spacing.lg) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(spacing: Theme.Spacing.xs) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.surfaceElevated)
                            .frame(width: 40, height: 20)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.surfaceElevated)
                            .frame(width: 50, height: 12)
                    }
                }
            }
        }
        .padding(Theme.Spacing.md)
    }

    private var statSkeleton: some View {
        VStack(spacing: Theme.Spacing.xs) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Theme.surfaceElevated)
                .frame(width: 50, height: 24)
            RoundedRectangle(cornerRadius: 4)
                .fill(Theme.surfaceElevated)
                .frame(width: 60, height: 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .fill(Theme.surface)
        )
    }
}
