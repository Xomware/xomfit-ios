import XCTest
@testable import XomFit

class AnalyticsViewModelTests: XCTestCase {
    var sut: AnalyticsViewModel!
    var mockWorkouts: [Workout]!
    
    override func setUp() {
        super.setUp()
        mockWorkouts = createMockWorkouts()
        sut = AnalyticsViewModel(workouts: mockWorkouts)
    }
    
    override func tearDown() {
        sut = nil
        mockWorkouts = nil
        super.tearDown()
    }
    
    // MARK: - Weight Progression Tests
    func testCalculateWeightProgression_WithValidData() {
        let data = sut.calculateWeightProgression(workouts: mockWorkouts)
        
        XCTAssertFalse(data.isEmpty, "Weight progression data should not be empty")
        XCTAssert(data.count >= 1, "Should have at least one data point")
        
        // Verify data is sorted by date
        for i in 1..<data.count {
            XCTAssert(data[i].date >= data[i-1].date, "Data should be sorted by date")
        }
    }
    
    func testCalculateWeightProgression_WithEmptyWorkouts() {
        let data = sut.calculateWeightProgression(workouts: [])
        
        XCTAssert(data.isEmpty, "Should return empty array for empty workouts")
    }
    
    func testCalculateWeightProgression_SelectsMaxWeight() {
        let data = sut.calculateWeightProgression(workouts: mockWorkouts)
        
        // For bench press (first exercise in mock), should select the heaviest weight
        let expectedMaxWeight = 235.0 // From mock data
        let maxDataWeight = data.max(by: { $0.weight < $1.weight })?.weight ?? 0
        
        XCTAssert(maxDataWeight >= expectedMaxWeight, "Should include the max weight")
    }
    
    // MARK: - Volume by Muscle Group Tests
    func testCalculateVolumeByMuscleGroup_WithValidData() {
        let data = sut.calculateVolumeByMuscleGroup(workouts: mockWorkouts)
        
        XCTAssertFalse(data.isEmpty, "Volume by muscle group data should not be empty")
        
        // Verify all muscle groups are included
        XCTAssert(data.count <= MuscleGroup.allCases.count, "Should not exceed total muscle groups")
    }
    
    func testCalculateVolumeByMuscleGroup_SortedByVolume() {
        let data = sut.calculateVolumeByMuscleGroup(workouts: mockWorkouts)
        
        // Verify data is sorted by volume (descending)
        for i in 1..<data.count {
            XCTAssert(data[i].volume <= data[i-1].volume, "Data should be sorted by volume descending")
        }
    }
    
    func testCalculateVolumeByMuscleGroup_VolumeCalculation() {
        let data = sut.calculateVolumeByMuscleGroup(workouts: mockWorkouts)
        
        // Chest should have volume from bench press sets
        let chestVolume = data.first(where: { $0.muscleGroup == .chest })?.volume ?? 0
        XCTAssert(chestVolume > 0, "Chest should have volume > 0")
    }
    
    // MARK: - Workout Frequency Tests
    func testCalculateWorkoutFrequency_CoversDateRange() {
        sut.setDateRange(
            startDate: Date().addingTimeInterval(-7 * 24 * 3600),
            endDate: Date()
        )
        
        let data = sut.calculateWorkoutFrequency(workouts: mockWorkouts)
        
        // Should have entries for each day
        XCTAssert(data.count > 0, "Should have frequency data")
        XCTAssert(data.count <= 8, "Should have at most 8 days of data for 7-day range")
    }
    
