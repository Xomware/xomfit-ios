import XCTest
@testable import Xomfit

/// Editing the exercise list mid-workout.
@MainActor
final class ExerciseEditingTests: XCTestCase {

    private func makeViewModel(count: Int) -> WorkoutLoggerViewModel {
        let vm = WorkoutLoggerViewModel()
        vm.startWorkout(name: "Test")
        for i in 0..<count { vm.addExercise(ExerciseDatabase.all[i]) }
        return vm
    }

    /// Removing the focused exercise used to leave `focusExerciseIndex`
    /// pointing at whatever slid into that slot — or one past the end when it
    /// was the last one, which is an out-of-bounds read waiting to happen.
    func testRemovingTheLastExerciseKeepsFocusInBounds() {
        let vm = makeViewModel(count: 3)
        vm.focusExerciseIndex = 2

        vm.removeExercise(at: 2)

        XCTAssertEqual(vm.exercises.count, 2)
        XCTAssertTrue(vm.exercises.indices.contains(vm.focusExerciseIndex))
        XCTAssertEqual(vm.focusExerciseIndex, 1)
    }

    func testRemovingEveryExerciseLeavesFocusAtZero() {
        let vm = makeViewModel(count: 1)
        vm.removeExercise(at: 0)

        XCTAssertTrue(vm.exercises.isEmpty)
        XCTAssertEqual(vm.focusExerciseIndex, 0)
    }

    func testRemovingResetsTheFocusedSet() {
        let vm = makeViewModel(count: 2)
        vm.focusSetIndex = 2

        vm.removeExercise(at: 0)

        XCTAssertEqual(vm.focusSetIndex, 0)
    }

    func testOutOfRangeRemovalIsIgnored() {
        let vm = makeViewModel(count: 2)
        vm.removeExercise(at: 99)
        XCTAssertEqual(vm.exercises.count, 2)
    }

    /// Swap keeps the slot and the sets. Removing and re-adding would send the
    /// exercise to the end of the workout and throw away its configured sets.
    func testReplaceKeepsPositionAndSets() {
        let vm = makeViewModel(count: 3)
        let originalSetCount = vm.exercises[1].sets.count
        let replacement = ExerciseDatabase.all[50]

        vm.replaceExercise(at: 1, with: replacement)

        XCTAssertEqual(vm.exercises[1].exercise.id, replacement.id)
        XCTAssertEqual(vm.exercises.count, 3)
        XCTAssertEqual(vm.exercises[1].sets.count, originalSetCount)
    }

    func testReplaceOutOfRangeIsIgnored() {
        let vm = makeViewModel(count: 1)
        let before = vm.exercises[0].exercise.id
        vm.replaceExercise(at: 5, with: ExerciseDatabase.all[10])
        XCTAssertEqual(vm.exercises[0].exercise.id, before)
    }

    // MARK: - Focus survives removal (#516)

    func testRemovingAboveTheFocusKeepsTheSameExerciseAndSet() {
        let vm = makeViewModel(count: 4)
        let focusedId = vm.exercises[2].id
        vm.focusExerciseIndex = 2
        vm.focusSetIndex = 1

        vm.removeExercise(at: 0)

        XCTAssertEqual(vm.focusExerciseIndex, 1)
        XCTAssertEqual(vm.exercises[vm.focusExerciseIndex].id, focusedId)
        XCTAssertEqual(vm.focusSetIndex, 1)
    }

    func testRemovingBelowTheFocusLeavesItAlone() {
        let vm = makeViewModel(count: 4)
        vm.focusExerciseIndex = 1
        vm.focusSetIndex = 2

        vm.removeExercise(at: 3)

        XCTAssertEqual(vm.focusExerciseIndex, 1)
        XCTAssertEqual(vm.focusSetIndex, 2)
    }

    func testRemovingTheFocusLandsOnTheNextExercisesFirstPendingSet() {
        let vm = makeViewModel(count: 3)
        let nextId = vm.exercises[2].id
        vm.exercises[2].sets[0].completedAt = Date()
        vm.focusExerciseIndex = 1

        vm.removeExercise(at: 1)

        XCTAssertEqual(vm.exercises[vm.focusExerciseIndex].id, nextId)
        XCTAssertEqual(vm.focusSetIndex, 1)
    }

    func testRemovalIsPersistedForResume() {
        let vm = makeViewModel(count: 3)
        vm.focusExerciseIndex = 2

        vm.removeExercise(at: 0)

        let saved = WorkoutLoggerViewModel.peekSavedSession()
        XCTAssertEqual(saved?.exercises.map(\.id), vm.exercises.map(\.id))
        XCTAssertEqual(saved?.focusExerciseIndex, 1)
    }

    // MARK: - Undo

    func testUndoRestoresTheExerciseInPlaceWithItsFocus() {
        let vm = makeViewModel(count: 3)
        let ids = vm.exercises.map(\.id)
        vm.focusExerciseIndex = 1
        vm.focusSetIndex = 2

        vm.removeExercise(at: 1)
        vm.undoRemoveExercise()

        XCTAssertEqual(vm.exercises.map(\.id), ids)
        XCTAssertEqual(vm.focusExerciseIndex, 1)
        XCTAssertEqual(vm.focusSetIndex, 2)
        XCTAssertNil(vm.lastRemovedExercise)
    }

    func testUndoAboveTheFocusShiftsItBack() {
        let vm = makeViewModel(count: 3)
        let focusedId = vm.exercises[2].id
        vm.focusExerciseIndex = 2

        vm.removeExercise(at: 0)
        vm.undoRemoveExercise()

        XCTAssertEqual(vm.exercises[vm.focusExerciseIndex].id, focusedId)
    }

    func testUndoAfterRemovingTheOnlyExercise() {
        let vm = makeViewModel(count: 1)
        let id = vm.exercises[0].id

        vm.removeExercise(at: 0)
        vm.undoRemoveExercise()

        XCTAssertEqual(vm.exercises.map(\.id), [id])
        XCTAssertEqual(vm.focusExerciseIndex, 0)
    }

    func testUndoWithNothingRemovedIsANoOp() {
        let vm = makeViewModel(count: 2)
        vm.undoRemoveExercise()
        XCTAssertEqual(vm.exercises.count, 2)
    }

    func testHasLoggedSetsOnlyCountsCompletedSets() {
        let vm = makeViewModel(count: 2)
        XCTAssertFalse(vm.hasLoggedSets(at: 0))

        vm.exercises[0].sets[0].completedAt = Date()

        XCTAssertTrue(vm.hasLoggedSets(at: 0))
        XCTAssertFalse(vm.hasLoggedSets(at: 1))
        XCTAssertFalse(vm.hasLoggedSets(at: 9))
    }

    // MARK: - Move

    func testMoveDownKeepsFocusOnTheSameExercise() {
        let vm = makeViewModel(count: 3)
        let ids = vm.exercises.map(\.id)
        vm.focusExerciseIndex = 0

        vm.moveExercise(from: 0, direction: 1)

        XCTAssertEqual(vm.exercises.map(\.id), [ids[1], ids[0], ids[2]])
        XCTAssertEqual(vm.focusExerciseIndex, 1)
    }

    func testMoveUpPastTheTopIsIgnored() {
        let vm = makeViewModel(count: 2)
        let ids = vm.exercises.map(\.id)

        vm.moveExercise(from: 0, direction: -1)

        XCTAssertEqual(vm.exercises.map(\.id), ids)
    }
}
