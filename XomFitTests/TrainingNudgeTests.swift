import XCTest
@testable import Xomfit

/// Deterministic unit tests for the Phase-2 training nudge: the `AdaptiveBaseline`
/// proportional-pacing firing condition and the `TrainingNudgeService` gating.
///
/// Every test injects synthetic `[Workout]` fixtures plus a fixed `now`, and pins
/// the `weekStartDay` preference so `WorkoutInsights.userCalendar()` is
/// deterministic. No real-clock dependence.
@MainActor
final class TrainingNudgeTests: XCTestCase {

    // MARK: - Setup

    private var calendar: Calendar = .current

    override func setUp() {
        super.setUp()
        TrainingNudgeService.resetForTesting()
        // Sunday-start week so weekStart math is deterministic (firstWeekday = 1).
        UserDefaults.standard.set(0, forKey: "weekStartDay")
        calendar = WorkoutInsights.userCalendar()
    }

    override func tearDown() {
        TrainingNudgeService.resetForTesting()
        UserDefaults.standard.removeObject(forKey: "weekStartDay")
        super.tearDown()
    }

    // MARK: - Fixtures

    /// A synthetic exercise targeting exactly one muscle so set-counting is clean.
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

    /// One workout on `date` logging `sets` sets for a single `muscle`.
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

    /// A fixed `now` that lands mid-week (Wednesday) so `weekFraction ≈ 0.57`,
    /// comfortably past `minWeekFraction` (0.4).
    private func midWeekNow() -> Date {
        // 2025-06-11 is a Wednesday (Sunday-start week → day 4 of 7).
        var comps = DateComponents()
        comps.year = 2025
        comps.month = 6
        comps.day = 11
        comps.hour = 12
        return calendar.date(from: comps)!
    }

