import XCTest
@testable import Xomfit

/// Superset grouping with an exercise the lifter picks.
///
/// Grouping used to be "group with the next exercise" and nothing else, so
/// pairing with anything further down the list meant reordering the workout to
/// make it adjacent.
@MainActor
final class SupersetPairingTests: XCTestCase {

    private func makeViewModel(exerciseCount: Int) -> WorkoutLoggerViewModel {
        let vm = WorkoutLoggerViewModel()
        vm.startWorkout(name: "Test")
        for i in 0..<exerciseCount {
            let exercise = ExerciseDatabase.all[i]
            vm.addExercise(exercise)
        }
        return vm
    }

    func testGroupsTwoNonAdjacentExercises() {
        let vm = makeViewModel(exerciseCount: 4)
        vm.groupSuperset(exerciseIndex: 0, with: 3)

        let group = vm.exercises[0].supersetGroupId
        XCTAssertNotNil(group)
        XCTAssertEqual(vm.exercises[3].supersetGroupId, group)
        XCTAssertNil(vm.exercises[1].supersetGroupId)
        XCTAssertNil(vm.exercises[2].supersetGroupId)
    }

    /// Joining an exercise already in a group adds to that group rather than
    /// starting a second one — which is what "superset these" means when one of
    /// them is already paired.
    func testJoiningAnExistingGroupExtendsIt() {
        let vm = makeViewModel(exerciseCount: 4)
        vm.groupSuperset(exerciseIndex: 0, with: 1)
        let group = vm.exercises[0].supersetGroupId

        vm.groupSuperset(exerciseIndex: 3, with: 1)

        XCTAssertEqual(vm.exercises[3].supersetGroupId, group)
        XCTAssertEqual(vm.exercises[0].supersetGroupId, group)
    }

    func testPairingWithItselfDoesNothing() {
        let vm = makeViewModel(exerciseCount: 2)
        vm.groupSuperset(exerciseIndex: 0, with: 0)
        XCTAssertNil(vm.exercises[0].supersetGroupId)
    }

    /// An index from a stale view must not trap.
    func testOutOfRangeIndicesAreIgnored() {
        let vm = makeViewModel(exerciseCount: 2)
        vm.groupSuperset(exerciseIndex: 0, with: 99)
        vm.groupSuperset(exerciseIndex: -1, with: 1)
        XCTAssertNil(vm.exercises[0].supersetGroupId)
        XCTAssertNil(vm.exercises[1].supersetGroupId)
    }

    func testCandidatesExcludeSelf() {
        let vm = makeViewModel(exerciseCount: 3)
        XCTAssertFalse(vm.supersetCandidates(for: 1).contains(1))
        XCTAssertEqual(Set(vm.supersetCandidates(for: 1)), [0, 2])
    }

    /// Offering an exercise already grouped with this one would be a no-op the
    /// lifter can tap.
    func testCandidatesExcludeExercisesAlreadyGroupedWithIt() {
        let vm = makeViewModel(exerciseCount: 3)
        vm.groupSuperset(exerciseIndex: 0, with: 2)

        XCTAssertEqual(vm.supersetCandidates(for: 0), [1])
    }
}
