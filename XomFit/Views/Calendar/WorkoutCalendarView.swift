import SwiftUI

struct WorkoutCalendarView: View {
    @StateObject private var viewModel = WorkoutCalendarViewModel()
    @State private var appeared = false

    private let cellSize: CGFloat = 12
    private let cellSpacing: CGFloat = 2
    private let dayLabels = ["M", "", "W", "", "F", "", ""]
    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.paddingLarge) {
                        // Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Workout Calendar")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(Theme.textPrimary)

                            Text("Your year of training at a glance")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                        .padding(.horizontal, Theme.paddingMedium)

                        // Heat Map
                        heatMapSection

                        // Legend
                        legendRow

                        // Stats
                        CalendarStatsView(viewModel: viewModel)

                        Spacer(minLength: 40)
                    }
                    .padding(.top, Theme.paddingMedium)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $viewModel.selectedDate) { date in
                CalendarDayDetailView(
                    date: date,
                    workouts: viewModel.selectedWorkouts
                )
                .presentationDetents([.medium])
            }
            .task {
                await viewModel.loadHistory()
                withAnimation(.easeOut(duration: 0.6)) {
                    appeared = true
                }
            }
        }
    }

    // MARK: - Heat Map

    @ViewBuilder
    private var heatMapSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Month labels
            monthLabelsRow

            HStack(alignment: .top, spacing: 0) {
                // Day of week labels
                VStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { i in
                        Text(dayLabels[i])
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(Theme.textSecondary)
                            .frame(width: 16, height: cellSize + cellSpacing)
                    }
                }

                // Scrollable grid
                ScrollView(.horizontal, showsIndicators: false) {
                    let weeks = groupByWeek()
                    HStack(alignment: .top, spacing: cellSpacing) {
                        ForEach(Array(weeks.enumerated()), id: \.offset) { weekIdx, week in
                            VStack(spacing: cellSpacing) {
                                ForEach(week) { day in
                                    CalendarCellView(
                                        intensity: day.intensity,
                                        isSelected: viewModel.selectedDate == day.date,
                                        isToday: calendar.isDateInToday(day.date),
                                        onTap: { viewModel.selectDate(day.date) }
                                    )
                                    .opacity(appeared ? 1 : 0)
                                    .animation(
                                        .easeOut(duration: 0.3).delay(Double(weekIdx) * 0.008),
                                        value: appeared
                                    )
                                }
                            }
                        }
                    }
                    .padding(.trailing, Theme.paddingMedium)
                }
            }
        }
        .padding(.horizontal, Theme.paddingMedium)
    }

    // MARK: - Month Labels

    @ViewBuilder
    private var monthLabelsRow: some View {
        let weeks = groupByWeek()
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                // Offset for day labels
                Color.clear.frame(width: 16)

                HStack(alignment: .top, spacing: cellSpacing) {
                    ForEach(Array(weeks.enumerated()), id: \.offset) { weekIdx, week in
                        let firstDay = week.first
                        let dayOfMonth = firstDay.map { calendar.component(.day, from: $0.date) } ?? 15
                        let showLabel = dayOfMonth <= 7
                        
                        Text(showLabel ? monthLabel(for: week.first!.date) : "")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(Theme.textSecondary)
                            .frame(width: cellSize)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Legend

    @ViewBuilder
    private var legendRow: some View {
        HStack(spacing: 4) {
            Spacer()
            Text("Less")
                .font(.system(size: 9))
                .foregroundColor(Theme.textSecondary)
            ForEach(0..<5) { i in
                CalendarCellView(intensity: i, isSelected: false, isToday: false, onTap: {})
            }
            Text("More")
                .font(.system(size: 9))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.horizontal, Theme.paddingMedium)
    }

    // MARK: - Helpers

    private func groupByWeek() -> [[WorkoutCalendarViewModel.CalendarDay]] {
        Dictionary(grouping: viewModel.calendarDays, by: \.weekIndex)
            .sorted(by: { $0.key < $1.key })
            .map { $0.value.sorted(by: { $0.dayOfWeek < $1.dayOfWeek }) }
    }

    private func monthLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }
}

// MARK: - Date Identifiable conformance for sheet

extension Date: @retroactive Identifiable {
    public var id: TimeInterval { timeIntervalSince1970 }
}

#Preview {
    WorkoutCalendarView()
}
