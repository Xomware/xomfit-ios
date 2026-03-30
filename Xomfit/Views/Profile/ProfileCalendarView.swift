import SwiftUI

struct ProfileCalendarView: View {
    let workoutDays: [Date: Int]

    @State private var displayedMonth: Date = Date()

    private let calendar = Calendar.current
    private let dayOfWeekHeaders = ["S", "M", "T", "W", "T", "F", "S"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(spacing: Theme.paddingMedium) {
            monthNavigator
            dayOfWeekHeader
            calendarGrid
        }
        .padding(Theme.paddingMedium)
        .background(Theme.cardBackground)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
        .padding(.horizontal, Theme.paddingMedium)
    }

    // MARK: - Month Navigator

    private var monthNavigator: some View {
        HStack {
            Button {
                navigateMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Previous month")

            Spacer()

            Text(monthYearString)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.textPrimary)

            Spacer()

            Button {
                navigateMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(canGoForward ? Theme.accent : Theme.textSecondary.opacity(0.3))
                    .frame(width: 44, height: 44)
            }
            .disabled(!canGoForward)
            .accessibilityLabel("Next month")
        }
    }

    // MARK: - Day of Week Header

    private var dayOfWeekHeader: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(dayOfWeekHeaders, id: \.self) { day in
                Text(day)
                    .font(Theme.fontSmall)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        let days = daysInMonth()
        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                if let date {
                    dayCell(for: date)
                } else {
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                }
            }
        }
    }

    private func dayCell(for date: Date) -> some View {
        let dayNumber = calendar.component(.day, from: date)
        let count = workoutCount(for: date)
        let isToday = calendar.isDateInToday(date)

        return Text("\(dayNumber)")
            .font(.system(size: 13, weight: count > 0 ? .bold : .regular))
            .foregroundStyle(cellForeground(count: count, isToday: isToday))
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(cellBackground(count: count, isToday: isToday))
            .clipShape(.rect(cornerRadius: 6))
            .accessibilityLabel(dayCellAccessibilityLabel(dayNumber: dayNumber, count: count))
    }

    // MARK: - Cell Styling

    private func cellForeground(count: Int, isToday: Bool) -> Color {
        if count > 0 { return Theme.background }
        if isToday { return Theme.accent }
        return Theme.textSecondary
    }

    private func cellBackground(count: Int, isToday: Bool) -> Color {
        if count >= 2 { return Theme.accent }
        if count == 1 { return Theme.accent.opacity(0.4) }
        if isToday { return Theme.accent.opacity(0.1) }
        return .clear
    }

    // MARK: - Helpers

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }

    private var canGoForward: Bool {
        let now = Date()
        let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))
        let displayedMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))
        guard let current = currentMonthStart, let displayed = displayedMonthStart else { return false }
        return displayed < current
    }

    private func navigateMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            withAnimation(.easeInOut(duration: 0.2)) {
                displayedMonth = newMonth
            }
        }
    }

    private func daysInMonth() -> [Date?] {
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)),
              let range = calendar.range(of: .day, in: .month, for: monthStart) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leadingBlanks = firstWeekday - calendar.firstWeekday
        let adjustedBlanks = leadingBlanks < 0 ? leadingBlanks + 7 : leadingBlanks

        var days: [Date?] = Array(repeating: nil, count: adjustedBlanks)

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                days.append(date)
            }
        }

        // Pad to fill the last row
        let remainder = days.count % 7
        if remainder > 0 {
            days.append(contentsOf: Array(repeating: nil as Date?, count: 7 - remainder))
        }

        return days
    }

    private func workoutCount(for date: Date) -> Int {
        let startOfDay = calendar.startOfDay(for: date)
        return workoutDays[startOfDay] ?? 0
    }

    private func dayCellAccessibilityLabel(dayNumber: Int, count: Int) -> String {
        if count > 0 {
            return "Day \(dayNumber), \(count) workout\(count == 1 ? "" : "s")"
        }
        return "Day \(dayNumber)"
    }
}
