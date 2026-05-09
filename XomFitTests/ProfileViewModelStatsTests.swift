import XCTest
@testable import XomFit

@MainActor
final class ProfileViewModelStatsTests: XCTestCase {

    // MARK: - Helpers

    /// Builds a workout `n` days ago from the given exercise(s). Sets are simple
    /// 5x5 unless overridden.
    private func makeWorkout(
        id: String = UUID().uuidString,
        daysAgo: Int,
        exercises: [WorkoutExercise]
    ) -> Workout {
        let start = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return Workout(
            id: id,
            userId: "user-1",
            name: "Test",
            exercises: exercises,
            startTime: start,
            endTime: start.addingTimeInterval(3600),
            notes: nil,
            location: nil,
            rating: nil
        )
    }

    private func makeExercise(
        id: String = UUID().uuidString,
        exercise: Exercise,
        weight: Double,
        reps: Int,
        sets: Int,
        laterality: Laterality = .bilateral
    ) -> WorkoutExercise {
        let setRows: [WorkoutSet] = (0..<sets).map { i in
            WorkoutSet(
                id: "\(id)-set-\(i)",
                exerciseId: exercise.id,
                weight: weight,
                reps: reps,
                rpe: 8,
                isPersonalRecord: false,
                completedAt: Date()
            )
        }
        return WorkoutExercise(
            id: id,
            exercise: exercise,
            sets: setRows,
            notes: nil,
            selectedLaterality: laterality
        )
    }

    // MARK: - Volume Trend

    func testVolumeTrend30dProducesFourBuckets() {
        let sut = ProfileViewModel()
        let workouts = [
            makeWorkout(daysAgo: 2, exercises: [makeExercise(exercise: .benchPress, weight: 100, reps: 5, sets: 3)]),
            makeWorkout(daysAgo: 10, exercises: [makeExercise(exercise: .benchPress, weight: 100, reps: 5, sets: 3)]),
            makeWorkout(daysAgo: 18, exercises: [makeExercise(exercise: .benchPress, weight: 100, reps: 5, sets: 3)]),
            makeWorkout(daysAgo: 25, exercises: [makeExercise(exercise: .benchPress, weight: 100, reps: 5, sets: 3)])
        ]

        sut.computeDerivedStats(workouts: workouts)

        XCTAssertEqual(sut.volumeTrend30d.count, 4)
        // Each bucket should have 1500 (100 * 5 * 3)
        for bucket in sut.volumeTrend30d {
            XCTAssertEqual(bucket.volume, 1500, accuracy: 0.01)
        }
    }

    func testVolumeTrendExcludesWorkoutsOlderThan30Days() {
        let sut = ProfileViewModel()
        let workouts = [
            makeWorkout(daysAgo: 60, exercises: [makeExercise(exercise: .benchPress, weight: 100, reps: 5, sets: 3)]),
            makeWorkout(daysAgo: 5, exercises: [makeExercise(exercise: .benchPress, weight: 100, reps: 5, sets: 3)])
        ]

        sut.computeDerivedStats(workouts: workouts)

        let total = sut.volumeTrend30d.reduce(0) { $0 + $1.volume }
        XCTAssertEqual(total, 1500, accuracy: 0.01, "Only the recent workout should count")
    }

    // MARK: - Consistency

    func testWorkoutsPerWeekAndAverage() {
        let sut = ProfileViewModel()
        // 1 workout in last 7d, 2 in week before, 0 in week before that, 3 in oldest week
        let workouts = [
            makeWorkout(daysAgo: 3, exercises: [makeExercise(exercise: .benchPress, weight: 100, reps: 5, sets: 3)]),
            makeWorkout(daysAgo: 9, exercises: [makeExercise(exercise: .benchPress, weight: 100, reps: 5, sets: 3)]),
            makeWorkout(daysAgo: 12, exercises: [makeExercise(exercise: .benchPress, weight: 100, reps: 5, sets: 3)]),
            makeWorkout(daysAgo: 22, exercises: [makeExercise(exercise: .benchPress, weight: 100, reps: 5, sets: 3)]),
            makeWorkout(daysAgo: 24, exercises: [makeExercise(exercise: .benchPress, weight: 100, reps: 5, sets: 3)]),
            makeWorkout(daysAgo: 27, exercises: [makeExercise(exercise: .benchPress, weight: 100, reps: 5, sets: 3)])
        ]

        sut.computeDerivedStats(workouts: workouts)

        XCTAssertEqual(sut.workoutsPerWeek4w.count, 4)
        XCTAssertEqual(sut.workoutsPerWeek4w.reduce(0, +), 6)
        XCTAssertEqual(sut.avgWorkoutsPerWeek, 6.0 / 4.0, accuracy: 0.001)
    }

    // MARK: - Top Exercises

    func testTopExercisesSortedAndCappedAtFive() {
        let sut = ProfileViewModel()
        let exercises: [Exercise] = (0..<7).map { i in
            Exercise(
                id: "ex-\(i)",
                name: "Exercise \(i)",
                muscleGroups: [.chest],
                equipment: .barbell,
                category: .compound,
                description: "",
                tips: []
            )
        }
        // Each subsequent exercise has more volume than the previous.
        let workouts = exercises.enumerated().map { idx, ex in
            makeWorkout(
                daysAgo: idx,
                exercises: [makeExercise(exercise: ex, weight: Double((idx + 1) * 100), reps: 5, sets: 3)]
            )
        }

        sut.computeDerivedStats(workouts: workouts)

        XCTAssertEqual(sut.topExercisesByVolume.count, 5)
        // Highest volume should be first
        let volumes = sut.topExercisesByVolume.map { $0.volume }
        XCTAssertEqual(volumes, volumes.sorted(by: >))
        // Top exercise is the last one we added (700 * 5 * 3 = 10500)
        XCTAssertEqual(sut.topExercisesByVolume.first?.name, "Exercise 6")
        XCTAssertEqual(sut.topExercisesByVolume.first?.volume, 10500, accuracy: 0.01)
    }

