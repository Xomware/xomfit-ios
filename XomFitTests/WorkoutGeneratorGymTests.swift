import XCTest
@testable import Xomfit

/// Gym-aware generation (#517): the pool honours the active gym's equipment and
/// machines, and generated exercises carry the machine to log them on.
final class WorkoutGeneratorGymTests: XCTestCase {

    private let gen = WorkoutGenerator()

    func testGymFiltersPoolToItsEquipment() {
        let home = GymProfile(name: "Home", equipment: [.dumbbell, .bodyweight])
        let pool = WorkoutGenerator.pool(for: [.chest, .quads], gym: home)
        XCTAssertFalse(pool.isEmpty)
        XCTAssertTrue(pool.allSatisfy { [.dumbbell, .bodyweight].contains($0.equipment) })
    }

    func testNoGymLeavesPoolUnfiltered() {
        let targets: Set<MuscleGroup> = [.back, .lats]
        XCTAssertEqual(WorkoutGenerator.pool(for: targets, gym: nil).map(\.id),
                       WorkoutGenerator.pool(for: targets).map(\.id))
        XCTAssertTrue(WorkoutGenerator.pool(for: targets).contains { $0.equipment == .barbell })
    }

    func testGymMachinesUnlockTheirExercisesWithoutGenericEquipment() {
        let gym = GymProfile(name: "Carbon", equipment: [],
                             machineIds: ["arsenal-reloaded-pendulum-squat", "arsenal-reloaded-linear-leg-press"])
        let ids = Set(WorkoutGenerator.pool(for: [.quads], gym: gym).map(\.id))
        XCTAssertEqual(ids, ["ex-pendulum-squat", "ex-leg-press", "ex-single-leg-press"])
    }

    func testGeneratedExercisesAreAssignedTheGymsMachine() {
        let gym = GymProfile(name: "Carbon", equipment: [],
                             machineIds: ["arsenal-reloaded-pendulum-squat", "arsenal-reloaded-linear-leg-press"])
        let template = gen.generate(targets: [.quads], timeBudgetMinutes: 30, targetSets: 3,
                                    familiarity: [:], seed: 7, gym: gym)
        XCTAssertFalse(template.exercises.isEmpty)
        for ex in template.exercises {
            let machine = ex.machineId.flatMap { MachineCatalog.byId[$0] }
            XCTAssertNotNil(machine, "\(ex.exercise.id) has no machine")
            XCTAssertTrue(machine?.exerciseIds.contains(ex.exercise.id) ?? false)
        }
    }

    func testNoGymAssignsNoMachines() {
        let template = gen.generate(targets: [.quads], timeBudgetMinutes: 30, targetSets: 3, familiarity: [:], seed: 7)
        XCTAssertTrue(template.exercises.allSatisfy { $0.machineId == nil })
    }

    func testRerollStaysWithinGym() {
        let gym = GymProfile(name: "Home", equipment: [.dumbbell])
        var template = gen.generate(targets: [.chest, .shoulders], timeBudgetMinutes: 45, targetSets: 3,
                                    familiarity: [:], seed: 3, gym: gym)
        for seed in UInt64(1)...20 {
            template = gen.reroll(slot: 0, in: template, targets: [.chest, .shoulders],
                                  familiarity: [:], seed: seed, gym: gym)
        }
        XCTAssertTrue(template.exercises.allSatisfy { $0.exercise.equipment == .dumbbell })
    }

    func testGymWithNothingForTargetsGivesEmptyTemplate() {
        let gym = GymProfile(name: "Bands only", equipment: [.bands])
        let template = gen.generate(targets: [.calves], timeBudgetMinutes: 30, targetSets: 3,
                                    familiarity: [:], seed: 1, gym: gym)
        XCTAssertTrue(template.exercises.isEmpty)
    }
}
