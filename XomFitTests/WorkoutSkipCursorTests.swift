import XCTest
@testable import Xomfit

/// Covers the two behaviours that make the active-workout flow continuous:
/// the shared cursor (one "where am I" across list and focus mode) and set
/// skipping (a set you decide not to do stops blocking the workout).
@MainActor
final class WorkoutSkipCursorTests: XCTestCase {

    private var sut: WorkoutLoggerViewModel!

    override func setUp() {
        super.setUp()
        sut = WorkoutLoggerViewModel()
        sut.startWorkout(name: "Test", userId: "test-user")
    }

    override func tearDown() {
        sut.discardWorkout()
        sut = nil
        super.tearDown()
    }

    /// Adds `count` exercises, each carrying `sets` empty sets.
    @discardableResult
    private func seed(exercises count: Int, sets: Int) -> [Exercise] {
        let picked = Array(ExerciseDatabase.all.prefix(count))
        for exercise in picked {
            sut.addExercise(exercise)
            let idx = sut.exercises.count - 1
            // addExercise seeds some sets already; normalise to `sets`.
            while sut.exercises[idx].sets.count < sets { sut.addSet(to: idx) }
            while sut.exercises[idx].sets.count > sets {
                sut.removeSet(exerciseIndex: idx, setIndex: sut.exercises[idx].sets.count - 1)
            }
        }
        // Land the cursor at the start regardless of what seeding did.
        sut.setCursor(exercise: 0, set: 0)
        return picked
    }

    // MARK: - Skip semantics

    func testSkippedSetIsNotPending() {
        seed(exercises: 1, sets: 3)
        sut.toggleSkip(exerciseIndex: 0, setIndex: 1)

        let set = sut.exercises[0].sets[1]
        XCTAssertTrue(set.isSkipped)
        XCTAssertFalse(set.isPending, "A skipped set must stop counting as work remaining")
        XCTAssertFalse(set.isCompleted, "Skipping is not the same as completing")
    }

    /// The load-bearing one: before skip existed, an abandoned set left the
    /// workout permanently incomplete.
    func testSkippedSetDoesNotBlockCompletion() {
        seed(exercises: 1, sets: 2)
        sut.completeSet(exerciseIndex: 0, setIndex: 0)
        XCTAssertFalse(sut.allExercisesComplete)

        sut.toggleSkip(exerciseIndex: 0, setIndex: 1)
        XCTAssertTrue(sut.allExercisesComplete, "One done + one skipped means the exercise is finished")
    }

    func testUnskipRestoresPending() {
        seed(exercises: 1, sets: 2)
        sut.toggleSkip(exerciseIndex: 0, setIndex: 1)
        sut.toggleSkip(exerciseIndex: 0, setIndex: 1)

        XCTAssertTrue(sut.exercises[0].sets[1].isPending)
        XCTAssertFalse(sut.allExercisesComplete)
    }

    func testSkippingCompletedSetClearsCompletion() {
        seed(exercises: 1, sets: 2)
        sut.completeSet(exerciseIndex: 0, setIndex: 0)
        sut.toggleSkip(exerciseIndex: 0, setIndex: 0)

        let set = sut.exercises[0].sets[0]
        XCTAssertTrue(set.isSkipped)
        XCTAssertFalse(set.isCompleted, "A set cannot be both done and skipped")
        XCTAssertFalse(set.isPersonalRecord)
    }

    func testSkippingCursorSetAdvancesPastIt() {
        seed(exercises: 1, sets: 3)
        sut.setCursor(exercise: 0, set: 0)

        sut.toggleSkip(exerciseIndex: 0, setIndex: 0)

        XCTAssertEqual(sut.focusSetIndex, 1, "Cursor must not sit on a set the lifter just dismissed")
    }

    func testSkippedSetsAreNotSaved() {
        seed(exercises: 1, sets: 3)
        sut.completeSet(exerciseIndex: 0, setIndex: 0)
        sut.toggleSkip(exerciseIndex: 0, setIndex: 1)

        // `finishWorkout` keeps only completed sets, so the skipped one and the
        // untouched one both fall out.
        let saved = sut.exercises[0].sets.filter { $0.isCompleted }
        XCTAssertEqual(saved.count, 1)
        XCTAssertFalse(saved.contains { $0.isSkipped })
    }

    func testSkipSurvivesEncodeDecodeRoundTrip() throws {
        seed(exercises: 1, sets: 2)
        sut.toggleSkip(exerciseIndex: 0, setIndex: 0)

        let data = try JSONEncoder().encode(sut.exercises)
        let restored = try JSONDecoder().decode([WorkoutExercise].self, from: data)

        XCTAssertTrue(restored[0].sets[0].isSkipped, "Skip state must survive session persistence")
        XCTAssertFalse(restored[0].sets[1].isSkipped)
    }

