import XCTest
@testable import Xomfit

/// The rest countdown is derived from an absolute end date, so it can't drift
/// when ticks are missed (app suspended, run loop busy) and survives a relaunch.
@MainActor
final class RestTimerWallClockTests: XCTestCase {

    private var sut: WorkoutLoggerViewModel!

    override func setUp() {
        super.setUp()
        sut = WorkoutLoggerViewModel()
        sut.startWorkout(name: "Test", userId: "test-user")
        sut.addExercise(ExerciseDatabase.all[0])
        sut.exercises[0].restSeconds = 60
    }

    override func tearDown() {
        sut.discardWorkout()
        sut = nil
        super.tearDown()
    }

    private func startRest() throws -> Date {
        sut.startRestTimer(for: 0)
        return try XCTUnwrap(sut.restEndDate)
    }

    func testStartSetsEndDateFromDuration() throws {
        let before = Date()
        let end = try startRest()
        XCTAssertEqual(end.timeIntervalSince(before), 60, accuracy: 1)
        XCTAssertEqual(sut.restTimeRemaining, 60)
    }

    /// The old tick subtracted one per call, so a 40s suspension cost nothing.
    func testTickAfterLongGapReadsWallClock() throws {
        let end = try startRest()
        sut.tickRestTimer(now: end.addingTimeInterval(-20))
        XCTAssertEqual(sut.restTimeRemaining, 20)
        sut.tickRestTimer(now: end.addingTimeInterval(15))
        XCTAssertEqual(sut.restTimeRemaining, -15, "Overtime keeps counting past zero")
        XCTAssertTrue(sut.isRestTimerActive)
    }

    func testPausedTickDoesNotMoveCountdown() throws {
        let end = try startRest()
        sut.togglePause()
        sut.tickRestTimer(now: end.addingTimeInterval(30))
        XCTAssertEqual(sut.restTimeRemaining, 60)
    }

    func testResumeShiftsEndDateByPausedTime() throws {
        let end = try startRest()
        sut.togglePause()
        sut.pausedAt = Date().addingTimeInterval(-10)
        sut.togglePause()
        let shifted = try XCTUnwrap(sut.restEndDate)
        XCTAssertEqual(shifted.timeIntervalSince(end), 10, accuracy: 0.5)
    }

    func testExtendMovesEndDate() throws {
        let end = try startRest()
        sut.extendRestTimer(30)
        XCTAssertEqual(sut.restEndDate, end.addingTimeInterval(30))
        XCTAssertEqual(sut.restTimeRemaining, 90)
        XCTAssertEqual(sut.restDuration, 90)
    }

    func testExtendWithoutRestDoesNothing() {
        sut.extendRestTimer(30)
        XCTAssertFalse(sut.isRestTimerActive)
        XCTAssertNil(sut.restEndDate)
        XCTAssertEqual(sut.restTimeRemaining, 0)
    }

    func testSkipClearsEndDate() throws {
        _ = try startRest()
        sut.skipRestTimer()
        XCTAssertNil(sut.restEndDate)
        XCTAssertFalse(sut.isRestTimerActive)
    }

    func testRestSurvivesRelaunch() throws {
        let end = try startRest()

        let relaunched = WorkoutLoggerViewModel()
        defer { relaunched.discardWorkout() }
        XCTAssertTrue(relaunched.restoreActiveSession())

        XCTAssertTrue(relaunched.isRestTimerActive)
        XCTAssertEqual(relaunched.restEndDate, end)
        XCTAssertEqual(relaunched.restDuration, 60)
        XCTAssertEqual(relaunched.restTimeRemaining, 60, accuracy: 1)
    }

    /// Pause isn't persisted, so a paused rest's end date would be stale.
    func testPausedRestIsNotRestored() throws {
        _ = try startRest()
        sut.togglePause()

        let relaunched = WorkoutLoggerViewModel()
        defer { relaunched.discardWorkout() }
        XCTAssertTrue(relaunched.restoreActiveSession())
        XCTAssertFalse(relaunched.isRestTimerActive)
        XCTAssertNil(relaunched.restEndDate)
    }

    /// Sessions saved by builds before the rest fields existed still decode.
    func testSnapshotWithoutRestFieldsDecodes() throws {
        sut.saveActiveSession(force: true)
        let saved = try XCTUnwrap(WorkoutLoggerViewModel.peekSavedSession())
        var json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(saved)) as? [String: Any]
        )
        json.removeValue(forKey: "restEndDate")
        json.removeValue(forKey: "restDuration")

        let decoded = try JSONDecoder().decode(
            WorkoutLoggerViewModel.PersistedSession.self,
            from: JSONSerialization.data(withJSONObject: json)
        )
        XCTAssertNil(decoded.restEndDate)
        XCTAssertEqual(decoded.restDuration, 0)
    }
}
