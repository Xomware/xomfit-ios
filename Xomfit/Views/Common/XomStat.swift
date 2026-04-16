import SwiftUI

// MARK: - Trend Direction

enum XomStatTrend {
    case up, down, neutral
}

// MARK: - XomStat

struct XomStat: View {
    let value: String
    let label: String
    let icon: String?
    let iconColor: Color
    let trend: XomStatTrend?

    init(
        _ value: String,
        label: String,
        icon: String? = nil,
        iconColor: Color = Theme.accent,
        trend: XomStatTrend? = nil
    ) {
        self.value = value
        self.label = label
        self.icon = icon
        self.iconColor = iconColor
        self.trend = trend
    }

    var body: some View {
        VStack(spacing: 2) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(iconColor)
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(Theme.fontNumberLarge)
                    .foregroundStyle(Theme.textPrimary)

                if let trend {
                    Image(systemName: trendIcon(trend))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(trendColor(trend))
                }
            }

            Text(label.uppercased())
                .font(Theme.fontMetricLabel)
                .foregroundStyle(Theme.textSecondary)
                .kerning(0.5)
        }
        .frame(maxWidth: .infinity)
    }

    private func trendIcon(_ trend: XomStatTrend) -> String {
        switch trend {
        case .up:      "arrow.up.right"
        case .down:    "arrow.down.right"
        case .neutral: "arrow.right"
        }
    }

    private func trendColor(_ trend: XomStatTrend) -> Color {
        switch trend {
        case .up:      Theme.accent
        case .down:    Theme.destructive
        case .neutral: Theme.textTertiary
        }
    }
}

// MARK: - Preview

#Preview {
    HStack {
        XomStat("135", label: "Workouts", trend: .up)
        XomStat("2,480", label: "Volume (lbs)", trend: .neutral)
        XomStat("12", label: "PRs", icon: "trophy.fill", iconColor: Theme.prGold)
    }
    .padding()
    .background(Theme.background)
}
