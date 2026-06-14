import XCTest
@testable import Xomfit

/// Deterministic unit tests for the Phase-3 `GoalBaseline` plan-driven nudge:
/// plan-pace firing, most-behind selection among focus muscles, and the
/// self-falling-back behavior (no plan / empty focus / no focus deficit all
/// delegate verbatim to `AdaptiveBaseline`).
///
/// Every test injects an explicit `GoalBaseline(plan:)` + synthetic `[Workout]`
/// + a fixed `now`, and pins `weekStartDay` so `WorkoutInsights.userCalendar()`
/// is deterministic. No real clock, no shared persistence dependence.
@MainActor
final class GoalBaselineTests: XCTestCase {

    // MARK: - Setup

    private var calendar: Calendar = .current

    override func setUp() {
        super.setUp()
        WeeklyPlanService.resetForTesting()
        TrainingNudgeService.resetForTesting()
        // Sunday-start week so weekStart math is deterministic (firstWeekday = 1).
        UserDefaults.standard.set(0, forKey: "weekStartDay")
        calendar = WorkoutInsights.userCalendar()
    }

    override func tearDown() {
        WeeklyPlanService.resetForTesting()
        TrainingNudgeService.resetForTesting()
        UserDefaults.standard.removeObject(forKey: "weekStartDay")
        super.tearDown()
    }

    // MARK: - Fixtures

    private func exercise(for muscle: MuscleGroup) -> Exercise {
        Exercise(
            id: "ex-test-\(muscle.rawValue)",
            name: "Test \(muscle.displayName)",
            muscleGroups: [muscle],
            equipment: .barbell,
            category: .compound,
            description: "",
            tips: []
        )
    }

    private func workout(id: String, muscle: MuscleGroup, sets: Int, date: Date) -> Workout {
        let ex = exercise(for: muscle)
        let workoutSets = (0..<sets).map { i in
            WorkoutSet(
                id: "\(id)-s\(i)",
                exerciseId: ex.id,
                weight: 100,
                reps: 8,
                rpe: nil,
                isPersonalRecord: false,
                completedAt: date
            )
        }
        return Workout(
            id: id,
            userId: "u1",
            name: "W",
            exercises: [WorkoutExercise(id: "\(id)-we", exercise: ex, sets: workoutSets, notes: nil)],
            startTime: date
        )
    }

    /// Wednesday mid-week (Sunday-start week → day 4 of 7, weekFraction ≈ 0.57).
    private func midWeekNow() -> Date {
        var comps = DateComponents()
        comps.year = 2025
        comps.month = 6
        comps.day = 11
        comps.hour = 12
        return calendar.date(from: comps)!
    }

