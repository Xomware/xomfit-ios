import XCTest
@testable import Xomfit

/// Covers the two behaviours that make the active-workout flow continuous:
/// the shared cursor (one "where am I" across list and focus mode) and set
/// skipping (a set you decide not to do stops blocking the workout).
@MainActor
final class WorkoutSkipCursorTests: XCTestCase {

    private var sut: WorkoutLoggerViewModel!

    override func setUp() {
        super.setUp()
        sut = WorkoutLoggerViewModel()
        sut.startWorkout(name: "Test", userId: "test-user")
    }

    override func tearDown() {
        sut.discardWorkout()
        sut = nil
        super.tearDown()
    }

    /// Adds `count` exercises, each carrying `sets` empty sets.
    @discardableResult
    private func seed(exercises count: Int, sets: Int) -> [Exercise] {
        let picked = Array(ExerciseDatabase.all.prefix(count))
        for exercise in picked {
            sut.addExercise(exercise)
            let idx = sut.exercises.count - 1
            // addExercise seeds some sets already; normalise to `sets`.
            while sut.exercises[idx].sets.count < sets { sut.addSet(to: idx) }
            while sut.exercises[idx].sets.count > sets {
                sut.removeSet(exerciseIndex: idx, setIndex: sut.exercises[idx].sets.count - 1)
            }
        }
        // Land the cursor at the start regardless of what seeding did.
        sut.setCursor(exercise: 0, set: 0)
        return picked
    }

    // MARK: - Skip semantics

    func testSkippedSetIsNotPending() {
        seed(exercises: 1, sets: 3)
        sut.toggleSkip(exerciseIndex: 0, setIndex: 1)

        let set = sut.exercises[0].sets[1]
        XCTAssertTrue(set.isSkipped)
        XCTAssertFalse(set.isPending, "A skipped set must stop counting as work remaining")
        XCTAssertFalse(set.isCompleted, "Skipping is not the same as completing")
    }

    /// The load-bearing one: before skip existed, an abandoned set left the
    /// workout permanently incomplete.
    func testSkippedSetDoesNotBlockCompletion() {
        seed(exercises: 1, sets: 2)
        sut.completeSet(exerciseIndex: 0, setIndex: 0)
        XCTAssertFalse(sut.allExercisesComplete)

        sut.toggleSkip(exerciseIndex: 0, setIndex: 1)
        XCTAssertTrue(sut.allExercisesComplete, "One done + one skipped means the exercise is finished")
    }

    func testUnskipRestoresPending() {
        seed(exercises: 1, sets: 2)
        sut.toggleSkip(exerciseIndex: 0, setIndex: 1)
        sut.toggleSkip(exerciseIndex: 0, setIndex: 1)

        XCTAssertTrue(sut.exercises[0].sets[1].isPending)
        XCTAssertFalse(sut.allExercisesComplete)
    }

    func testSkippingCompletedSetClearsCompletion() {
        seed(exercises: 1, sets: 2)
        sut.completeSet(exerciseIndex: 0, setIndex: 0)
        sut.toggleSkip(exerciseIndex: 0, setIndex: 0)

        let set = sut.exercises[0].sets[0]
        XCTAssertTrue(set.isSkipped)
        XCTAssertFalse(set.isCompleted, "A set cannot be both done and skipped")
        XCTAssertFalse(set.isPersonalRecord)
    }

    func testSkippingCursorSetAdvancesPastIt() {
        seed(exercises: 1, sets: 3)
        sut.setCursor(exercise: 0, set: 0)

        sut.toggleSkip(exerciseIndex: 0, setIndex: 0)

        XCTAssertEqual(sut.focusSetIndex, 1, "Cursor must not sit on a set the lifter just dismissed")
    }

