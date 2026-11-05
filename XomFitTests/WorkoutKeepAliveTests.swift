import XCTest
@testable import Xomfit

/// The iPhone workout session that keeps XomFit alive behind the lock screen
/// (#519) has to follow the workout exactly: a session left running after a
/// discard would hold the app awake for nothing.
@MainActor
final class WorkoutKeepAliveTests: XCTestCase {

    private final class Recorder: WorkoutKeepAlive {
        var calls: [String] = []
        func start() { calls.append("start") }
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

    func testRestoreStartsSession() {
        sut.startWorkout(name: "Push", userId: "test-user")
        sut.addExercise(ExerciseDatabase.all[0])

        let relaunched = WorkoutLoggerViewModel()
        let relaunchedRecorder = Recorder()
        relaunched.keepAlive = relaunchedRecorder
        XCTAssertTrue(relaunched.restoreActiveSession())
        XCTAssertEqual(relaunchedRecorder.calls, ["start"])
        relaunched.keepAlive = Recorder()
        relaunched.endSession()
    }
}
