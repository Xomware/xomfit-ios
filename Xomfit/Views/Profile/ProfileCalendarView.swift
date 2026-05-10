import SwiftUI

/// Profile calendar with two modes:
/// - **Month**: classic month grid with per-day workout dots (existing behavior).
/// - **Year**: 53-week heatmap (#316) where each cell is a day colored by that
///   day's total workout volume. Year mode adds a recap card up top with
///   total workouts, longest streak, top exercise (by sets), and total volume.
///
/// View takes `workouts` directly so it can derive volume tertiles + recap
/// stats locally without round-tripping through the view model. `workoutDays`
/// is preserved for callsite compat / Month mode.
struct ProfileCalendarView: View {
    let workoutDays: [Date: Int]
    let workouts: [Workout]
    let userId: String

    enum Mode: String, CaseIterable, Identifiable {
        case month = "Month"
        case year = "Year"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .month
    @State private var displayedMonth: Date = Date()
    @State private var displayedYear: Date = Date()
    @State private var selectedDate: IdentifiableDate? = nil

    private let calendar = Calendar.current
    private let dayOfWeekHeaders = ["S", "M", "T", "W", "T", "F", "S"]
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
        VStack(spacing: Theme.Spacing.md) {
            modePicker

            switch mode {
            case .month:
                monthSection
            case .year:
                yearSection
            }
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .sheet(item: $selectedDate) { selected in
            CalendarDayDetailSheet(
                date: selected.date,
                userId: userId,
                workouts: workoutsOn(date: selected.date)
            )
        }
    }

    // MARK: - Mode Picker