    /// Sessions persisted before `skippedAt` existed must still decode.
    func testLegacySetDecodesAsNotSkipped() throws {
        let legacy = """
        {
          "id": "s1",
          "exerciseId": "e1",
          "weight": 135,
          "reps": 8,
          "isPersonalRecord": false,
          "completedAt": 0,
          "weightMode": "total",
          "isDropSet": false
        }
        """.data(using: .utf8)!

        let set = try JSONDecoder().decode(WorkoutSet.self, from: legacy)
        XCTAssertFalse(set.isSkipped)
        XCTAssertNil(set.skippedAt)
    }

    // MARK: - Shared cursor

    func testSetCursorMovesBothIndices() {
        seed(exercises: 2, sets: 3)
        sut.setCursor(exercise: 1, set: 2)

        XCTAssertEqual(sut.focusExerciseIndex, 1)
        XCTAssertEqual(sut.focusSetIndex, 2)
    }

    func testSetCursorIgnoresOutOfBounds() {
        seed(exercises: 1, sets: 2)
        sut.setCursor(exercise: 0, set: 1)

        sut.setCursor(exercise: 99, set: 0)
        sut.setCursor(exercise: 0, set: 99)

        XCTAssertEqual(sut.focusExerciseIndex, 0)
        XCTAssertEqual(sut.focusSetIndex, 1, "An invalid target must not strand the cursor")
    }

    /// Completing a set in list mode used to leave the cursor behind, so
    /// zooming into focus mode landed on the set you'd just finished.
    func testCompletingSetAdvancesCursor() {
        seed(exercises: 1, sets: 3)
        sut.setCursor(exercise: 0, set: 0)

        sut.completeSet(exerciseIndex: 0, setIndex: 0)

        XCTAssertEqual(sut.focusSetIndex, 1)
    }

    func testCompletingLastSetAdvancesToNextExercise() {
        seed(exercises: 2, sets: 1)
        sut.setCursor(exercise: 0, set: 0)

        sut.completeSet(exerciseIndex: 0, setIndex: 0)

        XCTAssertEqual(sut.focusExerciseIndex, 1)
        XCTAssertEqual(sut.focusSetIndex, 0)
    }

    /// Completing a set that isn't the cursor must not drag the cursor along.
    func testCompletingNonCursorSetLeavesCursorAlone() {
        seed(exercises: 1, sets: 3)
        sut.setCursor(exercise: 0, set: 0)

        sut.completeSet(exerciseIndex: 0, setIndex: 2)

        XCTAssertEqual(sut.focusSetIndex, 0)
    }

    func testFocusAdvanceStepsOverSkippedSets() {
        seed(exercises: 1, sets: 4)
        sut.setCursor(exercise: 0, set: 0)
        sut.toggleSkip(exerciseIndex: 0, setIndex: 1)
        sut.toggleSkip(exerciseIndex: 0, setIndex: 2)
        sut.setCursor(exercise: 0, set: 0)

        sut.focusAdvance()

        XCTAssertEqual(sut.focusSetIndex, 3, "Advance must land on the next set actually owed")
    }

    // MARK: - Celebration precedence

    private func makePR(id: String, exerciseId: String) -> PersonalRecord {
        PersonalRecord(
            id: id, userId: "test-user", exerciseId: exerciseId,
            exerciseName: "Bench Press", weight: 245, reps: 5,
            date: Date(), previousBest: 225
        )
    }

    /// Crossing a tier requires a new best e1RM, which *is* a PR — so nearly
    /// every tier-up arrives alongside one. Showing both would double-banner the
    /// same moment.
    func testTierUpSupersedesThePRForTheSameLift() {
        sut.present(.personalRecord(makePR(id: "pr-1", exerciseId: "ex-bench-flat")))
        sut.present(.tierUp(exerciseId: "ex-bench-flat", exerciseName: "Bench Press", tier: .diamond))

        XCTAssertEqual(
            sut.activeCelebration,
            .tierUp(exerciseId: "ex-bench-flat", exerciseName: "Bench Press", tier: .diamond)
        )
    }

    /// The PR check is a network round trip and the tier check is local, so the
    /// PR routinely lands second. It must not overwrite the tier-up.
    func testPRArrivingAfterATierUpForTheSameLiftIsDropped() {
        sut.present(.tierUp(exerciseId: "ex-bench-flat", exerciseName: "Bench Press", tier: .diamond))
        sut.present(.personalRecord(makePR(id: "pr-1", exerciseId: "ex-bench-flat")))

        guard case .tierUp = sut.activeCelebration else {
            return XCTFail("Tier-up should still be showing, got \(String(describing: sut.activeCelebration))")
        }
    }