    /// `weekStart` for a given `now` under the active calendar.
    private func weekStart(for now: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: now)!.start
    }

    /// Build a trailing-4-week baseline of `setsPerWeek` for `muscle`, placed in
    /// the four full weeks BEFORE the current week.
    private func baselineWorkouts(
        muscle: MuscleGroup,
        setsPerWeek: Int,
        now: Date,
        idPrefix: String
    ) -> [Workout] {
        let ws = weekStart(for: now)
        var result: [Workout] = []
        for week in 1...AdaptiveBaseline.trailingWeeks {
            // Mid-point of each prior week so it's safely inside [windowStart, weekStart).
            let date = calendar.date(byAdding: .day, value: -7 * week + 3, to: ws)!
            result.append(workout(id: "\(idPrefix)-w\(week)", muscle: muscle, sets: setsPerWeek, date: date))
        }
        return result
    }

    // MARK: - AdaptiveBaseline firing

    func testFiresOnGenuineDeficit() {
        let now = midWeekNow()
        // Chest: 3 sets/week for 4 weeks (avg 3.0 ≥ floor); 0 chest this week.
        let workouts = baselineWorkouts(muscle: .chest, setsPerWeek: 3, now: now, idPrefix: "chest")

        let result = AdaptiveBaseline().underTrainedMuscle(workouts: workouts, now: now)

        XCTAssertEqual(result?.muscle, .chest)
    }

    func testDoesNotFireForNeverTrainedMuscle() {
        let now = midWeekNow()
        // Biceps: only 1 set/week (avg 1.0 < 2.0 floor) → must be skipped even at 0 this week.
        let workouts = baselineWorkouts(muscle: .biceps, setsPerWeek: 1, now: now, idPrefix: "biceps")

        let result = AdaptiveBaseline().underTrainedMuscle(workouts: workouts, now: now)

        XCTAssertNil(result)
    }

    func testDoesNotFireWhenOnPaceVsOwnBaseline() {
        let now = midWeekNow()
        // Chest baseline avg 3.0/wk → expectedByNow ≈ 1.71 at weekFraction ≈ 0.57.
        // Log 2 chest sets this week: 2 >= 0.5 * 1.71 → NOT a genuine deficit.
        var workouts = baselineWorkouts(muscle: .chest, setsPerWeek: 3, now: now, idPrefix: "chest")
        let ws = weekStart(for: now)
        let thisWeekDate = calendar.date(byAdding: .day, value: 1, to: ws)!
        workouts.append(workout(id: "chest-this", muscle: .chest, sets: 2, date: thisWeekDate))

        let result = AdaptiveBaseline().underTrainedMuscle(workouts: workouts, now: now)

        XCTAssertNil(result, "On-pace muscle must not fire (guards against naive below-average logic)")
    }

    func testDoesNotFireEarlyInWeek() {
        // Sunday (day 1 of 7) → weekFraction ≈ 0.14 < minWeekFraction (0.4).
        var comps = DateComponents()
        comps.year = 2025
        comps.month = 6
        comps.day = 8 // 2025-06-08 is a Sunday
        comps.hour = 9
        let now = calendar.date(from: comps)!

        let workouts = baselineWorkouts(muscle: .chest, setsPerWeek: 3, now: now, idPrefix: "chest")
        let result = AdaptiveBaseline().underTrainedMuscle(workouts: workouts, now: now)

        XCTAssertNil(result, "Should not fire before minWeekFraction of the week elapsed")
    }

    func testPicksLargestRelativeDeficit() {
        let now = midWeekNow()
        let ws = weekStart(for: now)
        // Two established muscles. Chest: avg 4/wk, 1 set this week (ratio higher).
        // Back: avg 4/wk, 0 sets this week (ratio 0 → most behind).
        var workouts = baselineWorkouts(muscle: .chest, setsPerWeek: 4, now: now, idPrefix: "chest")
        workouts += baselineWorkouts(muscle: .back, setsPerWeek: 4, now: now, idPrefix: "back")
        let thisWeekDate = calendar.date(byAdding: .day, value: 1, to: ws)!
        workouts.append(workout(id: "chest-this", muscle: .chest, sets: 1, date: thisWeekDate))

        let result = AdaptiveBaseline().underTrainedMuscle(workouts: workouts, now: now)

        XCTAssertEqual(result?.muscle, .back, "Smallest actual/expected ratio (back, 0 sets) should win")
    }

    func testEmptyHistoryReturnsNil() {
        let result = AdaptiveBaseline().underTrainedMuscle(workouts: [], now: midWeekNow())
        XCTAssertNil(result)
    }

    func testBaselineDoesNotTouchLastNudgeDay() {
        let now = midWeekNow()
        let workouts = baselineWorkouts(muscle: .chest, setsPerWeek: 3, now: now, idPrefix: "chest")
        _ = AdaptiveBaseline().underTrainedMuscle(workouts: workouts, now: now)
        XCTAssertNil(
            UserDefaults.standard.object(forKey: "xomfit.nudge.lastNudgeDay"),
            "Baseline must be pure — the gate lives only in the service"
        )
    }

    // MARK: - TrainingNudgeService gating

    @MainActor
    func testServiceFiresAndCommitsDay() {
        let now = midWeekNow()
        // 4 baseline weeks = 4 workouts; pad to clear the cold-start floor.
        var workouts = baselineWorkouts(muscle: .chest, setsPerWeek: 4, now: now, idPrefix: "chest")
        workouts += extraColdStartPadding(now: now)

        let result = TrainingNudgeService.nudgeForLaunch(workouts: workouts, now: now)
        XCTAssertEqual(result?.muscle, .chest)
    }

    @MainActor
    func testServiceOncePerDayGate() {
        let now = midWeekNow()
        var workouts = baselineWorkouts(muscle: .chest, setsPerWeek: 4, now: now, idPrefix: "chest")
        workouts += extraColdStartPadding(now: now)

        let first = TrainingNudgeService.nudgeForLaunch(workouts: workouts, now: now)
        XCTAssertEqual(first?.muscle, .chest)

        // Same day → suppressed.
        let second = TrainingNudgeService.nudgeForLaunch(workouts: workouts, now: now)
        XCTAssertNil(second)

        // Next day → fires again (still mid-week, Thursday).
        let nextDay = calendar.date(byAdding: .day, value: 1, to: now)!
        let third = TrainingNudgeService.nudgeForLaunch(workouts: workouts, now: nextDay)
        XCTAssertEqual(third?.muscle, .chest)
    }

    @MainActor
    func testServiceColdStartSuppression() {
        let now = midWeekNow()
        // Only the 4 baseline workouts → below minWorkoutsForNudge (8).
        let workouts = baselineWorkouts(muscle: .chest, setsPerWeek: 4, now: now, idPrefix: "chest")
        XCTAssertLessThan(workouts.count, TrainingNudgeService.minWorkoutsForNudge)

        let result = TrainingNudgeService.nudgeForLaunch(workouts: workouts, now: now)
        XCTAssertNil(result, "Cold-start users (too few workouts) must not be nudged")
    }

    @MainActor
    func testServiceWorkoutLoggedTodaySuppression() {
        let now = midWeekNow()
        var workouts = baselineWorkouts(muscle: .chest, setsPerWeek: 4, now: now, idPrefix: "chest")
        workouts += extraColdStartPadding(now: now)
        // A workout logged today (different muscle so the deficit still exists).
        workouts.append(workout(id: "today", muscle: .quads, sets: 3, date: now))

        let result = TrainingNudgeService.nudgeForLaunch(workouts: workouts, now: now)
        XCTAssertNil(result, "Suppress the nudge on a day the user already trained")
    }

    @MainActor
    func testServiceEmptyHistoryNoCrash() {
        let result = TrainingNudgeService.nudgeForLaunch(workouts: [], now: midWeekNow())
        XCTAssertNil(result)
    }

    // MARK: - Helpers

    /// Extra workouts (on a different, never-trained-enough muscle, well outside
    /// the chest baseline window) purely to push total count past the cold-start
    /// floor without altering the chest baseline/this-week math. Placed far in
    /// the past (before the 4-week window) so they don't affect detection.
    private func extraColdStartPadding(now: Date) -> [Workout] {
        let ws = weekStart(for: now)
        // 6 workouts, each ~10..15 weeks ago (outside the 4-week baseline window).
        return (0..<6).map { i in
            let date = calendar.date(byAdding: .day, value: -7 * (10 + i) - 2, to: ws)!
            return workout(id: "pad\(i)", muscle: .calves, sets: 1, date: date)
        }
    }
}
