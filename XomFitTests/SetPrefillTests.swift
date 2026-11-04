import XCTest
@testable import Xomfit

/// Prefill selection (#515): which past numbers a new set starts with.
final class ExerciseHistoryTests: XCTestCase {

    private let exercise = ExerciseDatabase.all[0]

    private func set(_ weight: Double, _ reps: Int, drop: Bool = false) -> WorkoutSet {
        WorkoutSet(
            id: UUID().uuidString, exerciseId: exercise.id, weight: weight, reps: reps,
            isPersonalRecord: false, completedAt: Date(), isDropSet: drop
        )
    }

    private func workout(
        daysAgo: Double,
        _ sets: [WorkoutSet],
        attachment: CableAttachment? = nil
    ) -> Workout {
        Workout(
            id: UUID().uuidString, userId: "u", name: "W",
            exercises: [WorkoutExercise(
                id: UUID().uuidString, exercise: exercise, sets: sets, notes: nil,
                selectedAttachment: attachment
            )],
            startTime: Date().addingTimeInterval(-daysAgo * 86_400),
            endTime: nil, notes: nil, location: nil, rating: nil
        )
    }

    private var key: String { ExerciseVariant.key(exerciseId: exercise.id) }

    func testPrefillIsPerSetNotTheHeaviestSet() {
        let history = ExerciseHistory(workouts: [workout(daysAgo: 1, [set(135, 10), set(155, 8), set(175, 5)])])
        let values = (0..<3).map { history.prefill(variantKey: key, ordinal: $0) }
        XCTAssertEqual(values.map(\.weight), [135, 155, 175])
        XCTAssertEqual(values.map(\.reps), [10, 8, 5])
    }

    func testUsesMostRecentSessionRegardlessOfInputOrder() {
        let history = ExerciseHistory(workouts: [
            workout(daysAgo: 7, [set(100, 5)]),
            workout(daysAgo: 1, [set(120, 5)]),
            workout(daysAgo: 3, [set(110, 5)]),
        ])
        XCTAssertEqual(history.prefill(variantKey: key, ordinal: 0).weight, 120)
    }

    func testExtraSetsRepeatLastSessionsFinalSet() {
        let history = ExerciseHistory(workouts: [workout(daysAgo: 1, [set(135, 10), set(145, 8)])])
        XCTAssertEqual(history.prefill(variantKey: key, ordinal: 4).weight, 145)
    }

    func testDropSetsDoNotShiftPositions() {
        let history = ExerciseHistory(workouts: [
            workout(daysAgo: 1, [set(135, 10), set(95, 12, drop: true), set(145, 8)])
        ])
        XCTAssertEqual(history.prefill(variantKey: key, ordinal: 1).weight, 145)
    }

    func testVariantsDoNotShareHistory() {
        let history = ExerciseHistory(workouts: [
            workout(daysAgo: 1, [set(50, 12)], attachment: .rope),
            workout(daysAgo: 2, [set(80, 10)]),
        ])
        let rope = ExerciseVariant.key(exerciseId: exercise.id, attachment: .rope)
        XCTAssertEqual(history.prefill(variantKey: rope, ordinal: 0).weight, 50)
        XCTAssertEqual(history.prefill(variantKey: key, ordinal: 0).weight, 80)
    }

    func testNeverLoggedPrefillsZero() {
        let history = ExerciseHistory(workouts: [])
        XCTAssertEqual(history.prefill(variantKey: key, ordinal: 0).weight, 0)
        XCTAssertEqual(history.prefill(variantKey: key, ordinal: 0).reps, 0)
    }

    func testPersonalRecordTieBreaksOnReps() {
        let history = ExerciseHistory(workouts: [
            workout(daysAgo: 1, [set(145, 5)]),
            workout(daysAgo: 2, [set(145, 6), set(135, 12)]),
        ])
        XCTAssertEqual(history.personalRecords[exercise.id]?.reps, 6)
    }
}

final class WeightInputParsingTests: XCTestCase {

    func testClearedFieldParsesToZero() {
        XCTAssertEqual(parseWeightInput("", unit: .lbs), 0)
        XCTAssertEqual(parseRepsInput(""), 0)
    }

    func testCommaDecimalSeparator() {
        XCTAssertEqual(parseWeightInput("62,5", unit: .lbs), 62.5)
    }

    func testTrailingDecimalPointKeepsValue() {
        XCTAssertEqual(parseWeightInput("135.", unit: .lbs), 135)
    }

    func testRejectsGarbage() {
        XCTAssertNil(parseWeightInput("abc", unit: .lbs))
        XCTAssertNil(parseWeightInput("-5", unit: .lbs))
        XCTAssertNil(parseRepsInput("8.5"))
    }

    /// The set row compares the typed text's parsed value with the stored
    /// value rather than the formatted string. In kg the string round trip is
    /// lossy ("1" displays as "1.0"), which is what rewrote the field mid-entry.
    func testKgEntryRoundTripsByValueNotByString() throws {
        let stored = try XCTUnwrap(parseWeightInput("1", unit: .kg))
        XCTAssertEqual(parseWeightInput("1", unit: .kg), stored)
        XCTAssertNotEqual(stored.formattedWeight(unit: .kg), "1")
    }
}

@MainActor
final class ProgressionPrefillTests: XCTestCase {

    private var sut: WorkoutLoggerViewModel!

    override func setUp() {
        super.setUp()
        sut = WorkoutLoggerViewModel()
        sut.startWorkout(name: "Test", userId: "prefill-test-\(UUID().uuidString)")
        sut.addExercise(ExerciseDatabase.all[0])
    }

    override func tearDown() {
        sut.discardWorkout()
        sut = nil
        super.tearDown()
    }

    func testCompletingASetKeepsTheNextSetsRememberedNumbers() {
        for idx in 0..<3 { sut.updateSet(exerciseIndex: 0, setIndex: idx, weight: 135, reps: 12) }
        sut.completeSet(exerciseIndex: 0, setIndex: 0)
        XCTAssertEqual(sut.exercises[0].sets[1].weight, 135)
        XCTAssertEqual(sut.exercises[0].sets[1].reps, 12)
    }

    func testEmptyNextSetStillGetsProgression() {
        sut.updateSet(exerciseIndex: 0, setIndex: 0, weight: 100, reps: 10)
        sut.completeSet(exerciseIndex: 0, setIndex: 0)
        XCTAssertEqual(sut.exercises[0].sets[1].weight, 100)
        XCTAssertEqual(sut.exercises[0].sets[1].reps, 11)
    }

    func testPreviousSetIsNilForDropSetRows() {
        sut.updateSet(exerciseIndex: 0, setIndex: 0, weight: 100, reps: 10)
        sut.completeSet(exerciseIndex: 0, setIndex: 0)
        sut.addDropSet(exerciseIndex: 0, parentSetIndex: 0)
        XCTAssertTrue(sut.exercises[0].sets[1].isDropSet)
        XCTAssertNil(sut.previousSet(exerciseIndex: 0, setIndex: 1))
    }
}