    private var modePicker: some View {
        Picker("Calendar mode", selection: $mode) {
            ForEach(Mode.allCases) { m in
                Text(m.rawValue).tag(m)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, Theme.Spacing.sm)
        .accessibilityLabel("Calendar mode")
        .onChange(of: mode) { _, _ in
            Haptics.selection()
        }
    }

    // MARK: - Month Section

    private var monthSection: some View {
        VStack(spacing: Theme.Spacing.sm) {
            monthNavigator
            dayOfWeekHeader
            calendarGrid
        }
        .padding(.horizontal, 12)
        .padding(.vertical, Theme.Spacing.md)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }

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
                    .foregroundStyle(canGoForwardMonth ? Theme.accent : Theme.textSecondary.opacity(0.3))
                    .frame(width: 44, height: 44)
            }
            .disabled(!canGoForwardMonth)
            .accessibilityLabel("Next month")
        }
    }

    private var dayOfWeekHeader: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Array(dayOfWeekHeaders.enumerated()), id: \.offset) { _, day in
                Text(day)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

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

    private func cellForeground(count: Int, isToday: Bool) -> Color {
        if count > 0 { return Theme.background }
        if isToday { return Theme.accent }
        return Theme.textSecondary
    }

    private func cellBackground(count: Int, isToday: Bool) -> some ShapeStyle {
        if count >= 2 { return AnyShapeStyle(Theme.accent) }
        if count == 1 { return AnyShapeStyle(Theme.accent.opacity(0.4)) }
        if isToday { return AnyShapeStyle(Theme.accent.opacity(0.1)) }
        return AnyShapeStyle(Theme.surface)
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }

    private var canGoForwardMonth: Bool {
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

    // MARK: - Year Section

    private var yearSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            yearRecapCard
            yearHeatmapCard
        }
    }

    private var yearRecapCard: some View {
        let stats = yearStats
        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("\(stats.year) Recap")
                    .font(Theme.fontHeadline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                yearNavigator
            }

            HStack(spacing: Theme.Spacing.sm) {
                recapStat(label: "Workouts", value: "\(stats.totalWorkouts)")
                recapStat(label: "Longest Streak", value: "\(stats.longestStreak)d")
            }

            HStack(spacing: Theme.Spacing.sm) {
                recapStat(label: "Top Exercise", value: stats.topExercise ?? "—")
                recapStat(label: "Total Volume", value: stats.formattedVolume)
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }

    private func recapStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(Theme.fontSmall)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
            Text(value)
                .font(.body.weight(.bold))
                .foregroundStyle(Theme.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.sm)
        .background(Theme.background.opacity(0.5))
        .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    private var yearNavigator: some View {
        HStack(spacing: 0) {
            Button {
                navigateYear(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("Previous year")

            Button {
                navigateYear(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(canGoForwardYear ? Theme.accent : Theme.textSecondary.opacity(0.3))
                    .frame(width: 36, height: 36)
            }
            .disabled(!canGoForwardYear)
            .accessibilityLabel("Next year")
        }
    }

    private var yearHeatmapCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            heatmapGrid
            heatmapLegend
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }

    /// 53-week × 7-day heatmap grid. Columns are weeks (oldest left → newest right),
    /// rows are weekdays (Sun top → Sat bottom). Days outside the displayed year
    /// are rendered as blank to preserve the column shape.
    private var heatmapGrid: some View {
        let layout = yearHeatmapLayout()
        let cellSpacing: CGFloat = 3

        return ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: cellSpacing) {
                    // Weekday labels column
                    VStack(spacing: cellSpacing) {
                        ForEach(0..<7, id: \.self) { row in
                            Text(weekdayLabel(for: row))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(Theme.textSecondary)
                                .frame(width: 14, height: 12, alignment: .trailing)
                        }
                    }

                    ForEach(Array(layout.weeks.enumerated()), id: \.offset) { weekIdx, week in
                        VStack(spacing: cellSpacing) {
                            ForEach(0..<7, id: \.self) { row in
                                heatmapCell(date: week[row], tertiles: layout.tertiles)
                            }
                        }
                        .id(weekIdx)
                    }
                }
                .padding(.vertical, 2)
            }
            .onAppear {
                // Scroll to the latest week so today is visible by default.
                if !layout.weeks.isEmpty {
                    proxy.scrollTo(layout.weeks.count - 1, anchor: .trailing)
                }
            }
            .onChange(of: displayedYear) { _, _ in
                if !layout.weeks.isEmpty {
                    proxy.scrollTo(layout.weeks.count - 1, anchor: .trailing)
                }
            }
        }
    }

    @ViewBuilder
    private func heatmapCell(date: Date?, tertiles: VolumeTertiles) -> some View {
        if let date {
            let normalized = calendar.startOfDay(for: date)
            let count = normalizedWorkoutDays[normalized] ?? 0
            let volume = volumeByDay[normalized] ?? 0
            let isToday = calendar.isDateInToday(date)

            Button {
                if count > 0 {
                    Haptics.selection()
                    selectedDate = IdentifiableDate(date: normalized)
                }
            } label: {
                RoundedRectangle(cornerRadius: 2)
                    .fill(heatmapFill(volume: volume, hasWorkout: count > 0, tertiles: tertiles))
                    .frame(width: 12, height: 12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .strokeBorder(isToday ? Theme.textPrimary : Color.clear, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(count == 0)
            .accessibilityLabel(heatmapCellAccessibilityLabel(date: normalized, count: count))
        } else {
            Color.clear.frame(width: 12, height: 12)
        }
    }

    private func heatmapFill(volume: Double, hasWorkout: Bool, tertiles: VolumeTertiles) -> Color {
        guard hasWorkout else { return Theme.surface.opacity(0.6) }
        // Below the lowest tertile -> 0.3, between low/mid -> 0.5, between mid/high -> 0.8, above -> 1.0.
        let opacity: Double
        if volume <= tertiles.low {
            opacity = 0.3
        } else if volume <= tertiles.mid {
            opacity = 0.5
        } else if volume <= tertiles.high {
            opacity = 0.8
        } else {
            opacity = 1.0
        }
        return Theme.accent.opacity(opacity)
    }

    private var heatmapLegend: some View {
        HStack(spacing: 6) {
            Text("Less")
                .font(.system(size: 10))
                .foregroundStyle(Theme.textSecondary)
            ForEach([0.0, 0.3, 0.5, 0.8, 1.0], id: \.self) { opacity in
                RoundedRectangle(cornerRadius: 2)
                    .fill(opacity == 0 ? Theme.surface.opacity(0.6) : Theme.accent.opacity(opacity))
                    .frame(width: 10, height: 10)
            }
            Text("More")
                .font(.system(size: 10))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Volume legend: less to more")
    }

    private func weekdayLabel(for row: Int) -> String {
        // Show Mon / Wed / Fri sparsely to avoid clutter (matches GitHub heatmap style).
        switch row {
        case 1: return "M"
        case 3: return "W"
        case 5: return "F"
        default: return ""
        }
    }

    private var canGoForwardYear: Bool {
        let nowYear = calendar.component(.year, from: Date())
        let displayed = calendar.component(.year, from: displayedYear)
        return displayed < nowYear
    }

    private func navigateYear(by value: Int) {
        if let newYear = calendar.date(byAdding: .year, value: value, to: displayedYear) {
            withAnimation(.xomConfident) {
                displayedYear = newYear
            }
        }
    }

    // MARK: - Year computations

    /// Volume rollup for the displayed year only, normalized to startOfDay.
    private var volumeByDay: [Date: Double] {
        let yearWorkouts = workoutsForDisplayedYear
        return WorkoutInsights.volumeByDay(workouts: yearWorkouts, calendar: calendar)
    }

    private var workoutsForDisplayedYear: [Workout] {
        let year = calendar.component(.year, from: displayedYear)
        return workouts.filter { calendar.component(.year, from: $0.startTime) == year }
    }

    private struct VolumeTertiles {
        let low: Double
        let mid: Double
        let high: Double
    }

    /// Layout describing the year heatmap: the week columns (Sun..Sat) and
    /// the volume tertile thresholds used to color each cell.
    private struct YearHeatmapLayout {
        let weeks: [[Date?]]
        let tertiles: VolumeTertiles
    }

    private func yearHeatmapLayout() -> YearHeatmapLayout {
        let year = calendar.component(.year, from: displayedYear)
        guard let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let yearEnd = calendar.date(from: DateComponents(year: year, month: 12, day: 31)) else {
            return YearHeatmapLayout(weeks: [], tertiles: VolumeTertiles(low: 0, mid: 0, high: 0))
        }

        // First column starts on the Sunday on/before Jan 1.
        let firstWeekday = calendar.component(.weekday, from: yearStart) // 1 = Sunday
        let leadingBlanks = firstWeekday - 1

        // Walk forward day-by-day until Dec 31, slotting into 7-tall columns.
        var weeks: [[Date?]] = []
        var currentColumn: [Date?] = Array(repeating: nil, count: leadingBlanks)

        var cursor = yearStart
        while cursor <= yearEnd {
            currentColumn.append(calendar.startOfDay(for: cursor))
            if currentColumn.count == 7 {
                weeks.append(currentColumn)
                currentColumn = []
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        if !currentColumn.isEmpty {
            while currentColumn.count < 7 {
                currentColumn.append(nil)
            }
            weeks.append(currentColumn)
        }

        // Tertiles over non-zero volume days for THIS year.
        let volumes = volumeByDay.values.filter { $0 > 0 }.sorted()
        let tertiles: VolumeTertiles
        if volumes.isEmpty {
            tertiles = VolumeTertiles(low: 0, mid: 0, high: 0)
        } else {
            let low = volumes[volumes.count / 4]
            let mid = volumes[volumes.count / 2]
            let high = volumes[(volumes.count * 3) / 4]
            tertiles = VolumeTertiles(low: low, mid: mid, high: high)
        }

        return YearHeatmapLayout(weeks: weeks, tertiles: tertiles)
    }

    private struct YearStats {
        let year: Int
        let totalWorkouts: Int
        let longestStreak: Int
        let topExercise: String?
        let totalVolume: Double

        var formattedVolume: String {
            if totalVolume >= 1_000_000 {
                return String(format: "%.1fM", totalVolume / 1_000_000)
            } else if totalVolume >= 1_000 {
                return String(format: "%.1fk", totalVolume / 1_000)
            }
            return "\(Int(totalVolume))"
        }
    }

    private var yearStats: YearStats {
        let year = calendar.component(.year, from: displayedYear)
        let yearWorkouts = workoutsForDisplayedYear

        let total = yearWorkouts.count
        let longest = WorkoutInsights.longestStreak(workouts: yearWorkouts, calendar: calendar)

        // Top exercise by total set count this year.
        var setsByName: [String: Int] = [:]
        var totalVolume: Double = 0
        for workout in yearWorkouts {
            totalVolume += workout.totalVolume
            for ex in workout.exercises {
                setsByName[ex.exercise.name, default: 0] += ex.sets.count
            }
        }
        let top = setsByName.max { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value < rhs.value }
            return lhs.key > rhs.key
        }?.key

        return YearStats(
            year: year,
            totalWorkouts: total,
            longestStreak: longest,
            topExercise: top,
            totalVolume: totalVolume
        )
    }

    private func heatmapCellAccessibilityLabel(date: Date, count: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let dateStr = formatter.string(from: date)
        if count > 0 {
            return "\(dateStr), \(count) workout\(count == 1 ? "" : "s"), tap to view"
        }
        return "\(dateStr), no workouts"
    }

    // MARK: - Workout lookup

    private func workoutsOn(date: Date) -> [Workout] {
        let target = calendar.startOfDay(for: date)
        return workouts.filter { calendar.startOfDay(for: $0.startTime) == target }
    }
}

// MARK: - Identifiable Date Wrapper

private struct IdentifiableDate: Identifiable {
    let id = UUID()
    let date: Date
}

// MARK: - Calendar Day Detail Sheet

/// Sheet shown when a user taps a day with workouts. If the in-memory
/// `workouts` list already contains this day's sessions we use those
/// directly; otherwise we fall back to fetching by `userId` to cover
/// the case where the calendar was passed sparse data.
private struct CalendarDayDetailSheet: View {
    let date: Date
    let userId: String
    let workouts: [Workout]

    @Environment(\.dismiss) private var dismiss
    @State private var loadedWorkouts: [Workout] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                if isLoading {
                    ProgressView().tint(Theme.accent)
                } else if loadedWorkouts.isEmpty {
                    VStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.largeTitle)
                            .foregroundStyle(Theme.textSecondary)
                        Text("No workouts found")
                            .font(Theme.fontBody)
                            .foregroundStyle(Theme.textSecondary)
                    }
                } else if loadedWorkouts.count == 1, let only = loadedWorkouts.first {
                    // Single workout — push detail directly into the sheet's nav stack.
                    WorkoutDetailView(workout: only)
                } else {
                    List {
                        ForEach(loadedWorkouts) { workout in
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
        // Prefer the in-memory list if the parent already has workouts for this day.
        if !workouts.isEmpty {
            loadedWorkouts = workouts
            isLoading = false
            return
        }
        isLoading = true
        let allWorkouts = await WorkoutService.shared.fetchWorkouts(userId: userId)
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        loadedWorkouts = allWorkouts.filter { calendar.startOfDay(for: $0.startTime) == targetDay }
        isLoading = false
    }
}
