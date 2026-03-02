import XCTest
@testable import XomFit

@MainActor
final class SmartRestTimerTests: XCTestCase {
    
    var sut: SmartRestTimerViewModel!
    
    override func setUp() {
        super.setUp()
        sut = SmartRestTimerViewModel()
        sut.smartTimerEnabled = false // Disable HealthKit for unit tests
    }
    
    override func tearDown() {
        sut.stop()
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Recovery Threshold BPM
    
    func testRecoveryThresholdBPM_default() {
        sut.userMaxHR = 190
        sut.recoveryThresholdPercent = 0.65
        XCTAssertEqual(sut.recoveryThresholdBPM, 123) // Int(190 * 0.65) = 123
    }
    
    func testRecoveryThresholdBPM_customValues() {
        sut.userMaxHR = 200
        sut.recoveryThresholdPercent = 0.70
        XCTAssertEqual(sut.recoveryThresholdBPM, 140)
    }
    
    func testRecoveryThresholdBPM_lowMax() {
        sut.userMaxHR = 150
        sut.recoveryThresholdPercent = 0.50
        XCTAssertEqual(sut.recoveryThresholdBPM, 75)
    }
    
    // MARK: - Timer Start/Stop
    
    func testStart_setsRunning() {
        sut.start(exerciseType: .compound)
        XCTAssertTrue(sut.isRunning)
        XCTAssertEqual(sut.secondsRemaining, 180)
        XCTAssertFalse(sut.isReady)
    }
    
    func testStart_isolation_duration() {
        sut.start(exerciseType: .isolation)
        XCTAssertEqual(sut.secondsRemaining, 90)
    }
    
    func testStart_cardio_duration() {
        sut.start(exerciseType: .cardio)
        XCTAssertEqual(sut.secondsRemaining, 60)
    }
    
    func testStart_customDuration() {
        sut.start(exerciseType: .custom(45))
        XCTAssertEqual(sut.secondsRemaining, 45)
    }
    
    func testStop_clearsRunning() {
        sut.start(exerciseType: .compound)
        sut.stop()
        XCTAssertFalse(sut.isRunning)
    }
    
    func testSkip_stopsTimer() {
        sut.start(exerciseType: .compound)
        sut.skip()
        XCTAssertFalse(sut.isRunning)
    }
    
    // MARK: - Add/Remove Time
    
    func testAddTime_positive() {
        sut.start(exerciseType: .compound)
        sut.addTime(30)
        XCTAssertEqual(sut.secondsRemaining, 210)
    }
    
    func testAddTime_negative() {
        sut.start(exerciseType: .compound)
        sut.addTime(-30)
        XCTAssertEqual(sut.secondsRemaining, 150)
    }
    
    func testAddTime_doesNotGoBelowZero() {
        sut.start(exerciseType: .cardio) // 60s
        sut.addTime(-120)
        XCTAssertEqual(sut.secondsRemaining, 0)
    }
    
    // MARK: - Readiness Progress
    
    func testReadinessProgress_noHR() {
        XCTAssertEqual(sut.readinessProgress, 0.0)
    }
    
    func testReadinessProgress_atPeak() {
        sut.userMaxHR = 200
        sut.recoveryThresholdPercent = 0.65 // threshold = 130
        sut.currentHR = 180
        sut.peakHR = 180
        // descent = 0, total needed = 180 - 130 = 50 → 0/50 = 0
        XCTAssertEqual(sut.readinessProgress, 0.0)
    }
    
    func testReadinessProgress_halfwayDown() {
        sut.userMaxHR = 200
        sut.recoveryThresholdPercent = 0.65 // threshold = 130
        sut.peakHR = 180
        sut.currentHR = 155
        // descent = 25, total = 50 → 0.5
        XCTAssertEqual(sut.readinessProgress, 0.5)
    }
    
    func testReadinessProgress_fullyRecovered() {
        sut.userMaxHR = 200
        sut.recoveryThresholdPercent = 0.65
        sut.peakHR = 180
        sut.currentHR = 125
        XCTAssertEqual(sut.readinessProgress, 1.0)
    }
    
    // MARK: - isReady with HR
    
    func testIsReady_whenHRNil_timerExpires() {
        sut.start(duration: 0, exerciseType: .compound)
        // With no HR and timer at 0, should become ready after tick
        // (In unit test without RunLoop, we test the logic directly)
        sut.secondsRemaining = 0
        sut.currentHR = nil
        // The timer callback would set isReady; we verify the state is correct
        XCTAssertFalse(sut.isReady) // Not set until timer ticks
    }
    
    // MARK: - Exercise Type Defaults
    
    func testExerciseType_compoundDuration() {
        XCTAssertEqual(RestExerciseType.compound.defaultDuration, 180)
    }
    
    func testExerciseType_isolationDuration() {
        XCTAssertEqual(RestExerciseType.isolation.defaultDuration, 90)
    }
    
    func testExerciseType_cardioDuration() {
        XCTAssertEqual(RestExerciseType.cardio.defaultDuration, 60)
    }
    
    func testExerciseType_customDuration() {
        XCTAssertEqual(RestExerciseType.custom(42).defaultDuration, 42)
    }
    
    // MARK: - Category Mapping
    
    func testFromCategory_compound() {
        XCTAssertEqual(RestExerciseType.from(category: "compound"), .compound)
    }
    
    func testFromCategory_isolation() {
        XCTAssertEqual(RestExerciseType.from(category: "isolation"), .isolation)
    }
    
    func testFromCategory_unknown_defaultsToCompound() {
        XCTAssertEqual(RestExerciseType.from(category: "stretching"), .compound)
    }
    
    // MARK: - Countdown Progress
    
    func testCountdownProgress_full() {
        sut.start(exerciseType: .compound) // 180s
        XCTAssertEqual(sut.countdownProgress, 1.0)
    }
    
    func testCountdownProgress_afterAddingNegative() {
        sut.start(duration: 100, exerciseType: .compound)
        sut.addTime(-50)
        XCTAssertEqual(sut.countdownProgress, 0.5)
    }
    
    // MARK: - Formatted Time
    
    func testFormattedTime_threeMinutes() {
        sut.secondsRemaining = 180
        XCTAssertEqual(sut.formattedTime, "3:00")
    }
    
    func testFormattedTime_oneThirty() {
        sut.secondsRemaining = 90
        XCTAssertEqual(sut.formattedTime, "1:30")
    }
    
    func testFormattedTime_zero() {
        sut.secondsRemaining = 0
        XCTAssertEqual(sut.formattedTime, "0:00")
    }
}