    func testSkippedSetsAreNotSaved() {
        seed(exercises: 1, sets: 3)
        sut.completeSet(exerciseIndex: 0, setIndex: 0)
        sut.toggleSkip(exerciseIndex: 0, setIndex: 1)

        // `finishWorkout` keeps only completed sets, so the skipped one and the
        // untouched one both fall out.
        let saved = sut.exercises[0].sets.filter { $0.isCompleted }
        XCTAssertEqual(saved.count, 1)
        XCTAssertFalse(saved.contains { $0.isSkipped })
    }

    func testSkipSurvivesEncodeDecodeRoundTrip() throws {
        seed(exercises: 1, sets: 2)
        sut.toggleSkip(exerciseIndex: 0, setIndex: 0)

        let data = try JSONEncoder().encode(sut.exercises)
        let restored = try JSONDecoder().decode([WorkoutExercise].self, from: data)

        XCTAssertTrue(restored[0].sets[0].isSkipped, "Skip state must survive session persistence")
        XCTAssertFalse(restored[0].sets[1].isSkipped)
    }

    /// Sessions persisted before `skippedAt` existed must still decode.
    func testLegacySetDecodesAsNotSkipped() throws {
        let legacy = """
        {
          "id": "s1",
          "exerciseId": "e1",
          "weight": 135,
          "reps": 8,
          "isPersonalRecord": false,
          "completedAt": 0,
          "weightMode": "total",
          "isDropSet": false
        }
        """.data(using: .utf8)!

        let set = try JSONDecoder().decode(WorkoutSet.self, from: legacy)
        XCTAssertFalse(set.isSkipped)
        XCTAssertNil(set.skippedAt)
    }

    // MARK: - Shared cursor

    func testSetCursorMovesBothIndices() {
        seed(exercises: 2, sets: 3)
        sut.setCursor(exercise: 1, set: 2)

        XCTAssertEqual(sut.focusExerciseIndex, 1)
        XCTAssertEqual(sut.focusSetIndex, 2)
    }

    func testSetCursorIgnoresOutOfBounds() {
        seed(exercises: 1, sets: 2)
        sut.setCursor(exercise: 0, set: 1)

        sut.setCursor(exercise: 99, set: 0)
        sut.setCursor(exercise: 0, set: 99)

        XCTAssertEqual(sut.focusExerciseIndex, 0)
        XCTAssertEqual(sut.focusSetIndex, 1, "An invalid target must not strand the cursor")
    }

    /// Completing a set in list mode used to leave the cursor behind, so
    /// zooming into focus mode landed on the set you'd just finished.
    func testCompletingSetAdvancesCursor() {
        seed(exercises: 1, sets: 3)
        sut.setCursor(exercise: 0, set: 0)

        sut.completeSet(exerciseIndex: 0, setIndex: 0)

        XCTAssertEqual(sut.focusSetIndex, 1)
    }

    func testCompletingLastSetAdvancesToNextExercise() {
        seed(exercises: 2, sets: 1)
        sut.setCursor(exercise: 0, set: 0)

        sut.completeSet(exerciseIndex: 0, setIndex: 0)

        XCTAssertEqual(sut.focusExerciseIndex, 1)
        XCTAssertEqual(sut.focusSetIndex, 0)
    }

    /// Completing a set that isn't the cursor must not drag the cursor along.
    func testCompletingNonCursorSetLeavesCursorAlone() {
        seed(exercises: 1, sets: 3)
        sut.setCursor(exercise: 0, set: 0)

        sut.completeSet(exerciseIndex: 0, setIndex: 2)

        XCTAssertEqual(sut.focusSetIndex, 0)
    }

    func testFocusAdvanceStepsOverSkippedSets() {
        seed(exercises: 1, sets: 4)
        sut.setCursor(exercise: 0, set: 0)
        sut.toggleSkip(exerciseIndex: 0, setIndex: 1)
        sut.toggleSkip(exerciseIndex: 0, setIndex: 2)
        sut.setCursor(exercise: 0, set: 0)

        sut.focusAdvance()

        XCTAssertEqual(sut.focusSetIndex, 3, "Advance must land on the next set actually owed")
    }
}
