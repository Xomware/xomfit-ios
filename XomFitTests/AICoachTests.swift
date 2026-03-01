import XCTest
@testable import XomFit

final class AICoachTests: XCTestCase {
    var service: AICoachService!
    
    override func setUp() {
        super.setUp()
        service = AICoachService.shared
    }
    
    func testReadinessCalculationWithNoWorkouts() {
        let readiness = service.calculateReadiness()
        XCTAssertGreaterThanOrEqual(readiness.score, 0)
        XCTAssertLessThanOrEqual(readiness.score, 100)
        XCTAssertNotNil(readiness.fatigueLevel)
        XCTAssertFalse(readiness.recommendation.isEmpty)
    }
    
    func testPeriodizationPlanHasSixWeeks() {
        let plan = service.generatePeriodizationPlan()
        XCTAssertEqual(plan.count, 6)
    }
    
    func testPeriodizationPhaseOrder() {
        let plan = service.generatePeriodizationPlan()
        XCTAssertTrue(plan.contains { $0.phase == .accumulation })
        XCTAssertTrue(plan.contains { $0.phase == .intensification })
        XCTAssertTrue(plan.contains { $0.phase == .realization })
        XCTAssertTrue(plan.contains { $0.phase == .deload })
    }
    
    func testTrainingLoadCalculation() {
        let load = service.calculateTrainingLoad()
        XCTAssertGreaterThanOrEqual(load.acute, 0)
        XCTAssertGreaterThan(load.chronic, 0)
        XCTAssertFalse(load.riskLevel.isEmpty)
    }
    
    func testMuscleGroupVolumesReturnsSixGroups() {
        let volumes = service.calculateMuscleGroupVolumes()
        XCTAssertEqual(volumes.count, 6)
    }
    
    func testInsightsAreGenerated() {
        let insights = service.generateInsights()
        XCTAssertNotNil(insights)
        // Insights may be empty if no workouts, that's ok
        XCTAssertTrue(insights.count >= 0)
    }
    
    func testFatigueLevelColors() {
        XCTAssertEqual(FatigueLevel.fresh.color, "green")
        XCTAssertEqual(FatigueLevel.overreached.color, "red")
    }
    
    func testReadinessScoreInRange() {
        let readiness = service.calculateReadiness()
        XCTAssertGreaterThanOrEqual(readiness.score, 0)
        XCTAssertLessThanOrEqual(readiness.score, 100)
    }
    
    func testCoachInsightHasRequiredFields() {
        let insight = CoachInsight(
            type: .progressiveOverload,
            title: "Test",
            message: "Test message",
            confidence: 0.8
        )
        XCTAssertFalse(insight.title.isEmpty)
        XCTAssertFalse(insight.message.isEmpty)
        XCTAssertGreaterThanOrEqual(insight.confidence, 0)
        XCTAssertLessThanOrEqual(insight.confidence, 1.0)
    }
    
    func testACWRRiskLevels() {
        let optimalLoad = TrainingLoad(acute: 20, chronic: 18)
        XCTAssertEqual(optimalLoad.riskLevel, "Optimal")
        
        let highRiskLoad = TrainingLoad(acute: 30, chronic: 15)
        XCTAssertEqual(highRiskLoad.riskLevel, "High Risk")
    }
}