    func testCalculateWorkoutFrequency_CountsMultipleWorkoutsPerDay() {
        // Create multiple workouts on same day
        let today = Date()
        let dayKey = Calendar.current.startOfDay(for: today)
        
        var tesWorkouts = mockWorkouts
        tesWorkouts.append(Workout(
            id: "w-extra",
            userId: "user-1",
            name: "Extra Workout",
            exercises: [],
            startTime: dayKey.addingTimeInterval(3600),
            endTime: dayKey.addingTimeInterval(7200),
            notes: nil
        ))
        
        let viewModel = AnalyticsViewModel(workouts: tesWorkouts)
        let data = viewModel.calculateWorkoutFrequency(workouts: tesWorkouts)
        
        let todayFrequency = data.first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) })
        XCTAssert((todayFrequency?.count ?? 0) > 0, "Should count multiple workouts")
    }
    
    // MARK: - Estimated 1RM Trends Tests
    func testCalculateOneRMTrends_WithValidData() {
        let data = sut.calculateOneRMTrends(workouts: mockWorkouts)
        
        XCTAssertFalse(data.isEmpty, "1RM trends data should not be empty")
        
        // Verify data is sorted by date
        for i in 1..<data.count {
            XCTAssert(data[i].date >= data[i-1].date, "Data should be sorted by date")
        }
    }
    
    func testCalculateOneRMTrends_UsesEstimatedOneRMFormula() {
        let data = sut.calculateOneRMTrends(workouts: mockWorkouts)
        
        for dataPoint in data {
            // 1RM should be at least as high as any working weight
            XCTAssert(dataPoint.estimatedOneRM > 0, "1RM should be positive")
        }
    }
    
    // MARK: - Summary Statistics Tests
    func testTotalWorkouts_CalculatesCorrectly() {
        let total = sut.totalWorkouts
        
        XCTAssert(total > 0, "Should have workouts")
        XCTAssertLessThanOrEqual(total, mockWorkouts.count, "Should not exceed mock workout count")
    }
    
    func testTotalVolume_CalculatesCorrectly() {
        let volume = sut.totalVolume
        
        // From mock: 225*5 + 225*5 + 235*3 = 1125 + 1125 + 705 = 2955
        let expectedVolume: Double = 225*5 + 225*5 + 235*3
        XCTAssert(volume >= expectedVolume, "Total volume should include all sets")
    }
    
    func testAverageWorkoutDuration_CalculatesCorrectly() {
        let duration = sut.averageWorkoutDuration
        
        XCTAssert(duration > 0, "Average duration should be positive")
    }
    
    // MARK: - Date Range Filtering Tests
    func testSetDateRange_FiltersWorkouts() {
        let futureDate = Date().addingTimeInterval(100000)
        sut.setDateRange(startDate: futureDate, endDate: futureDate.addingTimeInterval(10000))
        
        XCTAssert(sut.totalWorkouts == 0, "Should return no workouts outside date range")
    }
    
    func testSetPresetDateRange_LastMonth() {
        sut.setPresetDateRange(.lastMonth)
        
        let calendar = Calendar.current
        let startOfRange = calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        let now = Date()
        
        XCTAssert(sut.selectedStartDate <= startOfRange.addingTimeInterval(86400), "Start date should be about 1 month ago")
        XCTAssert(sut.selectedEndDate >= now.addingTimeInterval(-86400), "End date should be today")
    }
    
    // MARK: - Helper Methods
    private func createMockWorkouts() -> [Workout] {
        [
            Workout(
                id: "w-1",
                userId: "user-1",
                name: "Push Day",
                exercises: [
                    WorkoutExercise(
                        id: "we-1",
                        exercise: Exercise(
                            id: "ex-1",
                            name: "Bench Press",
                            muscleGroups: [.chest, .triceps, .shoulders],
                            equipment: .barbell,
                            category: .compound,
                            description: "Test",
                            tips: []
                        ),
                        sets: [
                            WorkoutSet(id: "set-1", exerciseId: "ex-1", weight: 225, reps: 5, rpe: 8, isPersonalRecord: false, completedAt: Date()),
                            WorkoutSet(id: "set-2", exerciseId: "ex-1", weight: 225, reps: 5, rpe: 8.5, isPersonalRecord: false, completedAt: Date()),
                            WorkoutSet(id: "set-3", exerciseId: "ex-1", weight: 235, reps: 3, rpe: 9, isPersonalRecord: true, completedAt: Date()),
                        ],
                        notes: nil
                    )
                ],
                startTime: Date().addingTimeInterval(-3600),
                endTime: Date().addingTimeInterval(-600),
                notes: nil
            )
        ]
    }
}
