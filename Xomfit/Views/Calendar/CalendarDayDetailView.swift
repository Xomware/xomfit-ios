import SwiftUI

struct CalendarDayDetailView: View {
    let date: Date
    let workouts: [Workout]

    private var headerText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: date)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                if workouts.isEmpty {
                    VStack(spacing: 12) {
                        Text("😴")
                            .font(.system(size: 48))
                        Text("Rest Day")
                            .font(.headline)
                            .foregroundColor(Theme.textPrimary)
                        Text("No workouts logged")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                } else {
                    List {
                        ForEach(workouts) { workout in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(workout.name)
                                    .font(.headline)
                                    .foregroundColor(Theme.textPrimary)

                                HStack(spacing: 16) {
                                    Label(workout.durationString, systemImage: "clock")
                                    Label(workout.formattedVolume + " lbs", systemImage: "scalemass")
                                    Label("\(workout.totalSets) sets", systemImage: "rectangle.stack")
                                }
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)

                                if workout.totalPRs > 0 {
                                    Label("\(workout.totalPRs) PR\(workout.totalPRs > 1 ? "s" : "")", systemImage: "trophy.fill")
                                        .font(.caption)
                                        .foregroundColor(Theme.prGold)
                                }
                            }
                            .padding(.vertical, 4)
                            .listRowBackground(Theme.cardBackground)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle(headerText)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    CalendarDayDetailView(date: Date(), workouts: [.mock])
}
