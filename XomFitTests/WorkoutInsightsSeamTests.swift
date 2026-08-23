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

    // MARK: - Weekly streak

    private func workout(daysAgo: Int, hour: Int = 12, beatTheClockSets: Int = 0) -> Workout {
        let cal = Calendar.current
        let day = cal.date(byAdding: .day, value: -daysAgo, to: Date())!
        let start = cal.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
        let bench = ExerciseDatabase.byId["ex-bench-flat"]!
        let sets = (0..<3).map { i in
            WorkoutSet(
                id: "s-\(daysAgo)-\(i)", exerciseId: bench.id, weight: 100, reps: 8,
                rpe: nil, isPersonalRecord: false, completedAt: start,
                beatRestTimer: i < beatTheClockSets
            )
        }
        return Workout(
            id: "w-\(daysAgo)-\(hour)", userId: "u1", name: "W",
            exercises: [WorkoutExercise(id: "we-\(daysAgo)-\(hour)", exercise: bench, sets: sets, notes: nil)],
            startTime: start
        )
    }

    /// The reason this exists instead of reusing `longestStreak`: training six
    /// days a week and resting Sunday should read as consistent, not as a
    /// one-day streak.
    func testWeeklyStreakSurvivesRestDays() {
        // One workout a week for four weeks — no two are on consecutive days.
        let workouts = [0, 7, 14, 21].map { workout(daysAgo: $0) }

        XCTAssertEqual(WorkoutInsights.longestWeeklyStreak(workouts: workouts), 4)
        XCTAssertEqual(
            WorkoutInsights.longestStreak(workouts: workouts), 1,
            "Day streak sees these as unrelated, which is the whole point"
        )
    }

    func testWeeklyStreakBreaksOnAMissedWeek() {
        // Weeks 0, 1, then a gap, then two more.
        let workouts = [0, 7, 28, 35].map { workout(daysAgo: $0) }
        XCTAssertEqual(WorkoutInsights.longestWeeklyStreak(workouts: workouts), 2)
    }

    func testWeeklyStreakIsZeroWithNoWorkouts() {
        XCTAssertEqual(WorkoutInsights.longestWeeklyStreak(workouts: []), 0)
    }

    // MARK: - Badge criteria

    func testTierBadgesCountBetterTiersToo() {
        // Reaching Diamond must not un-earn the Gold badge on the way past it.
        let unlocked = BadgeEvaluator.unlocked(
            for: [workout(daysAgo: 0)],
            firstPRDate: nil,
            rankedTiers: [.diamond, .diamond, .diamond]
        ).map(\.id)

        XCTAssertTrue(unlocked.contains("tier-gold-1"))
        XCTAssertTrue(unlocked.contains("tier-diamond-3"))
    }

    /// Ranks are unavailable until bodyweight is known. That must leave the
    /// badges locked, never falsely unlocked.
    func testTierBadgesStayLockedWithoutRanks() {
        let unlocked = BadgeEvaluator.unlocked(
            for: [workout(daysAgo: 0)], firstPRDate: nil, rankedTiers: []
        ).map(\.id)

        XCTAssertFalse(unlocked.contains("tier-gold-1"))
    }

    func testEarlyBirdAndNightOwlAreCountedSeparately() {
        let early = (0..<10).map { workout(daysAgo: $0, hour: 5) }
        let unlocked = BadgeEvaluator.unlocked(for: early, firstPRDate: nil).map(\.id)

        XCTAssertTrue(unlocked.contains("early-bird-10"))
        XCTAssertFalse(unlocked.contains("night-owl-10"))
    }

    func testBeatTheClockCountsSetsAcrossWorkouts() {
        // 4 workouts x 3 qualifying sets = 12, over the 10 threshold.
        let workouts = (0..<4).map { workout(daysAgo: $0, beatTheClockSets: 3) }
        let unlocked = BadgeEvaluator.unlocked(for: workouts, firstPRDate: nil).map(\.id)

        XCTAssertTrue(unlocked.contains("beat-the-clock-10"))
        XCTAssertFalse(unlocked.contains("beat-the-clock-100"))
    }

    /// Sets logged before the column existed decode as false, so history must
    /// not retroactively unlock this.
    func testBeatTheClockIgnoresSetsThatDidNotBeatTheClock() {
        let workouts = (0..<20).map { workout(daysAgo: $0, beatTheClockSets: 0) }
        let unlocked = BadgeEvaluator.unlocked(for: workouts, firstPRDate: nil).map(\.id)

        XCTAssertFalse(unlocked.contains("beat-the-clock-10"))
    }

    func testEveryCatalogBadgeHasAUniqueId() {
        let ids = BadgeCatalog.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "Duplicate badge ids would collide in the unlocked set")
    }


    // MARK: - Stretch variety

    /// The tailored routine used to hardcode `st-worlds-greatest` as its opener,
    /// so every warmup a lifter ever did began with the same movement. That was
    /// the most visible reason the routine felt identical each time.
    func testOpenerIsDrawnFromTheFullBodyPoolNotOneHardcodedId() {
        let openers = StretchDatabase.all.filter { $0.category == .fullBody }
        XCTAssertGreaterThan(openers.count, 1, "Rotation needs something to rotate through")

        let opener = StretchDatabase.rotatingOpener()
        XCTAssertNotNil(opener)
        XCTAssertEqual(opener?.category, .fullBody)
    }

    /// Stable within a day, on purpose. A warmup that reshuffled on every redraw
    /// would be worse than one that repeats — a lifter halfway through a routine
    /// should not have it change under them.
    func testVariationIsStableWithinARun() {
        let first = StretchDatabase.rotatingOpener()?.id
        let second = StretchDatabase.rotatingOpener()?.id
        XCTAssertEqual(first, second)
    }

    func testVariationIndexStaysInBounds() {
        for count in 1...12 {
            let index = StretchDatabase.variationIndex(count: count)
            XCTAssertTrue((0..<count).contains(index), "index \(index) out of bounds for \(count)")
        }
        XCTAssertEqual(StretchDatabase.variationIndex(count: 0), 0, "Empty pool must not divide by zero")
    }

    // MARK: - Warmup relevance

    private func stretchTestExercise(
        _ id: String,
        groups: [MuscleGroup],
        recommended: [String]? = nil
    ) -> Exercise {
        Exercise(
            id: id,
            name: id,
            muscleGroups: groups,
            equipment: .barbell,
            category: .compound,
            description: "",
            tips: [],
            recommendedStretchIds: recommended
        )
    }

    /// The bug this pins, in the shape it actually took: a template with several
    /// exercises, each carrying curated stretch ids.
    ///
    /// Step 1 walked exercises in order collecting recommendations until it hit
    /// the six-stretch cap, then two hardcoded openers were pushed in at the
    /// front and the whole thing was truncated back to six. The result was two
    /// fixed openers plus the *first* exercise's stretches — every later
    /// exercise contributed nothing, and the muscle-frequency pass was skipped
    /// entirely because `picked.count < 3` was already false.
    ///
    /// So a full-body template warmed up as if it were only its first lift, the
    /// same way every single time.
    func testRoutineCoversLaterExercisesNotJustTheFirst() {
        let bench = stretchTestExercise(
            "bench", groups: [.chest, .triceps, .shoulders],
            recommended: ["st-doorway-chest", "st-overhead-tricep", "st-shoulder-dislocates"]
        )
        let row = stretchTestExercise(
            "row", groups: [.back, .lats, .biceps],
            recommended: ["st-lat-overhead", "st-bicep-wall"]
        )
        let squat = stretchTestExercise(
            "squat", groups: [.quads, .glutes, .hamstrings],
            recommended: ["st-hamstring-stretch"]
        )

        let routine = StretchDatabase.suggestedStretches(
            forExercises: [bench, row, squat],
            target: 600
        )

        let legGroups: Set<MuscleGroup> = [.quads, .glutes, .hamstrings, .calves]
        let coversLegs = routine.contains { !legGroups.isDisjoint(with: Set($0.targetMuscleGroups)) }
        XCTAssertTrue(
            coversLegs,
            "Squats are in this session but nothing warms the legs: \(routine.map(\.name))"
        )
    }

    /// Two different sessions on the same day must not produce the same routine.
    /// Rotation used to be keyed on the day alone, so push in the morning and
    /// legs at night opened identically.
    func testDifferentSessionsOnTheSameDayDiffer() {
        let push = stretchTestExercise("bench", groups: [.chest, .triceps, .shoulders])
        let legs = stretchTestExercise("squat", groups: [.quads, .glutes, .hamstrings])

        let pushRoutine = StretchDatabase.suggestedStretches(forExercises: [push], target: 600).map(\.id)
        let legRoutine = StretchDatabase.suggestedStretches(forExercises: [legs], target: 600).map(\.id)

        XCTAssertNotEqual(pushRoutine, legRoutine)
    }

    /// Stable within a session, for the same reason the opener is: a routine
    /// that reshuffles mid-warmup is worse than one that repeats.
    func testSameSessionIsStableAcrossCalls() {
        let push = stretchTestExercise("bench", groups: [.chest, .triceps])
        let first = StretchDatabase.suggestedStretches(forExercises: [push], target: 600).map(\.id)
        let second = StretchDatabase.suggestedStretches(forExercises: [push], target: 600).map(\.id)
        XCTAssertEqual(first, second)
    }

    /// Order must not matter — `[chest, triceps]` and `[triceps, chest]` are the
    /// same session and should seed the same rotation.
    func testVariationSeedIgnoresMuscleOrder() {
        XCTAssertEqual(
            StretchDatabase.variationSeed(for: [.chest, .triceps]),
            StretchDatabase.variationSeed(for: [.triceps, .chest])
        )
    }

    /// The time budget still binds. A lifter who asks for a three-minute warmup
    /// should not be handed six minutes of stretches.
    func testSuggestedRoutineRespectsTheBudget() {
        let squat = stretchTestExercise("squat", groups: [.quads, .glutes])
        let routine = StretchDatabase.suggestedStretches(forExercises: [squat], target: 180)
        let total = routine.reduce(0) { $0 + $1.durationSeconds }
        XCTAssertLessThanOrEqual(TimeInterval(total), 180)
    }

    /// The fallback routine is what a lifter gets when they warm up before
    /// picking exercises — the most common way to see the same list repeatedly.
    func testDefaultRoutineIsNotEmptyAndRespectsTheBudget() {
        let routine = StretchDatabase.defaultRoutine(target: 360)
        XCTAssertFalse(routine.isEmpty)
        let total = routine.reduce(0) { $0 + $1.durationSeconds }
        XCTAssertLessThanOrEqual(TimeInterval(total), 360)
    }

}
