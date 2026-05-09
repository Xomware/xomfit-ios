import SwiftUI

/// Streak card surfaced on `ProfileStatsView` (#250).
/// Active streak (>= 1 day) renders in accent green with a flame icon;
/// broken streaks dim to textSecondary so the card still tells the story.
struct StreakCard: View {
    let currentStreak: Int
    let longestStreak: Int

    private var isActive: Bool { currentStreak > 0 }

    private var iconColor: Color {
        isActive ? Theme.streak : Theme.textSecondary
    }

    private var headlineText: String {
        let unit = currentStreak == 1 ? "day" : "days"
        return isActive ? "\(currentStreak) \(unit) streak" : "No active streak"
    }

    private var subtitleText: String {
        if longestStreak > 0 {
            let unit = longestStreak == 1 ? "day" : "days"
            return "Longest: \(longestStreak) \(unit)"
        }
        return "Log a workout today to start one"
    }

    var body: some View {
        XomCard(padding: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "flame.fill")
                        .font(.title3)
                        .foregroundStyle(iconColor)
                        .symbolEffect(.bounce, value: currentStreak)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(headlineText)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(subtitleText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isActive
            ? "Current streak \(currentStreak) days. Longest streak \(longestStreak) days."
            : "No active streak. Longest streak \(longestStreak) days."
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        StreakCard(currentStreak: 7, longestStreak: 12)
        StreakCard(currentStreak: 1, longestStreak: 12)
        StreakCard(currentStreak: 0, longestStreak: 12)
        StreakCard(currentStreak: 0, longestStreak: 0)
    }
    .padding()
    .background(Theme.background)
}