    func testTopExercisesLateralityMultiplierApplies() {
        let sut = ProfileViewModel()
        let bilateralWorkout = makeWorkout(
            id: "bilateral",
            daysAgo: 2,
            exercises: [makeExercise(exercise: .benchPress, weight: 100, reps: 5, sets: 3, laterality: .bilateral)]
        )
        let unilateralWorkout = makeWorkout(
            id: "unilateral",
            daysAgo: 5,
            exercises: [makeExercise(exercise: .squat, weight: 100, reps: 5, sets: 3, laterality: .unilateral)]
        )

        sut.computeDerivedStats(workouts: [bilateralWorkout, unilateralWorkout])

        let bench = sut.topExercisesByVolume.first { $0.name == "Bench Press" }
        let squat = sut.topExercisesByVolume.first { $0.name == "Squat" }
        XCTAssertEqual(bench?.volume, 1500, accuracy: 0.01)
        // Unilateral should double: 100 * 5 * 3 * 2 = 3000
        XCTAssertEqual(squat?.volume, 3000, accuracy: 0.01)
    }

    func testTopExercisesAggregatesAcrossWorkouts() {
        let sut = ProfileViewModel()
        let workouts = (0..<3).map { i in
            makeWorkout(
                id: "w-\(i)",
                daysAgo: i + 1,
                exercises: [makeExercise(exercise: .benchPress, weight: 100, reps: 5, sets: 3)]
            )
        }

        sut.computeDerivedStats(workouts: workouts)

        XCTAssertEqual(sut.topExercisesByVolume.count, 1)
        XCTAssertEqual(sut.topExercisesByVolume.first?.volume, 4500, accuracy: 0.01)
        XCTAssertEqual(sut.topExercisesByVolume.first?.setCount, 9)
    }

    // MARK: - PR of the Month

    func testPROfTheMonthPicksHighestPercentImprovement() {
        let sut = ProfileViewModel()
        sut.allPRs = [
            // Within 30d, 10% improvement
            PersonalRecord(
                id: "pr-1", userId: "u", exerciseId: "e1", exerciseName: "Bench",
                weight: 220, reps: 3,
                date: Date().addingTimeInterval(-86400 * 5),
                previousBest: 200
            ),
            // Within 30d, 20% improvement (should win)
            PersonalRecord(
                id: "pr-2", userId: "u", exerciseId: "e2", exerciseName: "Squat",
                weight: 360, reps: 1,
                date: Date().addingTimeInterval(-86400 * 10),
                previousBest: 300
            ),
            // Within 30d, 5% improvement
            PersonalRecord(
                id: "pr-3", userId: "u", exerciseId: "e3", exerciseName: "Deadlift",
                weight: 420, reps: 1,
                date: Date().addingTimeInterval(-86400 * 2),
                previousBest: 400
            )
        ]

        sut.computeDerivedStats(workouts: [])

        XCTAssertEqual(sut.prOfTheMonth?.id, "pr-2")
    }

    func testPROfTheMonthExcludesPRsOlderThan30Days() {
        let sut = ProfileViewModel()
        sut.allPRs = [
            PersonalRecord(
                id: "pr-old", userId: "u", exerciseId: "e1", exerciseName: "Old",
                weight: 500, reps: 1,
                date: Date().addingTimeInterval(-86400 * 60),
                previousBest: 100
            )
        ]

        sut.computeDerivedStats(workouts: [])

        XCTAssertNil(sut.prOfTheMonth)
    }

    func testPROfTheMonthRequiresPositiveImprovement() {
        let sut = ProfileViewModel()
        sut.allPRs = [
            // Equal weight = 0% improvement, should be filtered
            PersonalRecord(
                id: "pr-flat", userId: "u", exerciseId: "e1", exerciseName: "Flat",
                weight: 200, reps: 1,
                date: Date().addingTimeInterval(-86400 * 3),
                previousBest: 200
            ),
            // No previousBest, should be filtered
            PersonalRecord(
                id: "pr-noprev", userId: "u", exerciseId: "e2", exerciseName: "First",
                weight: 100, reps: 1,
                date: Date(),
                previousBest: nil
            )
        ]

        sut.computeDerivedStats(workouts: [])

        XCTAssertNil(sut.prOfTheMonth)
    }

    func testPROfTheMonthIsNilWhenNoPRs() {
        let sut = ProfileViewModel()
        sut.allPRs = []

        sut.computeDerivedStats(workouts: [])

        XCTAssertNil(sut.prOfTheMonth)
    }

    func testPROfTheMonthTiebreaksByMostRecentDate() {
        let sut = ProfileViewModel()
        sut.allPRs = [
            // Same 10% improvement, older date
            PersonalRecord(
                id: "pr-old", userId: "u", exerciseId: "e1", exerciseName: "Old",
                weight: 110, reps: 1,
                date: Date().addingTimeInterval(-86400 * 10),
                previousBest: 100
            ),
            // Same 10% improvement, newer date — should win
            PersonalRecord(
                id: "pr-new", userId: "u", exerciseId: "e2", exerciseName: "New",
                weight: 220, reps: 1,
                date: Date().addingTimeInterval(-86400 * 1),
                previousBest: 200
            )
        ]

        sut.computeDerivedStats(workouts: [])

        XCTAssertEqual(sut.prOfTheMonth?.id, "pr-new")
    }
}
