import XCTest
@testable import XomFit

final class AdvancedStatsTests: XCTestCase {
    var service: AdvancedStatsService!
    
    override func setUp() {
        super.setUp()
        service = AdvancedStatsService.shared
    }
    
    func testMuscleHeatmapReturnsMuscleGroups() {
        let heatmap = service.muscleHeatmap(days: 7)
        XCTAssertEqual(heatmap.count, 9)
    }
    
    func testHeatmapIntensityInRange() {
        let heatmap = service.muscleHeatmap(days: 7)
        for muscle in heatmap {
            XCTAssertGreaterThanOrEqual(muscle.intensity, 0)
            XCTAssertLessThanOrEqual(muscle.intensity, 1.0)
        }
    }
    
    func testMuscleBalanceRatiosReturnsData() {
        let balances = service.muscleBalanceRatios(days: 30)
        XCTAssertEqual(balances.count, 2)
    }
    
    func testStrengthCurveReturnsEmptyForNoData() {
        let curve = service.strengthCurve(for: "NonExistentExercise", days: 90)
        XCTAssertEqual(curve.count, 0)
    }
    
    func testAllTimePRsReturnsArray() {
        let prs = service.allTimePRs()
        XCTAssertNotNil(prs)
    }
    
    func testCSVExportHasHeader() {
        let csv = service.exportToCSV()
        XCTAssertTrue(csv.hasPrefix("Date,Exercise,Sets,Reps,Weight,Volume"))
    }
    
    func testEstimated1RMCalculation() {
        let point = StrengthDataPoint(date: Date(), value: 100, reps: 10, exerciseName: "Bench Press")
        let expected = 100 * (1 + 10.0 / 30.0)
        XCTAssertEqual(point.estimated1RM, expected, accuracy: 0.01)
    }
    
    func testMusclePairBalanceIsBalanced() {
        let balanced = MusclePairBalance(primaryMuscle: "Push", antagonistMuscle: "Pull",
                                       primaryVolume: 10, antagonistVolume: 10)
        XCTAssertTrue(balanced.isBalanced)
        XCTAssertEqual(balanced.ratio, 1.0, accuracy: 0.01)
    }
    
    func testMusclePairImbalanceDetection() {
        let imbalanced = MusclePairBalance(primaryMuscle: "Push", antagonistMuscle: "Pull",
                                          primaryVolume: 20, antagonistVolume: 5)
        XCTAssertFalse(imbalanced.isBalanced)
    }
    
    func testFrequencyHeatmapReturnsData() {
        let data = service.workoutFrequencyHeatmap(days: 364)
        XCTAssertNotNil(data)
    }
    
    func testAvailableExercisesReturnsArray() {
        let exercises = service.availableExercises()
        XCTAssertNotNil(exercises)
    }
}
