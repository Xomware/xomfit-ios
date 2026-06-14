import Foundation

// MARK: - Seam 1 — NudgeBaseline strategy

/// The single muscle the training nudge will surface, plus user-facing copy.
///
/// The nudge is body-part granular (one of the 13 `MuscleGroup` cases), never a
/// region or a list — it points at exactly one muscle to keep the nudge gentle.
struct UnderTrainedMuscle: Equatable {
    let muscle: MuscleGroup
    /// User-facing reason, e.g. "You usually hit chest by now this week".
    let reason: String
}

/// Strategy the training nudge consumes to decide "what counts as under-trained."
///
/// Phase 2 ships `AdaptiveBaseline`; Phase 3 adds a goal-driven conformer. The
/// protocol stays injectable so neither `TrainingNudgeService` nor the views
/// change when the strategy changes.
protocol NudgeBaseline {
    /// Returns the single most-behind muscle, or nil if nothing should be nudged.
    ///
    /// `now` is injected (never `Date()` internally) so the decision is
    /// deterministically testable.
    func underTrainedMuscle(workouts: [Workout], now: Date) -> UnderTrainedMuscle?
}

// MARK: - AdaptiveBaseline (proportional pacing)

/// Zero-config adaptive baseline. For each muscle it compares this week's logged
/// sets against the muscle's OWN trailing-4-week weekly average, pro-rated by how
/// far into the current week we are ("proportional pacing"). It fires only for a
/// genuine personal deficit against an established baseline, late enough in the
/// week to be meaningful — and surfaces only the single most-behind muscle.
///
/// This is the load-bearing core of Phase 2: with 13 muscle groups, something
/// almost always looks "behind average," so the firing condition is deliberately
/// conservative and fully unit-tested.
struct AdaptiveBaseline: NudgeBaseline {

    // MARK: Tuning constants (single source of truth)

    /// Trailing window length used to establish each muscle's baseline pace.
    static let trailingWeeks: Int = 4
    /// Below this avg sets/week, the muscle is treated as never/barely trained
    /// and is skipped — the nudge can't invent a deficit for a muscle the user
    /// has chosen to ignore.
    static let minWeeklyBaselineSets: Double = 2.0
    /// Fire only when this week's actual sets are below this fraction of the
    /// expected-by-now level (genuine deficit, not merely "slightly behind").
    static let deficitFraction: Double = 0.5
    /// Require at least this fraction of the week to have elapsed before firing —
    /// early-week absences aren't meaningful.
    static let minWeekFraction: Double = 0.4

    func underTrainedMuscle(workouts: [Workout], now: Date) -> UnderTrainedMuscle? {
        let cal = WorkoutInsights.userCalendar()

        guard let weekStart = cal.dateInterval(of: .weekOfYear, for: now)?.start else {
            return nil
        }

        // Days elapsed into the current week, clamped to 1...7 (day 1 = weekStart).
        let rawDays = (cal.dateComponents([.day], from: weekStart, to: now).day ?? 0) + 1
        let daysElapsed = min(max(rawDays, 1), 7)
        let weekFraction = Double(daysElapsed) / 7.0

        // Condition (c): not far enough into the week for an absence to matter.
        if weekFraction < Self.minWeekFraction { return nil }

        // Trailing baseline window: the `trailingWeeks` full weeks BEFORE the
        // current week (current week excluded from the baseline).
        guard let windowStart = cal.date(byAdding: .day, value: -7 * Self.trailingWeeks, to: weekStart) else {
            return nil
        }

        // Baseline window strictly excludes the current week, so window the
        // workouts to [windowStart, weekStart).
        let baselineWorkouts = workouts.filter { $0.startTime >= windowStart && $0.startTime < weekStart }
        let baselineSets = WorkoutInsights.setsPerMuscleGroup(workouts: baselineWorkouts)
        let actualSets = WorkoutInsights.setsPerMuscleGroup(workouts: workouts, since: weekStart)

        struct Candidate {
            let muscle: MuscleGroup
            let ratio: Double          // actual / expectedByNow (smaller = more behind)
            let expectedByNow: Double
        }

        var candidates: [Candidate] = []
        for muscle in MuscleGroup.allCases {
            let avgWeekly = Double(baselineSets[muscle, default: 0]) / Double(Self.trailingWeeks)
            // Condition (b): skip never/barely-trained muscles.
            if avgWeekly < Self.minWeeklyBaselineSets { continue }

            let expectedByNow = avgWeekly * weekFraction
            let actual = Double(actualSets[muscle, default: 0])

            // Condition (a): genuine deficit vs this muscle's OWN by-now pace.
            guard actual < Self.deficitFraction * expectedByNow else { continue }

            let ratio = expectedByNow == 0 ? 0 : actual / expectedByNow
            candidates.append(Candidate(muscle: muscle, ratio: ratio, expectedByNow: expectedByNow))
        }

        guard !candidates.isEmpty else { return nil }

        // Surface the single most-behind muscle: smallest ratio wins; ties broken
        // by larger expectedByNow, then by MuscleGroup.allCases order.
        let order = MuscleGroup.allCases
        let best = candidates.min { lhs, rhs in
            if lhs.ratio != rhs.ratio { return lhs.ratio < rhs.ratio }
            if lhs.expectedByNow != rhs.expectedByNow { return lhs.expectedByNow > rhs.expectedByNow }
            let li = order.firstIndex(of: lhs.muscle) ?? Int.max
            let ri = order.firstIndex(of: rhs.muscle) ?? Int.max
            return li < ri
        }!

        return UnderTrainedMuscle(
            muscle: best.muscle,
            reason: "You usually hit \(best.muscle.displayName.lowercased()) by now this week"
        )
    }
}

