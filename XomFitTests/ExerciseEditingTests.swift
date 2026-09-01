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
}
