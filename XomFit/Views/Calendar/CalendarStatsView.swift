import SwiftUI

struct CalendarStatsView: View {
    @ObservedObject var viewModel: WorkoutCalendarViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stats")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
                .padding(.horizontal, Theme.paddingMedium)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    StatCard(emoji: "🔥", title: "Current Streak", value: "\(viewModel.currentStreak) days")
                    StatCard(emoji: "🏆", title: "Longest Streak", value: "\(viewModel.longestStreak) days")
                    StatCard(emoji: "📅", title: "Total This Year", value: "\(viewModel.totalWorkoutsThisYear) workouts")
                    StatCard(emoji: "📆", title: "Most Active Day", value: viewModel.mostActiveDayOfWeek.isEmpty ? "—" : viewModel.mostActiveDayOfWeek)
                    StatCard(emoji: "🗓", title: "Best Month", value: viewModel.mostActiveMonth.isEmpty ? "—" : viewModel.mostActiveMonth)
                }
                .padding(.horizontal, Theme.paddingMedium)
            }
        }
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let emoji: String
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(emoji)
                .font(.title2)

            Text(title)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(Theme.textPrimary)
        }
        .frame(width: 130, alignment: .leading)
        .padding(Theme.paddingMedium)
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
    }
}

#Preview {
    CalendarStatsView(viewModel: WorkoutCalendarViewModel())
        .background(Theme.background)
}
