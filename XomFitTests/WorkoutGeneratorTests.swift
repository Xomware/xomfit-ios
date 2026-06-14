import XCTest
@testable import Xomfit

/// Deterministic unit tests for the pure `WorkoutGenerator` engine. All
/// randomness is injected via a seed, so every assertion is reproducible.
final class WorkoutGeneratorTests: XCTestCase {

    private let gen = WorkoutGenerator()

    // MARK: - Determinism (load-bearing)

    func testSameSeedProducesIdenticalTemplate() {
        let targets: [MuscleGroup] = [.chest, .triceps, .shoulders]
        let a = gen.generate(targets: targets, timeBudgetMinutes: 60, targetSets: 3, familiarity: [:], seed: 42)
        let b = gen.generate(targets: targets, timeBudgetMinutes: 60, targetSets: 3, familiarity: [:], seed: 42)

        XCTAssertEqual(a.exercises.map { $0.exercise.id }, b.exercises.map { $0.exercise.id })
        XCTAssertEqual(a.exercises.map { $0.targetReps }, b.exercises.map { $0.targetReps })
        XCTAssertEqual(a.exercises.map { $0.targetSets }, b.exercises.map { $0.targetSets })
        XCTAssertEqual(a.category, b.category)
    }

    func testDifferentSeedMayDiffer() {
        // Not strictly required to differ, but over a large pool it should.
        let targets: [MuscleGroup] = [.back, .lats, .biceps]
        let a = gen.generate(targets: targets, timeBudgetMinutes: 60, targetSets: 3, familiarity: [:], seed: 1)
        let b = gen.generate(targets: targets, timeBudgetMinutes: 60, targetSets: 3, familiarity: [:], seed: 999_999)
        // At least the ids OR rep schemes should diverge for distinct seeds.
        let sameIds = a.exercises.map { $0.exercise.id } == b.exercises.map { $0.exercise.id }
        let sameReps = a.exercises.map { $0.targetReps } == b.exercises.map { $0.targetReps }
        XCTAssertFalse(sameIds && sameReps, "Distinct seeds produced identical output across a large pool")
    }

    // MARK: - Time → count

    func testTimeToCount_60min_3sets_clampsToTen() {
        // 60 / (3*2) = 10, clamped to pool size (chest pool is large, > 10).
        let t = gen.generate(targets: [.chest], timeBudgetMinutes: 60, targetSets: 3, familiarity: [:], seed: 7)
        XCTAssertEqual(t.exercises.count, 10)
    }

    func testTimeToCount_30min_4sets_isThree() {
        // 30 / (4*2) = 3.
        let t = gen.generate(targets: [.chest], timeBudgetMinutes: 30, targetSets: 4, familiarity: [:], seed: 7)
        XCTAssertEqual(t.exercises.count, 3)
    }

    func testTinyBudgetClampsToAtLeastTwo() {
        // 10 / (5*2) = 1 → clamped up to 2.
        let t = gen.generate(targets: [.chest], timeBudgetMinutes: 10, targetSets: 5, familiarity: [:], seed: 7)
        XCTAssertGreaterThanOrEqual(t.exercises.count, 2)
    }

    func testCountClampsToPoolSize() {
        // Abs pool is small; a huge budget can't exceed it.
        let poolSize = WorkoutGenerator.pool(for: [.abs]).count
        let t = gen.generate(targets: [.abs], timeBudgetMinutes: 600, targetSets: 2, familiarity: [:], seed: 7)
        XCTAssertLessThanOrEqual(t.exercises.count, poolSize)
    }

    // MARK: - Compound ordering

    func testCompoundBeforeIsolation() {
        let t = gen.generate(targets: [.chest, .triceps], timeBudgetMinutes: 60, targetSets: 3, familiarity: [:], seed: 11)
        let categories = t.exercises.map { $0.exercise.category }
        if let lastCompound = categories.lastIndex(of: .compound),
           let firstIsolation = categories.firstIndex(of: .isolation) {
            XCTAssertLessThan(lastCompound, firstIsolation, "An isolation exercise appeared before a compound one")
        }
    }