// MARK: - GoalBaseline (plan-driven pacing)

/// Goal-directed baseline (Phase 3). When an explicit `WeeklyPlan` is set, it
/// paces the plan's focus muscles against a plan-derived expected dose and
/// surfaces the single focus muscle most behind that pace. When there is no plan,
/// no focus, or no focus-muscle deficit, it delegates VERBATIM to a wrapped
/// `AdaptiveBaseline` — so the no-plan path is byte-for-byte Phase-2 behavior.
///
/// Pure struct: the plan is injected via `init` (no `UserDefaults` reads), `now`
/// is injected. `TrainingNudgeService` owns the plan lookup + gating.
struct GoalBaseline: NudgeBaseline {

    let plan: WeeklyPlan?
    let fallback: AdaptiveBaseline

    init(plan: WeeklyPlan?, fallback: AdaptiveBaseline = AdaptiveBaseline()) {
        self.plan = plan
        self.fallback = fallback
    }

    // MARK: Tuning constants (single source of truth)

    /// Assumed working-set dose per focus muscle per planned session. The one
    /// genuinely new dial in Phase 3 — tune here.
    static let setsPerSessionPerMuscle: Double = 4.0
    /// Fire only when actual sets are below this fraction of expected-by-now
    /// (mirrors `AdaptiveBaseline.deficitFraction`).
    static let deficitFraction: Double = 0.5
    /// Require this fraction of the week elapsed before firing (mirrors
    /// `AdaptiveBaseline.minWeekFraction`). No early-week firing.
    static let minWeekFraction: Double = 0.4

    func underTrainedMuscle(workouts: [Workout], now: Date) -> UnderTrainedMuscle? {
        // Step 1 — no plan / no focus → adaptive.
        guard let plan, !plan.focusMuscles.isEmpty else {
            return fallback.underTrainedMuscle(workouts: workouts, now: now)
        }

        let cal = WorkoutInsights.userCalendar()
        guard let weekStart = cal.dateInterval(of: .weekOfYear, for: now)?.start else {
            return fallback.underTrainedMuscle(workouts: workouts, now: now)
        }

        // Step 2 — week framing (identical math to AdaptiveBaseline).
        let rawDays = (cal.dateComponents([.day], from: weekStart, to: now).day ?? 0) + 1
        let daysElapsed = min(max(rawDays, 1), 7)
        let weekFraction = Double(daysElapsed) / 7.0

        // Condition (c): not far enough into the week to be meaningful.
        if weekFraction < Self.minWeekFraction { return nil }

        // Step 3 — plan-derived expected pace per focus muscle. Note: NO
        // minWeeklyBaselineSets floor — the plan is explicit intent, so a focus
        // muscle is "expected" even with zero trailing history.
        let actualSets = WorkoutInsights.setsPerMuscleGroup(workouts: workouts, since: weekStart)
        let expectedWeeklySets = Self.setsPerSessionPerMuscle * Double(plan.targetSessions)
        let expectedByNow = expectedWeeklySets * weekFraction

        struct Candidate {
            let muscle: MuscleGroup
            let ratio: Double          // actual / expectedByNow (smaller = more behind)
            let expectedByNow: Double
        }

        var candidates: [Candidate] = []
        for muscle in plan.focusMuscles {
            let actual = Double(actualSets[muscle, default: 0])

            // Step 4 — condition (a): genuine deficit vs the plan's by-now pace.
            guard actual < Self.deficitFraction * expectedByNow else { continue }

            let ratio = expectedByNow == 0 ? 0 : actual / expectedByNow
            candidates.append(Candidate(muscle: muscle, ratio: ratio, expectedByNow: expectedByNow))
        }

        // Step 6 — no focus muscle behind plan pace → adaptive fallback.
        guard !candidates.isEmpty else {
            return fallback.underTrainedMuscle(workouts: workouts, now: now)
        }

        // Step 5 — most-behind selection: smallest ratio wins; ties broken by
        // larger expectedByNow, then MuscleGroup.allCases order (same shape as
        // AdaptiveBaseline).
        let order = MuscleGroup.allCases
        let best = candidates.min { lhs, rhs in
            if lhs.ratio != rhs.ratio { return lhs.ratio < rhs.ratio }
            if lhs.expectedByNow != rhs.expectedByNow { return lhs.expectedByNow > rhs.expectedByNow }
            let li = order.firstIndex(of: lhs.muscle) ?? Int.max
            let ri = order.firstIndex(of: rhs.muscle) ?? Int.max
            return li < ri
        }!

        // Step 7 — goal-directive copy (distinct from the adaptive reason).
        return UnderTrainedMuscle(
            muscle: best.muscle,
            reason: "\(best.muscle.displayName) is behind your weekly plan"
        )
    }
}