    private func weekStart(for now: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: now)!.start
    }

    /// Trailing-4-week baseline of `setsPerWeek` for `muscle` (for adaptive-fallback
    /// fixtures), placed in the four full weeks before the current week.
    private func baselineWorkouts(
        muscle: MuscleGroup,
        setsPerWeek: Int,
        now: Date,
        idPrefix: String
    ) -> [Workout] {
        let ws = weekStart(for: now)
        var result: [Workout] = []
        for week in 1...AdaptiveBaseline.trailingWeeks {
            let date = calendar.date(byAdding: .day, value: -7 * week + 3, to: ws)!
            result.append(workout(id: "\(idPrefix)-w\(week)", muscle: muscle, sets: setsPerWeek, date: date))
        }
        return result
    }

    // MARK: - Plan-driven firing

    func testFiresWhenFocusMuscleBehindPlan() {
        let now = midWeekNow()
        // Plan: 4 sessions/week, focus Legs; zero leg sets this week.
        let plan = WeeklyPlan(targetSessions: 4, focusRegions: [.legs])
        // expectedByNow = 4.0 * 4 * 0.571 ≈ 9.14; actual 0 < 0.5 * expected → fires.
        let result = GoalBaseline(plan: plan).underTrainedMuscle(workouts: [], now: now)

        XCTAssertNotNil(result)
        XCTAssertTrue(
            TrainingRegion.legs.muscles.contains(result!.muscle),
            "Should surface a leg muscle (focus deficit)"
        )
        XCTAssertTrue(result!.reason.contains("weekly plan"), "Goal-directive copy expected")
    }

    func testDoesNotFireWhenFocusMuscleOnPace() {
        let now = midWeekNow()
        let plan = WeeklyPlan(targetSessions: 4, focusRegions: [.legs])
        let ws = weekStart(for: now)
        let thisWeek = calendar.date(byAdding: .day, value: 1, to: ws)!
        // Log plenty of sets for EVERY leg muscle so none is behind pace; no other
        // signal → result must not surface a leg deficit.
        var workouts: [Workout] = []
        for (i, muscle) in TrainingRegion.legs.muscles.enumerated() {
            workouts.append(workout(id: "leg\(i)", muscle: muscle, sets: 10, date: thisWeek))
        }

        let result = GoalBaseline(plan: plan).underTrainedMuscle(workouts: workouts, now: now)

        if let result {
            XCTAssertFalse(
                TrainingRegion.legs.muscles.contains(result.muscle),
                "On-pace focus muscles must not be surfaced as a plan deficit"
            )
        }
    }

    func testEarlyWeekSuppressed() {
        // Sunday (day 1 of 7) → weekFraction ≈ 0.14 < minWeekFraction (0.4).
        var comps = DateComponents()
        comps.year = 2025
        comps.month = 6
        comps.day = 8 // 2025-06-08 is a Sunday
        comps.hour = 9
        let now = calendar.date(from: comps)!

        let plan = WeeklyPlan(targetSessions: 4, focusRegions: [.legs])
        let result = GoalBaseline(plan: plan).underTrainedMuscle(workouts: [], now: now)

        XCTAssertNil(result, "No early-week firing for plan-driven nudges")
    }

    func testPicksMostBehindFocusMuscle() {
        let now = midWeekNow()
        let ws = weekStart(for: now)
        let thisWeek = calendar.date(byAdding: .day, value: 1, to: ws)!
        // Focus Legs + Pull. Give every pull muscle partial sets; leave legs at 0.
        // Legs ratio 0 (most behind) should win over any partially-trained pull muscle.
        let plan = WeeklyPlan(targetSessions: 4, focusRegions: [.legs, .pull])
        var workouts: [Workout] = []
        for (i, muscle) in TrainingRegion.pull.muscles.enumerated() {
            // 5 sets each: expectedByNow ≈ 9.14, 0.5*expected ≈ 4.57; 5 >= 4.57 → not a candidate.
            workouts.append(workout(id: "pull\(i)", muscle: muscle, sets: 5, date: thisWeek))
        }

        let result = GoalBaseline(plan: plan).underTrainedMuscle(workouts: workouts, now: now)

        XCTAssertNotNil(result)
        XCTAssertTrue(
            TrainingRegion.legs.muscles.contains(result!.muscle),
            "A zero-set leg muscle (smaller ratio) should win over partially-trained pull muscles"
        )
    }

    // MARK: - Self-falling-back equivalence

    func testNoPlanFallsBackToAdaptive() {
        let now = midWeekNow()
        // Adaptive "genuine deficit" fixture: chest baseline + zero chest this week.
        let workouts = baselineWorkouts(muscle: .chest, setsPerWeek: 3, now: now, idPrefix: "chest")

        let goalResult = GoalBaseline(plan: nil).underTrainedMuscle(workouts: workouts, now: now)
        let adaptiveResult = AdaptiveBaseline().underTrainedMuscle(workouts: workouts, now: now)

        XCTAssertEqual(goalResult, adaptiveResult, "No plan must equal adaptive byte-for-byte")
        XCTAssertEqual(goalResult?.muscle, .chest)
    }

    func testEmptyFocusFallsBackToAdaptive() {
        let now = midWeekNow()
        let workouts = baselineWorkouts(muscle: .chest, setsPerWeek: 3, now: now, idPrefix: "chest")
        let plan = WeeklyPlan(targetSessions: 4, focusRegions: [])

        let goalResult = GoalBaseline(plan: plan).underTrainedMuscle(workouts: workouts, now: now)
        let adaptiveResult = AdaptiveBaseline().underTrainedMuscle(workouts: workouts, now: now)

        XCTAssertEqual(goalResult, adaptiveResult, "Session-count-only plan = adaptive behavior")
        XCTAssertEqual(goalResult?.muscle, .chest)
    }

    func testNoFocusDeficitFallsBackToAdaptive() {
        let now = midWeekNow()
        let ws = weekStart(for: now)
        let thisWeek = calendar.date(byAdding: .day, value: 1, to: ws)!
        // Focus Legs, all leg muscles on-pace this week (no focus deficit), BUT a
        // different muscle (chest) is in genuine adaptive deficit. Step 6 should
        // surface the adaptive chest muscle.
        let plan = WeeklyPlan(targetSessions: 4, focusRegions: [.legs])
        var workouts = baselineWorkouts(muscle: .chest, setsPerWeek: 3, now: now, idPrefix: "chest")
        for (i, muscle) in TrainingRegion.legs.muscles.enumerated() {
            workouts.append(workout(id: "leg\(i)", muscle: muscle, sets: 12, date: thisWeek))
        }

        let goalResult = GoalBaseline(plan: plan).underTrainedMuscle(workouts: workouts, now: now)

        XCTAssertEqual(goalResult?.muscle, .chest, "Falls back to the adaptive deficit muscle")
    }

    // MARK: - Purity

    func testGoalBaselineIsPure() {
        let now = midWeekNow()
        let plan = WeeklyPlan(targetSessions: 4, focusRegions: [.legs])
        _ = GoalBaseline(plan: plan).underTrainedMuscle(workouts: [], now: now)

        XCTAssertNil(
            UserDefaults.standard.object(forKey: "xomfit.nudge.lastNudgeDay"),
            "Baseline must not write the gate key"
        )
        XCTAssertNil(
            UserDefaults.standard.data(forKey: "xomfit.weeklyPlan"),
            "Baseline must not write the plan key (plan is injected, not read here)"
        )
    }

    // MARK: - Service wiring

    func testServiceUsesGoalBaselineWhenPlanSaved() {
        let now = midWeekNow()
        // Save a focus plan; the default resolvedBaseline() should pick it up.
        WeeklyPlanService.shared.save(WeeklyPlan(targetSessions: 4, focusRegions: [.legs]))

        // Enough total workouts to clear the cold-start floor, none this week so the
        // leg focus deficit stands; none logged today.
        var workouts: [Workout] = []
        let ws = weekStart(for: now)
        for i in 0..<10 {
            let date = calendar.date(byAdding: .day, value: -7 * (10 + i) - 2, to: ws)!
            workouts.append(workout(id: "pad\(i)", muscle: .chest, sets: 2, date: date))
        }

        let result = TrainingNudgeService.nudgeForLaunch(workouts: workouts, now: now)

        XCTAssertNotNil(result)
        XCTAssertTrue(
            TrainingRegion.legs.muscles.contains(result!.muscle),
            "Service default baseline should resolve to the saved GoalBaseline plan"
        )
    }
}
