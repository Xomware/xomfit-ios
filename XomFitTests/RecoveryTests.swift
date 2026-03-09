import XCTest
@testable import XomFit

final class RecoveryTests: XCTestCase {
    var service: RecoveryService!
    
    override func setUp() {
        super.setUp()
        service = RecoveryService.shared
    }
    
    func testMuscleGroupsInitialized() {
        XCTAssertGreaterThan(service.soreness.count, 0)
    }
    
    func testTenMuscleGroupsTracked() {
        XCTAssertEqual(service.muscleGroups.count, 10)
    }
    
    func testUpdateSoreness() {
        service.updateSoreness(muscleGroup: "Chest", level: .moderate)
        let chest = service.soreness.first { $0.muscleGroup == "Chest" }
        XCTAssertEqual(chest?.level, .moderate)
        // Reset
        service.updateSoreness(muscleGroup: "Chest", level: .none)
    }
    
    func testSleepLogging() {
        service.logSleep(hours: 8.0, quality: 4)
        let last = service.lastNightSleep()
        XCTAssertNotNil(last)
        XCTAssertEqual(last?.hoursSlept, 8.0)
        XCTAssertEqual(last?.quality, 4)
    }
    
    func testSleepRecoveryScore() {
        let entry = SleepEntry(hoursSlept: 8.0, quality: 5)
        XCTAssertGreaterThan(entry.recoveryScore, 70)
    }
    
    func testSleepRecoveryScorePoorSleep() {
        let entry = SleepEntry(hoursSlept: 5.0, quality: 2)
        let good = SleepEntry(hoursSlept: 9.0, quality: 5)
        XCTAssertLessThan(entry.recoveryScore, good.recoveryScore)
    }
    
    func testHRVLogging() {
        service.logHRV(hrv: 65.0, restingHR: 55)
        let avg = service.averageHRV(days: 1)
        XCTAssertGreaterThan(avg, 0)
    }
    
    func testReadinessCalculation() {
        let readiness = service.calculateDailyReadiness()
        XCTAssertGreaterThanOrEqual(readiness.score, 0)
        XCTAssertLessThanOrEqual(readiness.score, 100)
        XCTAssertNotNil(readiness.status)
    }
    
    func testOvertrainingRiskDefault() {
        // With no workouts, should not flag risk
        let risk = service.isOvertrainingRisk()
        XCTAssertFalse(risk) // No workouts = no risk
    }
    
    func testRecoveryTimeline() {
        let timeline = service.recoveryTimeline()
        XCTAssertEqual(timeline.count, service.muscleGroups.count)
    }
    
    func testSorenessLevelRecoveryDays() {
        XCTAssertEqual(SorenessLevel.none.recoveryDaysNeeded, 0)
        XCTAssertEqual(SorenessLevel.severe.recoveryDaysNeeded, 4)
    }
    
    func testMuscleSorenessIsReady() {
        let mild = MuscleSoreness(muscleGroup: "Chest", level: .mild)
        XCTAssertTrue(mild.isReady)
        
        let severe = MuscleSoreness(muscleGroup: "Chest", level: .severe)
        XCTAssertFalse(severe.isReady)
    }
    
    func testRecoveryStatusEmoji() {
        XCTAssertEqual(RecoveryStatus.train.emoji, "🟢")
        XCTAssertEqual(RecoveryStatus.rest.emoji, "🔴")
    }
}