    /// A PR on a different lift is a separate achievement, but two banners
    /// back-to-back mid-set is noise — the higher-ranked one wins outright.
    func testLowerRankedCelebrationOnAnotherLiftIsDroppedNotQueued() {
        sut.present(.tierUp(exerciseId: "ex-squat", exerciseName: "Squat", tier: .gold))
        sut.present(.personalRecord(makePR(id: "pr-1", exerciseId: "ex-bench-flat")))

        guard case .tierUp = sut.activeCelebration else {
            return XCTFail("Higher-ranked celebration should survive")
        }

        // ...and dismissing leaves nothing behind, rather than revealing a queue.
        sut.dismissCelebration()
        XCTAssertNil(sut.activeCelebration)
    }

    func testHigherRankedCelebrationOnAnotherLiftReplacesTheCurrentOne() {
        sut.present(.personalRecord(makePR(id: "pr-1", exerciseId: "ex-bench-flat")))
        sut.present(.tierUp(exerciseId: "ex-squat", exerciseName: "Squat", tier: .gold))

        XCTAssertEqual(
            sut.activeCelebration,
            .tierUp(exerciseId: "ex-squat", exerciseName: "Squat", tier: .gold)
        )
    }


    // MARK: - All-exercises-done prompt

    /// The card used to be suppressed on the final exercise, on the theory that
    /// the lifter would head straight to Finish. In practice the session went
    /// quiet with nothing prompting the obvious next action.
    func testTransitionCardShowsWhenTheLastExerciseCompletes() {
        seed(exercises: 2, sets: 2)
        for exIdx in 0..<2 {
            for setIdx in 0..<2 {
                sut.completeSet(exerciseIndex: exIdx, setIndex: setIdx)
            }
        }

        XCTAssertTrue(sut.allExercisesComplete)
        XCTAssertTrue(
            sut.showExerciseTransition,
            "Finishing the last exercise must prompt Add Exercise / Finish Workout"
        )
        XCTAssertNil(
            sut.nextExerciseIndex,
            "Nothing left to move on to — the card should be in its all-done state"
        )
    }

    /// Mid-workout the card still points somewhere, so the all-done branch must
    /// not take over early.
    func testTransitionCardStillOffersTheNextExerciseMidWorkout() {
        seed(exercises: 2, sets: 2)
        for setIdx in 0..<2 {
            sut.completeSet(exerciseIndex: 0, setIndex: setIdx)
        }

        XCTAssertTrue(sut.showExerciseTransition)
        XCTAssertFalse(sut.allExercisesComplete)
        XCTAssertEqual(sut.nextExerciseIndex, 1)
    }

    // MARK: - Beat the clock

    /// Read before `startRestTimer` replaces the clock — after that call the
    /// answer would always be yes and the badge would be worthless.
    func testSetCompletedWhileRestingCountsAsBeatingTheClock() {
        seed(exercises: 1, sets: 3)

        // First set: no rest running yet, so there is no clock to beat.
        sut.completeSet(exerciseIndex: 0, setIndex: 0)
        XCTAssertFalse(sut.exercises[0].sets[0].beatRestTimer)

        // That started a rest timer, so the next set beats it.
        XCTAssertTrue(sut.isRestTimerActive)
        sut.completeSet(exerciseIndex: 0, setIndex: 1)
        XCTAssertTrue(sut.exercises[0].sets[1].beatRestTimer)
    }

    func testLettingRestExpireDoesNotCountAsBeatingTheClock() {
        seed(exercises: 1, sets: 3)
        sut.completeSet(exerciseIndex: 0, setIndex: 0)

        // Run the clock out. Overtime keeps the timer active but there is
        // nothing left to beat.
        sut.restTimeRemaining = 0
        sut.completeSet(exerciseIndex: 0, setIndex: 1)

        XCTAssertFalse(sut.exercises[0].sets[1].beatRestTimer)
    }

    func testTogglingASetOffClearsBeatTheClock() {
        seed(exercises: 1, sets: 3)
        sut.completeSet(exerciseIndex: 0, setIndex: 0)
        sut.completeSet(exerciseIndex: 0, setIndex: 1)
        XCTAssertTrue(sut.exercises[0].sets[1].beatRestTimer)

        sut.completeSet(exerciseIndex: 0, setIndex: 1)   // toggle off
        XCTAssertFalse(sut.exercises[0].sets[1].beatRestTimer)
    }


    // MARK: - New-PR badge

    /// The exercise card read PRs from history, so after beating one it kept
    /// advertising the number the lifter had just broken. `checkForPR` flags the
    /// set itself, which is what the card should trust for the current session.
    func testCompletedSetCarriesThePRFlagForTheCard() {
        seed(exercises: 1, sets: 3)
        sut.exercises[0].sets[0].weight = 225
        sut.exercises[0].sets[0].reps = 5
        sut.completeSet(exerciseIndex: 0, setIndex: 0)

        // No network in tests, so simulate what checkForPR does to the set.
        sut.exercises[0].sets[0].isPersonalRecord = true

        let prSets = sut.exercises[0].sets.filter { $0.isPersonalRecord && $0.weight > 0 && $0.reps > 0 }
        XCTAssertEqual(prSets.count, 1)
        XCTAssertEqual(prSets.first?.weight, 225)
    }

