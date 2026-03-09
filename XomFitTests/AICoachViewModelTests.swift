import XCTest
@testable import XomFit

@MainActor
final class AICoachViewModelTests: XCTestCase {
    var viewModel: AICoachViewModel!

    override func setUp() {
        super.setUp()
        viewModel = AICoachViewModel()
    }

    func testInitialState() {
        XCTAssertTrue(viewModel.recommendations.isEmpty)
        XCTAssertNil(viewModel.performanceAnalysis)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.insights.isEmpty)
    }

    func testTopRecommendationNilWhenEmpty() {
        XCTAssertNil(viewModel.topRecommendation)
    }

    func testHasRecommendationsFalseWhenEmpty() {
        XCTAssertFalse(viewModel.hasRecommendations)
    }

    func testDismissInsight() {
        let insight = CoachInsight(type: .prOpportunity, title: "Test", message: "Test", confidence: 0.8)
        viewModel.insights = [insight]
        XCTAssertEqual(viewModel.insights.count, 1)
        viewModel.dismissInsight(insight)
        XCTAssertTrue(viewModel.insights.isEmpty)
    }

    func testAcceptRecommendation() {
        let rec = AIRecommendation.mockExerciseRecommendation
        viewModel.recommendations = [rec]
        XCTAssertEqual(viewModel.recommendations.count, 1)
        viewModel.acceptRecommendation(rec)
        XCTAssertTrue(viewModel.recommendations.isEmpty)
    }

    func testDismissRecommendation() {
        let rec = AIRecommendation.mockWeakPointRecommendation
        viewModel.recommendations = [rec]
        viewModel.dismissRecommendation(rec)
        XCTAssertTrue(viewModel.recommendations.isEmpty)
    }

    func testSelectedPhaseDefault() {
        XCTAssertEqual(viewModel.selectedPhase, .accumulation)
    }

    func testCurrentPhaseBlockNilBeforeLoad() {
        XCTAssertNil(viewModel.currentPhaseBlock())
    }

    func testUserPreferencesDefaults() {
        XCTAssertEqual(viewModel.userPreferences.targetDaysPerWeek, 4)
        XCTAssertTrue(viewModel.userPreferences.enableAutoDeload)
    }

    func testLoadRecommendationsSetsLoading() {
        let workouts = [Workout.mock]
        viewModel.loadRecommendations(userId: "user-1", workouts: workouts)
        // isLoading should be true initially (async)
        XCTAssertTrue(viewModel.isLoading)
    }

    func testLoadAllSetsLoading() {
        viewModel.loadAll()
        XCTAssertTrue(viewModel.isLoading)
    }
}
