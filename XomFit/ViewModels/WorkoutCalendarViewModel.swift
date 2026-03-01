import Foundation
import SwiftUI

@MainActor
class WorkoutCalendarViewModel: ObservableObject {
    @Published var workoutsByDate: [Date: [Workout]] = [:]
    @Published var selectedDate: Date? = nil
    @Published var selectedWorkouts: [Workout] = []
    @Published var currentStreak: Int = 0
    @Published var longestStreak: Int = 0
    @Published var totalWorkoutsThisYear: Int = 0
    @Published var mostActiveDayOfWeek: String = ""
    @Published var mostActiveMonth: String = ""
    @Published var calendarDays: [CalendarDay] = []
    @Published var isLoaded: Bool = false

    private let calendar = Calendar.current

    struct CalendarDay: Identifiable {
        let id = UUID()
        let date: Date
        let intensity: Int
        let weekIndex: Int
        let dayOfWeek: Int // 0=Mon, 6=Sun
    }

    // MARK: - Load History

    func loadHistory() async {
        // In production, fetch from WorkoutService/Supabase
        // For now, use mock data to demonstrate the calendar
        let workouts: [Workout] = [.mock, .mockFriendWorkout]
        
        var grouped: [Date: [Workout]] = [:]
        for workout in workouts {
            let startOfDay = calendar.startOfDay(for: workout.startTime)
            grouped[startOfDay, default: []].append(workout)
        }
        
        workoutsByDate = grouped
        buildCalendarDays()
        calculateStreaks()
        computeStats()
        isLoaded = true
    }

    // MARK: - Intensity Mapping

    func intensity(for date: Date) -> Int {
        let key = calendar.startOfDay(for: date)
        let count = workoutsByDate[key]?.count ?? 0
        return Self.intensityLevel(for: count)
    }

    static func intensityLevel(for count: Int) -> Int {
        switch count {
        case 0: return 0
        case 1: return 1
        case 2...3: return 2
        case 4...5: return 3
        default: return 4
        }
    }

    // MARK: - Select Date

    func selectDate(_ date: Date) {
        let key = calendar.startOfDay(for: date)
        selectedDate = key
        selectedWorkouts = workoutsByDate[key] ?? []
    }

    // MARK: - Build Calendar Days (52 weeks back from today)

    private func buildCalendarDays() {
        var days: [CalendarDay] = []
        let today = calendar.startOfDay(for: Date())

        // Find the most recent Sunday (end of week row), then go back 52 weeks
        var weekday = calendar.component(.weekday, from: today) // 1=Sun, 2=Mon...
        // Convert to Mon=0 system: Mon=0, Tue=1, ... Sun=6
        let todayDayOfWeek = (weekday + 5) % 7
        
        // Start date: 52 weeks ago, aligned to Monday
        let daysBack = 52 * 7 + todayDayOfWeek
        guard let startDate = calendar.date(byAdding: .day, value: -daysBack, to: today) else { return }

        let totalDays = daysBack + 1 // include today
        for i in 0..<totalDays {
            guard let date = calendar.date(byAdding: .day, value: i, to: startDate) else { continue }
            let dow = i % 7
            let week = i / 7
            let level = intensity(for: date)
            days.append(CalendarDay(date: date, intensity: level, weekIndex: week, dayOfWeek: dow))
        }
        calendarDays = days
    }

    // MARK: - Streaks

    func calculateStreaks() {
        let sortedDates = workoutsByDate.keys.sorted(by: >)
        guard !sortedDates.isEmpty else {
            currentStreak = 0
            longestStreak = 0
            return
        }

        let today = calendar.startOfDay(for: Date())
        var current = 0
        var longest = 0
        var streak = 0
        var checkDate = today

        // Current streak: count consecutive days from today backward
        while true {
            if workoutsByDate[checkDate] != nil {
                current += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = prev
            } else if checkDate == today {
                // Today might not have a workout yet, check yesterday
                guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = prev
            } else {
                break
            }
        }
        currentStreak = current

        // Longest streak: scan all dates
        let allDates = Set(workoutsByDate.keys)
        let sorted = allDates.sorted()
        streak = 0
        for (i, date) in sorted.enumerated() {
            if i == 0 {
                streak = 1
            } else {
                let prev = sorted[i - 1]
                let diff = calendar.dateComponents([.day], from: prev, to: date).day ?? 0
                if diff == 1 {
                    streak += 1
                } else {
                    streak = 1
                }
            }
            longest = max(longest, streak)
        }
        longestStreak = longest
    }

    // MARK: - Stats

    func computeStats() {
        let now = Date()
        let yearStart = calendar.date(from: calendar.dateComponents([.year], from: now))!

        let thisYearWorkouts = workoutsByDate.filter { $0.key >= yearStart }
        totalWorkoutsThisYear = thisYearWorkouts.values.reduce(0) { $0 + $1.count }

        // Most active day of week
        var dayCount: [Int: Int] = [:]
        for (date, workouts) in workoutsByDate {
            let dow = calendar.component(.weekday, from: date)
            dayCount[dow, default: 0] += workouts.count
        }
        if let bestDay = dayCount.max(by: { $0.value < $1.value }) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US")
            mostActiveDayOfWeek = formatter.weekdaySymbols[bestDay.key - 1]
        }

        // Most active month
        var monthCount: [Int: Int] = [:]
        for (date, workouts) in thisYearWorkouts {
            let month = calendar.component(.month, from: date)
            monthCount[month, default: 0] += workouts.count
        }
        if let bestMonth = monthCount.max(by: { $0.value < $1.value }) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US")
            mostActiveMonth = formatter.monthSymbols[bestMonth.key - 1]
        }
    }
}
