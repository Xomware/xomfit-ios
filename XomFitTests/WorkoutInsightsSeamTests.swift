import XCTest
@testable import Xomfit

/// Unit tests for the two shared seams introduced for the workout-generator epic:
/// Seam 2 (`WorkoutInsights.setsPerMuscleGroup`) and Seam 3 (`TrainingRegion` +
/// `MuscleGroup.region`).
final class WorkoutInsightsSeamTests: XCTestCase {

    // MARK: - Fixtures

    private func makeWorkout(
        id: String,
        startTime: Date,
        exercise: Exercise,
        setCount: Int
    ) -> Workout {
        let sets = (0..<setCount).map { i in
            WorkoutSet(
                id: "\(id)-s\(i)",
                exerciseId: exercise.id,
                weight: 100,
                reps: 8,
                rpe: nil,
                isPersonalRecord: false,
                completedAt: startTime
            )
        }
        return Workout(
            id: id,
            userId: "u1",
            name: "W",
            exercises: [WorkoutExercise(id: "\(id)-we", exercise: exercise, sets: sets, notes: nil)],
            startTime: startTime
        )
    }

    // MARK: - Seam 2 — set counting

    func testSetsPerMuscleGroupCountsEachTargetedMuscle() {
        // Bench Press targets chest, triceps, shoulders. 3 sets each.
        let bench = ExerciseDatabase.byId["ex-bench-flat"]!
        let workout = makeWorkout(id: "w1", startTime: Date(), exercise: bench, setCount: 3)

        let result = WorkoutInsights.setsPerMuscleGroup(workouts: [workout])

        for muscle in bench.muscleGroups {
            XCTAssertEqual(result[muscle], 3, "Expected 3 sets for \(muscle)")
        }
        // A muscle the exercise doesn't target should be absent.
        XCTAssertNil(result[.quads])
    }

    func testSetsPerMuscleGroupAccumulatesAcrossWorkouts() {
        let bench = ExerciseDatabase.byId["ex-bench-flat"]!
        let w1 = makeWorkout(id: "w1", startTime: Date(), exercise: bench, setCount: 2)
        let w2 = makeWorkout(id: "w2", startTime: Date(), exercise: bench, setCount: 4)

        let result = WorkoutInsights.setsPerMuscleGroup(workouts: [w1, w2])
        XCTAssertEqual(result[.chest], 6)
    }

    func testSetsPerMuscleGroupEmptyForNoWorkouts() {
        XCTAssertTrue(WorkoutInsights.setsPerMuscleGroup(workouts: []).isEmpty)
    }

    // MARK: - Seam 2 — windowed variant

    func testSetsPerMuscleGroupSinceExcludesOlder() {
        let bench = ExerciseDatabase.byId["ex-bench-flat"]!
        let now = Date()
        let recent = makeWorkout(id: "recent", startTime: now, exercise: bench, setCount: 3)
        let old = makeWorkout(id: "old", startTime: now.addingTimeInterval(-30 * 86_400), exercise: bench, setCount: 5)

        let cutoff = now.addingTimeInterval(-7 * 86_400)
        let result = WorkoutInsights.setsPerMuscleGroup(workouts: [recent, old], since: cutoff)

        // Only the recent workout's 3 sets should count.
        XCTAssertEqual(result[.chest], 3)
    }

    func testSetsPerMuscleGroupSinceIncludesBoundary() {
        let bench = ExerciseDatabase.byId["ex-bench-flat"]!
        let cutoff = Date()
        let atBoundary = makeWorkout(id: "b", startTime: cutoff, exercise: bench, setCount: 2)
        let result = WorkoutInsights.setsPerMuscleGroup(workouts: [atBoundary], since: cutoff)
        XCTAssertEqual(result[.chest], 2, "since: should be inclusive of the boundary (>=)")
    }

    // MARK: - Seam 3 — forward map (all 13 cases)

    func testRegionForwardMapAllThirteenCases() {
        let expected: [MuscleGroup: TrainingRegion] = [
            .chest: .push, .shoulders: .push, .triceps: .push,
            .back: .pull, .lats: .pull, .biceps: .pull, .traps: .pull, .forearms: .pull,
            .quads: .legs, .hamstrings: .legs, .glutes: .legs, .calves: .legs,
            .abs: .core
        ]
        // Every one of the 13 cases must be mapped and match the table.
        XCTAssertEqual(MuscleGroup.allCases.count, 13)
        for muscle in MuscleGroup.allCases {
            XCTAssertEqual(muscle.region, expected[muscle], "Wrong region for \(muscle)")
        }
    }

    // MARK: - Seam 3 — reverse map round-trips

    func testRegionReverseMap() {
        XCTAssertEqual(TrainingRegion.push.muscles, [.chest, .shoulders, .triceps])
        XCTAssertEqual(TrainingRegion.pull.muscles, [.back, .lats, .biceps, .traps, .forearms])
        XCTAssertEqual(TrainingRegion.legs.muscles, [.quads, .hamstrings, .glutes, .calves])
        XCTAssertEqual(TrainingRegion.core.muscles, [.abs])
    }

    func testReverseMapRoundTrips() {
        // Every muscle listed under a region must roll back up to that region.
        for region in TrainingRegion.allCases {
            for muscle in region.muscles {
                XCTAssertEqual(muscle.region, region, "\(muscle) under \(region) doesn't round-trip")
            }
        }
        // And the union of all region muscles covers all 13 exactly once.
        let all = TrainingRegion.allCases.flatMap { $0.muscles }
        XCTAssertEqual(Set(all), Set(MuscleGroup.allCases))
        XCTAssertEqual(all.count, MuscleGroup.allCases.count)
    }

    // MARK: - Seam 3 — templateCategory

    func testTemplateCategoryMapping() {
        XCTAssertEqual(TrainingRegion.push.templateCategory, .push)
        XCTAssertEqual(TrainingRegion.pull.templateCategory, .pull)
        XCTAssertEqual(TrainingRegion.legs.templateCategory, .legs)
        XCTAssertEqual(TrainingRegion.core.templateCategory, .custom)
    }
}