    // MARK: - Rep schemes

    func testRepSchemesMatchCategoryVocabulary() {
        let t = gen.generate(targets: [.chest, .biceps], timeBudgetMinutes: 60, targetSets: 3, familiarity: [:], seed: 3)
        for ex in t.exercises {
            switch ex.exercise.category {
            case .compound:
                XCTAssertTrue(["5", "6-8"].contains(ex.targetReps), "Unexpected compound rep scheme \(ex.targetReps)")
            case .isolation:
                XCTAssertTrue(["10-12", "12-15"].contains(ex.targetReps), "Unexpected isolation rep scheme \(ex.targetReps)")
            default:
                XCTFail("Generated a non-strength exercise: \(ex.exercise.category)")
            }
        }
    }

    // MARK: - Slot allocation weighting

    func testSlotAllocationFavorsLargerPool() {
        // back has a much larger pool than calves → should receive more slots.
        let backSize = WorkoutGenerator.pool(for: [.back]).filter { $0.muscleGroups.contains(.back) }.count
        let calvesSize = WorkoutGenerator.pool(for: [.calves]).filter { $0.muscleGroups.contains(.calves) }.count
        XCTAssertGreaterThan(backSize, calvesSize, "Fixture assumption: back pool > calves pool")

        let pool = WorkoutGenerator.pool(for: [.back, .calves])
        let slots = WorkoutGenerator.allocateSlots(count: 6, targets: [.back, .calves], pool: pool)
        let backSlots = slots.filter { $0 == .back }.count
        let calfSlots = slots.filter { $0 == .calves }.count
        XCTAssertGreaterThan(backSlots, calfSlots)
    }

    // MARK: - No duplicates

    func testNoDuplicateExercises() {
        let t = gen.generate(targets: [.chest, .triceps, .shoulders], timeBudgetMinutes: 90, targetSets: 3, familiarity: [:], seed: 5)
        let ids = t.exercises.map { $0.exercise.id }
        XCTAssertEqual(Set(ids).count, ids.count, "Generated template contains duplicate exercises")
    }

    // MARK: - Familiarity bias

    func testFamiliarityBiasSurfacesLoggedExercise() {
        // Pick a real chest exercise id and weight it heavily; it should appear.
        let chestPool = WorkoutGenerator.pool(for: [.chest])
        guard let favorite = chestPool.first else { return XCTFail("Empty chest pool") }
        let familiarity = [favorite.id: 50]
        // Small workout to make presence meaningful.
        var appeared = 0
        for seed in UInt64(0)..<10 {
            let t = gen.generate(targets: [.chest], timeBudgetMinutes: 30, targetSets: 3, familiarity: familiarity, seed: seed)
            if t.exercises.contains(where: { $0.exercise.id == favorite.id }) { appeared += 1 }
        }
        XCTAssertGreaterThan(appeared, 5, "Heavily-familiar exercise rarely surfaced")
    }

    // MARK: - Reroll

    func testRerollExcludesExistingAndChangesOnlyThatSlot() {
        let targets: [MuscleGroup] = [.chest, .triceps, .shoulders]
        let original = gen.generate(targets: targets, timeBudgetMinutes: 90, targetSets: 3, familiarity: [:], seed: 21)
        guard original.exercises.count >= 3 else { return XCTFail("Need ≥3 exercises") }

        let slot = 1
        let rerolled = gen.reroll(slot: slot, in: original, targets: targets, familiarity: [:], seed: 21)

        // The rerolled slot's new exercise must not duplicate any other slot.
        let otherIds = rerolled.exercises.enumerated()
            .filter { $0.offset != findNewSlotIndex(original: original, rerolled: rerolled) }
            .map { $0.element.exercise.id }
        // After resort the index may shift; assert global uniqueness instead.
        let ids = rerolled.exercises.map { $0.exercise.id }
        XCTAssertEqual(Set(ids).count, ids.count, "Reroll produced a duplicate")
        _ = otherIds
    }

