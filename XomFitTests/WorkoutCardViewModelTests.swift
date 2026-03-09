import XCTest
@testable import XomFit

@MainActor
final class WorkoutCardViewModelTests: XCTestCase {

    // MARK: - Helpers

    private func makeWorkout(
        exercises: [WorkoutExercise] = [],
        startTime: Date = Date().addingTimeInterval(-3600),
        endTime: Date? = Date()
    ) -> Workout {
        Workout(
            id: UUID().uuidString,
            userId: "user-1",
            name: "Test Workout",
            exercises: exercises,
            startTime: startTime,
            endTime: endTime,
            notes: nil
        )
    }

    private func makeExercise(
        name: String = "Bench Press",
        exerciseId: String = "ex-1",
        sets: [WorkoutSet] = []
    ) -> WorkoutExercise {
        WorkoutExercise(
            id: UUID().uuidString,
            exercise: Exercise(id: exerciseId, name: name, muscleGroups: [.chest], equipment: .barbell, category: .compound, description: "", tips: []),
            sets: sets,
            notes: nil
        )
    }

    private func makeSet(
        exerciseId: String = "ex-1",
        weight: Double = 100,
        reps: Int = 5,
        isPR: Bool = false
    ) -> WorkoutSet {
        WorkoutSet(
            id: UUID().uuidString,
            exerciseId: exerciseId,
            weight: weight,
            reps: reps,
            rpe: nil,
            isPersonalRecord: isPR,
            completedAt: Date()
        )
    }

    // MARK: - Theme Auto-Selection

    func testThemeAutoSelectsFireWhenPRsExist() {
        let workout = makeWorkout(exercises: [
            makeExercise(sets: [makeSet(isPR: true)])
        ])
        let completed = WorkoutCardViewModel.buildCompletedWorkout(from: workout)
        let vm = WorkoutCardViewModel(completedWorkout: completed)
        XCTAssertEqual(vm.selectedTheme, .fire)
    }

    func testThemeAutoSelectsDefaultWhenNoPRs() {
        let workout = makeWorkout(exercises: [
            makeExercise(sets: [makeSet(isPR: false)])
        ])
        let completed = WorkoutCardViewModel.buildCompletedWorkout(from: workout)
        let vm = WorkoutCardViewModel(completedWorkout: completed)
        XCTAssertEqual(vm.selectedTheme, .default)
    }

    // MARK: - Build Completed Workout

    func testBuildExtractsTop3Exercises() {
        let workout = makeWorkout(exercises: [
            makeExercise(name: "Squat", exerciseId: "e1", sets: [makeSet(exerciseId: "e1", weight: 200, reps: 5)]),
            makeExercise(name: "Bench", exerciseId: "e2", sets: [makeSet(exerciseId: "e2", weight: 150, reps: 5)]),
            makeExercise(name: "Deadlift", exerciseId: "e3", sets: [makeSet(exerciseId: "e3", weight: 250, reps: 5)]),
            makeExercise(name: "Curl", exerciseId: "e4", sets: [makeSet(exerciseId: "e4", weight: 30, reps: 10)]),
        ])
        let completed = WorkoutCardViewModel.buildCompletedWorkout(from: workout)
        XCTAssertEqual(completed.exercises.count, 3)
        // Should be sorted by volume: Deadlift (1250), Squat (1000), Bench (750)
        XCTAssertEqual(completed.exercises[0].name, "Deadlift")
        XCTAssertEqual(completed.exercises[1].name, "Squat")
        XCTAssertEqual(completed.exercises[2].name, "Bench")
    }

    func testBuildWithFewerThan3Exercises() {
        let workout = makeWorkout(exercises: [
            makeExercise(name: "Squat", sets: [makeSet(weight: 200, reps: 5)])
        ])
        let completed = WorkoutCardViewModel.buildCompletedWorkout(from: workout)
        XCTAssertEqual(completed.exercises.count, 1)
    }

    // MARK: - Duration Formatting

    func testDurationFormatMinutesOnly() {
        XCTAssertEqual(WorkoutSummaryCardView.formatDuration(2700), "45m")
    }

    func testDurationFormatHoursAndMinutes() {
        XCTAssertEqual(WorkoutSummaryCardView.formatDuration(4980), "1h 23m")
    }

    func testDurationFormatExactHours() {
        XCTAssertEqual(WorkoutSummaryCardView.formatDuration(7200), "2h")
    }

    func testDurationFormatZero() {
        XCTAssertEqual(WorkoutSummaryCardView.formatDuration(0), "0m")
    }

    // MARK: - Volume Calculation

    func testTotalVolumeCalculation() {
        let workout = makeWorkout(exercises: [
            makeExercise(name: "Bench", sets: [
                makeSet(weight: 100, reps: 5),
                makeSet(weight: 100, reps: 5),
            ]),
            makeExercise(name: "Squat", sets: [
                makeSet(weight: 200, reps: 3),
            ]),
        ])
        let completed = WorkoutCardViewModel.buildCompletedWorkout(from: workout)
        XCTAssertEqual(completed.totalVolume, 1600, accuracy: 0.01) // 500 + 500 + 600
    }

    // MARK: - PR Count

    func testPRCountExtraction() {
        let workout = makeWorkout(exercises: [
            makeExercise(name: "Bench", sets: [
                makeSet(weight: 100, reps: 5, isPR: true),
                makeSet(weight: 95, reps: 5, isPR: false),
            ]),
            makeExercise(name: "Squat", sets: [
                makeSet(weight: 200, reps: 3, isPR: true),
            ]),
        ])
        let completed = WorkoutCardViewModel.buildCompletedWorkout(from: workout)
        XCTAssertEqual(completed.newPRs.count, 2)
    }

    func testNoPRs() {
        let workout = makeWorkout(exercises: [
            makeExercise(sets: [makeSet(isPR: false)])
        ])
        let completed = WorkoutCardViewModel.buildCompletedWorkout(from: workout)
        XCTAssertTrue(completed.newPRs.isEmpty)
    }

    // MARK: - Total Reps & Sets

    func testTotalSetsAndReps() {
        let workout = makeWorkout(exercises: [
            makeExercise(sets: [
                makeSet(weight: 100, reps: 5),
                makeSet(weight: 100, reps: 5),
                makeSet(weight: 100, reps: 3),
            ])
        ])
        let completed = WorkoutCardViewModel.buildCompletedWorkout(from: workout)
        XCTAssertEqual(completed.totalSets, 3)
        XCTAssertEqual(completed.totalReps, 13)
    }

    // MARK: - User Name

    func testUserNamePassthrough() {
        let workout = makeWorkout()
        let completed = WorkoutCardViewModel.buildCompletedWorkout(from: workout, userName: "domgiordano")
        XCTAssertEqual(completed.userName, "domgiordano")
    }
}
