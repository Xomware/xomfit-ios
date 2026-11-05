import XCTest
@testable import Xomfit

/// The iPhone workout session that keeps XomFit alive behind the lock screen
/// (#519) has to follow the workout exactly: a session left running after a
/// discard would hold the app awake for nothing.
@MainActor
final class WorkoutKeepAliveTests: XCTestCase {

    private final class Recorder: WorkoutKeepAlive {
        var calls: [String] = []
        var startedFor: [Date] = []
        var recoveredFor: [Date?] = []
        func recover(resumableWorkoutStartedAt: Date?) {
            calls.append("recover")
            recoveredFor.append(resumableWorkoutStartedAt)
        }
        func start(workoutStartedAt: Date) {
            calls.append("start")
            startedFor.append(workoutStartedAt)
        }
        func pause() { calls.append("pause") }
        func resume() { calls.append("resume") }
        func end() { calls.append("end") }
    }

    private var sut: WorkoutLoggerViewModel!
    private var recorder: Recorder!

    override func setUp() {
        super.setUp()
        recorder = Recorder()
        sut = WorkoutLoggerViewModel()
        sut.keepAlive = recorder
    }

    override func tearDown() {
        sut.discardWorkout()
        sut = nil
        recorder = nil
        super.tearDown()
    }

    func testStartPauseResumeDiscard() {
        sut.startWorkout(name: "Push", userId: "test-user")
        XCTAssertEqual(recorder.startedFor, [sut.startTime])
        sut.togglePause()
        sut.togglePause()
        sut.discardWorkout()
        XCTAssertEqual(recorder.calls, ["start", "pause", "resume", "end"])
    }

    func testFinishEndsSession() async {
        sut.startWorkout(name: "Push", userId: "test-user")
        await sut.finishWorkout(userId: "test-user")
        XCTAssertEqual(recorder.calls.first, "start")
        XCTAssertEqual(recorder.calls.last, "end")
        XCTAssertFalse(recorder.calls.dropFirst().contains("start"))
    }

    /// The restored workout passes its original start, which is what lets the
    /// keep-alive tell its own recovered session from an older one.
    func testRestoreStartsSessionForOriginalStart() throws {
        sut.startWorkout(name: "Push", userId: "test-user")
        sut.addExercise(ExerciseDatabase.all[0])
        sut.saveActiveSession(force: true)
        let started = try XCTUnwrap(WorkoutLoggerViewModel.peekSavedSession()).startTime

        let relaunched = WorkoutLoggerViewModel()
        let relaunchedRecorder = Recorder()
        relaunched.keepAlive = relaunchedRecorder
        XCTAssertTrue(relaunched.restoreActiveSession())
        XCTAssertEqual(relaunchedRecorder.calls, ["start"])
        XCTAssertEqual(relaunchedRecorder.startedFor, [started])
        relaunched.keepAlive = Recorder()
        relaunched.endSession()
    }

    func testRecoverOffersSavedWorkout() throws {
        sut.startWorkout(name: "Push", userId: "test-user")
        sut.saveActiveSession(force: true)
        let started = try XCTUnwrap(WorkoutLoggerViewModel.peekSavedSession()).startTime

        let relaunched = WorkoutLoggerViewModel()
        let relaunchedRecorder = Recorder()
        relaunched.keepAlive = relaunchedRecorder
        relaunched.recoverKeepAlive()
        XCTAssertEqual(relaunchedRecorder.calls, ["recover"])
        XCTAssertEqual(relaunchedRecorder.recoveredFor, [started])
    }

    func testRecoverWithNothingSavedEnds() {
        WorkoutLoggerViewModel.clearSavedSession()
        sut.recoverKeepAlive()
        XCTAssertEqual(recorder.recoveredFor, [nil])
    }

    /// A workout already running has its own session; nothing recovered may
    /// take it over.
    func testRecoverDuringLiveWorkoutEnds() {
        sut.startWorkout(name: "Push", userId: "test-user")
        sut.saveActiveSession(force: true)
        sut.recoverKeepAlive()
        XCTAssertEqual(recorder.recoveredFor, [nil])
    }

    func testAdoptsSessionStartedDuringWorkout() {
        let workout = Date(timeIntervalSince1970: 1_000)
        XCTAssertTrue(PhoneWorkoutSession.adopts(sessionStartedAt: workout, workoutStartedAt: workout))
        XCTAssertTrue(PhoneWorkoutSession.adopts(
            sessionStartedAt: workout.addingTimeInterval(5), workoutStartedAt: workout
        ))
    }

    func testEndsSessionFromEarlierWorkout() {
        let workout = Date(timeIntervalSince1970: 1_000)
        XCTAssertFalse(PhoneWorkoutSession.adopts(
            sessionStartedAt: workout.addingTimeInterval(-1), workoutStartedAt: workout
        ))
    }

    func testEndsSessionWithNoWorkoutOrNoStart() {
        let date = Date(timeIntervalSince1970: 1_000)
        XCTAssertFalse(PhoneWorkoutSession.adopts(sessionStartedAt: date, workoutStartedAt: nil))
        XCTAssertFalse(PhoneWorkoutSession.adopts(sessionStartedAt: nil, workoutStartedAt: date))
    }
}