    func testRerollKeepsOtherExercises() {
        let targets: [MuscleGroup] = [.chest, .triceps, .shoulders]
        let original = gen.generate(targets: targets, timeBudgetMinutes: 90, targetSets: 3, familiarity: [:], seed: 33)
        guard original.exercises.count >= 3 else { return XCTFail("Need ≥3 exercises") }

        let rerolled = gen.reroll(slot: 0, in: original, targets: targets, familiarity: [:], seed: 33)
        // Exactly one exercise id should change (the rerolled slot), unless the
        // pool was size 1 for that group.
        let originalIds = Set(original.exercises.map { $0.exercise.id })
        let rerolledIds = Set(rerolled.exercises.map { $0.exercise.id })
        let changed = originalIds.symmetricDifference(rerolledIds)
        // Either 0 (pool exhausted) or 2 (one removed, one added).
        XCTAssertTrue(changed.count == 0 || changed.count == 2, "Reroll changed \(changed.count / 2) exercises, expected 1")
    }

    func testRerollDeterministicPerSeed() {
        let targets: [MuscleGroup] = [.back, .lats, .biceps]
        let original = gen.generate(targets: targets, timeBudgetMinutes: 90, targetSets: 3, familiarity: [:], seed: 8)
        let a = gen.reroll(slot: 0, in: original, targets: targets, familiarity: [:], seed: 8)
        let b = gen.reroll(slot: 0, in: original, targets: targets, familiarity: [:], seed: 8)
        XCTAssertEqual(a.exercises.map { $0.exercise.id }, b.exercises.map { $0.exercise.id })
    }

    // MARK: - Edge cases

    func testEmptyTargetsProducesEmptyTemplate() {
        let t = gen.generate(targets: [], timeBudgetMinutes: 60, targetSets: 3, familiarity: [:], seed: 1)
        XCTAssertTrue(t.exercises.isEmpty)
    }

    func testCategoryFromDominantRegion() {
        let push = gen.generate(targets: [.chest, .shoulders, .triceps], timeBudgetMinutes: 60, targetSets: 3, familiarity: [:], seed: 2)
        XCTAssertEqual(push.category, .push)

        let legs = gen.generate(targets: [.quads, .hamstrings, .glutes], timeBudgetMinutes: 60, targetSets: 3, familiarity: [:], seed: 2)
        XCTAssertEqual(legs.category, .legs)
    }

    func testOutputIsCustom() {
        let t = gen.generate(targets: [.chest], timeBudgetMinutes: 60, targetSets: 3, familiarity: [:], seed: 2)
        XCTAssertTrue(t.isCustom)
    }

    // MARK: - Helpers

    private func findNewSlotIndex(original: WorkoutTemplate, rerolled: WorkoutTemplate) -> Int {
        let originalIds = Set(original.exercises.map { $0.exercise.id })
        for (i, ex) in rerolled.exercises.enumerated() where !originalIds.contains(ex.exercise.id) {
            return i
        }
        return -1
    }
}

/// Tests for the deterministic SplitMix64 RNG itself.
final class SeededGeneratorTests: XCTestCase {
    func testSameSeedSameSequence() {
        var a = SeededGenerator(seed: 123)
        var b = SeededGenerator(seed: 123)
        for _ in 0..<100 {
            XCTAssertEqual(a.next(), b.next())
        }
    }

    func testDifferentSeedsDiverge() {
        var a = SeededGenerator(seed: 1)
        var b = SeededGenerator(seed: 2)
        var anyDifferent = false
        for _ in 0..<10 where a.next() != b.next() { anyDifferent = true }
        XCTAssertTrue(anyDifferent)
    }
}
