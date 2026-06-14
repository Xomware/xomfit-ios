import Foundation

/// Once-per-day training nudge decision. Mirrors `BadgeToastService`'s seam shape
/// (a `@MainActor enum` that returns at most one value and commits a "seen"
/// marker), but as a sibling so the once-per-launch badge path is untouched.
///
/// `MainTabView` evaluates this only when `BadgeToastService.badgeForLaunch`
/// returns nil — the streak/PR badge always wins the launch.
///
/// The actual under-training detection is delegated to an injected
/// `NudgeBaseline` (Seam 1, default `AdaptiveBaseline`). This service owns only
/// the gating: once-per-day, cold-start, and workout-logged-today suppression.
@MainActor
enum TrainingNudgeService {
    private static let lastNudgeDayKey = "xomfit.nudge.lastNudgeDay"

    /// Below this total workout count we suppress the nudge entirely — a brand
    /// new user has no meaningful baseline yet (cold start).
    static let minWorkoutsForNudge: Int = 8

    /// Resolves the default baseline: a `GoalBaseline` wrapping the adaptive
    /// fallback, seeded with the saved `WeeklyPlan` (or `nil` when none). With no
    /// plan, `GoalBaseline` delegates verbatim to `AdaptiveBaseline`, so the
    /// behavior is identical to Phase 2 and `MainTabView`'s call site (which
    /// passes no baseline) automatically gets goal-or-adaptive.
    private static func resolvedBaseline() -> NudgeBaseline {
        GoalBaseline(plan: WeeklyPlanService.shared.currentPlan())
    }

    /// Once-per-day gated nudge decision. When no `baseline` is passed it resolves
    /// to a `GoalBaseline` (goal-driven when a plan exists, adaptive otherwise).
    ///
    /// The default is a `nil` sentinel rather than `resolvedBaseline()` directly:
    /// default-arg expressions evaluate in a nonisolated context, but
    /// `WeeklyPlanService.shared` is `@MainActor`, so the resolution must happen
    /// inside this MainActor-isolated body. `MainTabView`'s call site (passing no
    /// baseline) is unchanged and picks up the goal-or-adaptive default.
    ///
    /// `now` is injectable for tests; commits `lastNudgeDay` (start of day) only
    /// when it returns a non-nil nudge, so tapping/dismissing doesn't re-fire the
    /// same day.
    static func nudgeForLaunch(
        workouts: [Workout],
        baseline: NudgeBaseline? = nil,
        now: Date = Date()
    ) -> UnderTrainedMuscle? {
        let baseline = baseline ?? resolvedBaseline()
        let defaults = UserDefaults.standard
        let cal = WorkoutInsights.userCalendar()

        // Once-per-day gate: already nudged today → stay quiet.
        if let lastNudgeDay = defaults.object(forKey: lastNudgeDayKey) as? Date,
           cal.isDate(lastNudgeDay, inSameDayAs: now) {
            return nil
        }

        // Cold-start suppression: not enough history for a real baseline.
        if workouts.count < minWorkoutsForNudge { return nil }

        // Workout-logged-today suppression: don't nag on a day they already lifted.
        let today = cal.startOfDay(for: now)
        let trainedToday = workouts.contains { cal.startOfDay(for: $0.startTime) == today }
        if trainedToday { return nil }

        // Delegate the firing decision to the baseline strategy.
        guard let nudge = baseline.underTrainedMuscle(workouts: workouts, now: now) else {
            return nil
        }

        // Commit the day so we don't re-fire until tomorrow.
        defaults.set(cal.startOfDay(for: now), forKey: lastNudgeDayKey)
        return nudge
    }

    /// Test seam — clear persisted state.
    static func resetForTesting() {
        UserDefaults.standard.removeObject(forKey: lastNudgeDayKey)
    }
}