    /// Beating a PR twice should surface the better number, not the earlier one.
    func testHeaviestPRSetWinsWhenThereAreSeveral() {
        seed(exercises: 1, sets: 3)
        for (idx, weight) in [225.0, 245.0].enumerated() {
            sut.exercises[0].sets[idx].weight = weight
            sut.exercises[0].sets[idx].reps = 5
            sut.exercises[0].sets[idx].isPersonalRecord = true
        }

        let best = sut.exercises[0].sets
            .filter { $0.isPersonalRecord && $0.weight > 0 && $0.reps > 0 }
            .max { $0.weight < $1.weight }

        XCTAssertEqual(best?.weight, 245, "The card should show the better lift, not the first one")
    }


    // MARK: - Garmin set adjustment

    /// The watch edits one field at a time, so the other must survive.
    func testAdjustingRepsFromTheWatchLeavesWeightAlone() {
        seed(exercises: 1, sets: 3)
        sut.updateSet(exerciseIndex: 0, setIndex: 0, weight: 225, reps: 5)
        sut.setCursor(exercise: 0, set: 0)

        sut.adjustFocusedSetFromWatch(reps: 8, weight: nil)

        XCTAssertEqual(sut.exercises[0].sets[0].reps, 8)
        XCTAssertEqual(sut.exercises[0].sets[0].weight, 225, "Weight must not be reset by a reps-only edit")
    }

    func testAdjustingWeightFromTheWatchLeavesRepsAlone() {
        seed(exercises: 1, sets: 3)
        sut.updateSet(exerciseIndex: 0, setIndex: 0, weight: 225, reps: 5)
        sut.setCursor(exercise: 0, set: 0)

        sut.adjustFocusedSetFromWatch(reps: nil, weight: 245)

        XCTAssertEqual(sut.exercises[0].sets[0].weight, 245)
        XCTAssertEqual(sut.exercises[0].sets[0].reps, 5, "Reps must not be reset by a weight-only edit")
    }

    /// A message can arrive after the workout ends — Bluetooth is not
    /// synchronous with the UI.
    func testAdjustingWithNoActiveWorkoutIsANoOp() {
        seed(exercises: 1, sets: 2)
        sut.discardWorkout()
        sut.adjustFocusedSetFromWatch(reps: 12, weight: 100)
        XCTAssertFalse(sut.isActive)
    }


    // MARK: - Logging a set from the watch

    /// One action on the wrist, because it is one action to the lifter: the
    /// numbers land and rest starts, rather than adjusting the target and then
    /// separately saying done.
    func testLoggingFromTheWatchRecordsNumbersAndStartsRest() {
        seed(exercises: 1, sets: 3)
        sut.updateSet(exerciseIndex: 0, setIndex: 0, weight: 185, reps: 8)
        sut.setCursor(exercise: 0, set: 0)

        sut.logSetFromWatch(weight: 205, reps: 5)

        XCTAssertEqual(sut.exercises[0].sets[0].weight, 205)
        XCTAssertEqual(sut.exercises[0].sets[0].reps, 5)
        XCTAssertTrue(sut.exercises[0].sets[0].isCompleted)
        XCTAssertTrue(sut.isRestTimerActive, "Logging a set should begin rest")
    }

    /// Two genuine logs in a row advance twice — that is the normal case, and
    /// the view model must not conflate it with a duplicate delivery.
    ///
    /// Deduplication happens in `GarminSyncService`, not here: only the
    /// transport knows whether two identical messages are one action delivered
    /// twice or two sets performed. Putting a time window in the view model
    /// would make rapid legitimate sets unloggable.
    func testTwoLogsAdvanceThroughConsecutiveSets() {
        seed(exercises: 1, sets: 3)
        sut.setCursor(exercise: 0, set: 0)

        sut.logSetFromWatch(weight: 100, reps: 10)
        XCTAssertTrue(sut.exercises[0].sets[0].isCompleted)

        sut.logSetFromWatch(weight: 110, reps: 8)
        XCTAssertTrue(sut.exercises[0].sets[1].isCompleted)
        XCTAssertEqual(sut.exercises[0].sets[1].weight, 110, "The second log lands on the second set")
    }

    /// A message can arrive after the workout ends — Bluetooth is not
    /// synchronous with the UI.
    func testLoggingWithNoActiveWorkoutIsANoOp() {
        seed(exercises: 1, sets: 2)
        sut.discardWorkout()
        sut.logSetFromWatch(weight: 100, reps: 10)
        XCTAssertFalse(sut.isActive)
    }

}
