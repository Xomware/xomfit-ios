import SwiftUI

struct ProfileCalendarView: View {
    let workoutDays: [Date: Int]
    let userId: String

    @State private var displayedMonth: Date = Date()
    @State private var selectedDate: IdentifiableDate? = nil

    /// 0 = Sunday, 1 = Monday. Drives the firstWeekday + header order.
    @AppStorage("weekStartDay") private var weekStartDay: Int = 0

    /// Calendar configured to honor the user's "Week starts on" preference.
    private var calendar: Calendar {
        var cal = Calendar.current
        // Calendar.firstWeekday: 1 = Sunday, 2 = Monday.
        cal.firstWeekday = weekStartDay == 1 ? 2 : 1
        return cal
    }

    /// Header order rotates so the leading column matches `firstWeekday`.
    private var dayOfWeekHeaders: [String] {
        weekStartDay == 1
            ? ["M", "T", "W", "T", "F", "S", "S"]
            : ["S", "M", "T", "W", "T", "F", "S"]
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    /// Normalize workoutDays keys to startOfDay for reliable matching.
    private var normalizedWorkoutDays: [Date: Int] {
        var result: [Date: Int] = [:]
        for (date, count) in workoutDays {
            let normalized = calendar.startOfDay(for: date)
            result[normalized, default: 0] += count
        }
        return result
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            monthNavigator
            dayOfWeekHeader
            calendarGrid
        }
        .padding(.horizontal, 12)
        .padding(.vertical, Theme.Spacing.md)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
        .padding(.horizontal, Theme.Spacing.sm)
        .sheet(item: $selectedDate) { selected in
            CalendarDayDetailSheet(
                date: selected.date,
                userId: userId
            )
        }
    }

    // MARK: - Month Navigator

    private var monthNavigator: some View {
        HStack {
            Button {
                navigateMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Previous month")

            Spacer()

            Text(monthYearString)
                .font(.body.weight(.bold))
                .foregroundStyle(Theme.textPrimary)

            Spacer()

            Button {
                navigateMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(canGoForward ? Theme.accent : Theme.textSecondary.opacity(0.3))
                    .frame(width: 44, height: 44)
            }
            .disabled(!canGoForward)
            .accessibilityLabel("Next month")
        }
    }

    // MARK: - Day of Week Header

    private var dayOfWeekHeader: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(dayOfWeekHeaders, id: \.self) { day in
                Text(day)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        let days = daysInMonth()
        return LazyVGrid(columns: columns, spacing: 6) {
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
        let normalized = calendar.startOfDay(for: date)
        let count = normalizedWorkoutDays[normalized] ?? 0
        let isToday = calendar.isDateInToday(date)

        return Button {
            if count > 0 {
                Haptics.selection()
                selectedDate = IdentifiableDate(date: normalized)
            }
        } label: {
            VStack(spacing: 2) {
                Text("\(dayNumber)")
                    .font(.subheadline.weight(count > 0 ? .bold : .regular))
                    .foregroundStyle(cellForeground(count: count, isToday: isToday))

                if count > 0 {
                    Circle()
                        .fill(count >= 2 ? Theme.accent : Theme.accent.opacity(0.7))
                        .frame(width: 5, height: 5)
                } else {
                    Circle()
                        .fill(.clear)
                        .frame(width: 5, height: 5)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 36)
            .aspectRatio(1, contentMode: .fit)
            .background(cellBackground(count: count, isToday: isToday))
            .clipShape(.rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(count == 0)
        .accessibilityLabel(dayCellAccessibilityLabel(dayNumber: dayNumber, count: count))
    }

    // MARK: - Cell Styling

    private func cellForeground(count: Int, isToday: Bool) -> Color {
        if count > 0 { return Theme.background }
        if isToday { return Theme.accent }
        return Theme.textSecondary
    }

    private func cellBackground(count: Int, isToday: Bool) -> some ShapeStyle {
        if count >= 2 { return AnyShapeStyle(Theme.accent) }
        if count == 1 { return AnyShapeStyle(Theme.accent.opacity(0.4)) }
        if isToday { return AnyShapeStyle(Theme.accent.opacity(0.1)) }
        // Empty day: subtle surface fill + hairline for grid density
        return AnyShapeStyle(Theme.surface)
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
            withAnimation(.xomConfident) {
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
                days.append(calendar.startOfDay(for: date))
            }
        }

        let remainder = days.count % 7
        if remainder > 0 {
            days.append(contentsOf: Array(repeating: nil as Date?, count: 7 - remainder))
        }

        return days
    }

    private func dayCellAccessibilityLabel(dayNumber: Int, count: Int) -> String {
        if count > 0 {
            return "Day \(dayNumber), \(count) workout\(count == 1 ? "" : "s"), tap to view"
        }
        return "Day \(dayNumber)"
    }
}

// MARK: - Identifiable Date Wrapper

private struct IdentifiableDate: Identifiable {
    let id = UUID()
    let date: Date
}

// MARK: - Calendar Day Detail Sheet

private struct CalendarDayDetailSheet: View {
    let date: Date
    let userId: String

    @Environment(\.dismiss) private var dismiss
    @State private var workouts: [Workout] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                if isLoading {
                    ProgressView().tint(Theme.accent)
                } else if workouts.isEmpty {
                    VStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.largeTitle)
                            .foregroundStyle(Theme.textSecondary)
                        Text("No workouts found")
                            .font(Theme.fontBody)
                            .foregroundStyle(Theme.textSecondary)
                    }
                } else {
                    List {
                        ForEach(workouts) { workout in
                            NavigationLink {
                                WorkoutDetailView(workout: workout)
                                    .hideTabBar()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "dumbbell.fill")
                                        .font(.body)
                                        .foregroundStyle(Theme.accent)
                                        .frame(width: 36, height: 36)
                                        .background(Theme.accent.opacity(0.15))
                                        .clipShape(.rect(cornerRadius: 8))

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(workout.name)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Theme.textPrimary)
                                        HStack(spacing: 8) {
                                            Text("\(workout.exercises.count) exercises")
                                            Text(workout.durationString)
                                                .foregroundStyle(Theme.accent)
                                        }
                                        .font(Theme.fontSmall)
                                        .foregroundStyle(Theme.textSecondary)
                                    }

                                    Spacer()
                                }
                            }
                            .listRowBackground(Theme.surface)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle(formattedDate)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.accent)
                }
            }
            .task { await loadWorkouts() }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func loadWorkouts() async {
        isLoading = true
        let allWorkouts = await WorkoutService.shared.fetchWorkouts(userId: userId)
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        workouts = allWorkouts.filter { calendar.startOfDay(for: $0.startTime) == targetDay }
        isLoading = false
    }
}
