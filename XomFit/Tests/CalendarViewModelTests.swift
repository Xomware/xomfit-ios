import XCTest
@testable import XomFit

@MainActor
final class CalendarViewModelTests: XCTestCase {
    
    private func makeViewModel(workoutDates: [Date] = [], workoutsPerDate: Int = 1) -> WorkoutCalendarViewModel {
        let vm = WorkoutCalendarViewModel()
        let calendar = Calendar.current
        for date in workoutDates {
            let key = calendar.startOfDay(for: date)
            var workouts: [Workout] = []
            for _ in 0..<workoutsPerDate {
                workouts.append(Workout(
                    id: UUID().uuidString,
                    userId: "test",
                    name: "Test Workout",
                    exercises: [],
                    startTime: date,
                    endTime: date.addingTimeInterval(3600),
                    notes: nil
                ))
            }
            vm.workoutsByDate[key] = workouts
        }
        return vm
    }
    
    // MARK: - Intensity Tests
    
    func testIntensityZeroWorkouts() {
        XCTAssertEqual(WorkoutCalendarViewModel.intensityLevel(for: 0), 0)
    }
    
    func testIntensityOneWorkout() {
        XCTAssertEqual(WorkoutCalendarViewModel.intensityLevel(for: 1), 1)
    }
    
    func testIntensityTwoToThreeWorkouts() {
        XCTAssertEqual(WorkoutCalendarViewModel.intensityLevel(for: 2), 2)
        XCTAssertEqual(WorkoutCalendarViewModel.intensityLevel(for: 3), 2)
    }
    
    func testIntensityFourToFiveWorkouts() {
        XCTAssertEqual(WorkoutCalendarViewModel.intensityLevel(for: 4), 3)
        XCTAssertEqual(WorkoutCalendarViewModel.intensityLevel(for: 5), 3)
    }
    
    func testIntensitySixPlusWorkouts() {
        XCTAssertEqual(WorkoutCalendarViewModel.intensityLevel(for: 6), 4)
        XCTAssertEqual(WorkoutCalendarViewModel.intensityLevel(for: 10), 4)
    }
    
    // MARK: - Streak Tests
    
    func testCurrentStreakConsecutiveDays() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dates = (0..<5).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
        
        let vm = makeViewModel(workoutDates: dates)
        vm.calculateStreaks()
        
        XCTAssertEqual(vm.currentStreak, 5)
    }
    
    func testCurrentStreakGapResetsStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        // Today + yesterday, then skip a day, then 2 more days
        let dates = [
            today,
            calendar.date(byAdding: .day, value: -1, to: today)!,
            // gap at -2
            calendar.date(byAdding: .day, value: -3, to: today)!,
            calendar.date(byAdding: .day, value: -4, to: today)!,
        ]
        
        let vm = makeViewModel(workoutDates: dates)
        vm.calculateStreaks()
        
        XCTAssertEqual(vm.currentStreak, 2)
    }
    
    func testLongestStreakIsLongerThanCurrent() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        // Current: 1 day (today)
        // Past: 5 consecutive days ending 10 days ago
        var dates = [today]
        for i in 10..<15 {
            dates.append(calendar.date(byAdding: .day, value: -i, to: today)!)
        }
        
        let vm = makeViewModel(workoutDates: dates)
        vm.calculateStreaks()
        
        XCTAssertEqual(vm.currentStreak, 1)
        XCTAssertEqual(vm.longestStreak, 5)
    }
    
    func testEmptyStreaks() {
        let vm = makeViewModel()
        vm.calculateStreaks()
        
        XCTAssertEqual(vm.currentStreak, 0)
        XCTAssertEqual(vm.longestStreak, 0)
    }
    
    // MARK: - Stats Tests
    
    func testMostActiveDayOfWeek() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Create workouts on multiple Mondays (weekday 2)
        var dates: [Date] = []
        for weeksBack in 0..<4 {
            // Find the Monday of that week
            var comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
            comps.weekday = 2 // Monday
            if let monday = calendar.date(from: comps),
               let adjusted = calendar.date(byAdding: .weekOfYear, value: -weeksBack, to: monday) {
                dates.append(adjusted)
            }
        }
        
        let vm = makeViewModel(workoutDates: dates)
        vm.computeStats()
        
        XCTAssertEqual(vm.mostActiveDayOfWeek, "Monday")
    }
    
    func testTotalWorkoutsThisYear() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dates = (0..<10).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
        
        let vm = makeViewModel(workoutDates: dates)
        vm.computeStats()
        
        XCTAssertEqual(vm.totalWorkoutsThisYear, 10)
    }
    
    func testYearFilteringExcludesLastYear() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let thisYear = calendar.date(byAdding: .day, value: -1, to: today)!
        let lastYear = calendar.date(byAdding: .year, value: -1, to: today)!
        
        let vm = makeViewModel(workoutDates: [thisYear, lastYear])
        vm.computeStats()
        
        XCTAssertEqual(vm.totalWorkoutsThisYear, 1)
    }
}
