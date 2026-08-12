import XCTest
@testable import Xomfit

/// Covers the two defects behind "my weights and PRs aren't saving right":
/// variant identity (so different attachments don't share a record) and the
/// model fields that the Supabase payloads used to silently drop.
final class ExerciseVariantTests: XCTestCase {

    // MARK: - Variant identity

    func testDefaultConfigurationProducesStableKey() {
        let key = ExerciseVariant.key(exerciseId: "ex-1")
        XCTAssertEqual(key, "ex-1|-|-|-|bilateral")
    }

    func testDifferentAttachmentsAreDifferentVariants() {
        let rope = ExerciseVariant.key(exerciseId: "ex-99", attachment: .rope)
        let straight = ExerciseVariant.key(exerciseId: "ex-99", attachment: .straightBar)
        XCTAssertNotEqual(rope, straight, "A rope pushdown and a straight-bar pushdown must not share a PR")
    }

    func testDifferentGripsAreDifferentVariants() {
        XCTAssertNotEqual(
            ExerciseVariant.key(exerciseId: "ex-5", grip: .overhand),
            ExerciseVariant.key(exerciseId: "ex-5", grip: .underhand)
        )
    }

    func testLateralityIsPartOfIdentity() {
        XCTAssertNotEqual(
            ExerciseVariant.key(exerciseId: "ex-7", laterality: .bilateral),
            ExerciseVariant.key(exerciseId: "ex-7", laterality: .unilateral)
        )
    }

    func testKeyIsFixedAritySoItStaysParseable() {
        let sparse = ExerciseVariant.key(exerciseId: "ex-1")
        let full = ExerciseVariant.key(
            exerciseId: "ex-1", grip: .neutral, attachment: .vBar,
            position: .seated, laterality: .alternating
        )
        XCTAssertEqual(sparse.split(separator: "|").count, 5)
        XCTAssertEqual(full.split(separator: "|").count, 5)
    }

    func testKeyForWorkoutExerciseMatchesExplicitKey() {
        let logged = WorkoutExercise(
            id: "we-1",
            exercise: Exercise.benchPress,
            sets: [],
            selectedGrip: .close,
            selectedAttachment: nil,
            selectedPosition: .incline,
            selectedLaterality: .bilateral
        )
        XCTAssertEqual(
            ExerciseVariant.key(for: logged),
            ExerciseVariant.key(
                exerciseId: Exercise.benchPress.id,
                grip: .close,
                position: .incline
            )
        )
    }

    func testDisplaySuffixIsNilForDefaultConfiguration() {
        XCTAssertNil(ExerciseVariant.displaySuffix())
    }

    func testDisplaySuffixDescribesVariant() {
        let suffix = ExerciseVariant.displaySuffix(attachment: .rope, laterality: .unilateral)
        XCTAssertEqual(suffix, "Rope · Single")
    }

    // MARK: - Fields the payloads used to drop

    /// `weightMode` was never persisted, so a set logged as 25 lb per side came
    /// back as 25 lb total and its recorded volume halved. This pins the volume
    /// difference the dropped field was destroying.
    func testPerSideSetCountsDoubleVolume() {
        let perSide = WorkoutSet(
            id: "s1", exerciseId: "ex-1", weight: 25, reps: 10,
            rpe: nil, isPersonalRecord: false, completedAt: Date(),
            weightMode: .perSide
        )
        let total = WorkoutSet(
            id: "s2", exerciseId: "ex-1", weight: 25, reps: 10,
            rpe: nil, isPersonalRecord: false, completedAt: Date(),
            weightMode: .total
        )
        XCTAssertEqual(perSide.volume, 500)
        XCTAssertEqual(total.volume, 250)
    }

    func testWorkoutSetSurvivesJSONRoundTrip() throws {
        let original = WorkoutSet(
            id: "s1", exerciseId: "ex-1", weight: 135, reps: 8,
            rpe: 8.5, isPersonalRecord: true, completedAt: Date(),
            weightMode: .perSide, isDropSet: true
        )
        let decoded = try JSONDecoder().decode(
            WorkoutSet.self, from: JSONEncoder().encode(original)
        )
        XCTAssertEqual(decoded.weightMode, .perSide)
        XCTAssertTrue(decoded.isDropSet)
        XCTAssertEqual(decoded.weight, 135)
        XCTAssertEqual(decoded.reps, 8)
    }

    func testWorkoutExerciseSurvivesJSONRoundTrip() throws {
        let groupId = UUID()
        let original = WorkoutExercise(
            id: "we-1",
            exercise: Exercise.squat,
            sets: [],
            notes: "felt heavy",
            selectedGrip: .wide,
            selectedAttachment: .dHandle,
            selectedPosition: .seated,
            selectedLaterality: .unilateral,
            supersetGroupId: groupId,
            restSeconds: 150
        )
        let decoded = try JSONDecoder().decode(
            WorkoutExercise.self, from: JSONEncoder().encode(original)
        )
        XCTAssertEqual(decoded.selectedGrip, .wide)
        XCTAssertEqual(decoded.selectedAttachment, .dHandle)
        XCTAssertEqual(decoded.selectedPosition, .seated)
        XCTAssertEqual(decoded.selectedLaterality, .unilateral)
        XCTAssertEqual(decoded.supersetGroupId, groupId)
        XCTAssertEqual(decoded.restSeconds, 150)
        XCTAssertEqual(decoded.notes, "felt heavy")
    }

    // MARK: - e1RM ranking

    /// The old PR check matched on an exact rep count, so a strictly worse set
    /// could register as a record. Ranking on estimated 1RM is what makes sets
    /// at different rep counts comparable at all.
    func testHeavierSetAtFewerRepsCanRankBelowLighterSetAtMoreReps() {
        let heavyFewReps = Exercise.estimateMax(weight: 225, reps: 5)
        let lightMoreReps = Exercise.estimateMax(weight: 225, reps: 6)
        XCTAssertLessThan(
            heavyFewReps, lightMoreReps,
            "225x5 must not outrank 225x6 — that was the original PR bug"
        )
    }

    func testSingleRepEstimateIsTheWeightItself() {
        XCTAssertEqual(Exercise.estimateMax(weight: 315, reps: 1), 315)
    }

    // MARK: - Legacy record compatibility

    func testLegacyRecordFallsBackToBareExerciseId() {
        let legacy = PersonalRecord(
            id: "pr-1", userId: "u1", exerciseId: "ex-1", exerciseName: "Bench Press",
            weight: 225, reps: 5, date: Date(), previousBest: nil
        )
        XCTAssertEqual(legacy.effectiveVariantKey, "ex-1")
        XCTAssertEqual(legacy.kind, .repRange, "Records predating e1RM ranking keep their original meaning")
    }

    func testDisplayNameIncludesVariantWhenPresent() {
        var record = PersonalRecord(
            id: "pr-2", userId: "u1", exerciseId: "ex-9", exerciseName: "Pushdown",
            weight: 70, reps: 12, date: Date(), previousBest: nil
        )
        XCTAssertEqual(record.displayName, "Pushdown")
        record.selectedAttachment = .rope
        XCTAssertEqual(record.displayName, "Pushdown · Rope")
    }
}
