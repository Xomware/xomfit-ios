# Execution Log — Workout Generator: Phase 3 (Weekly Planner)

## 2026-06-14 — Full Phase 3 implementation

Executed all 10 ordered Implementation Steps from `PLAN.md`.

### Steps completed
1. **`TrainingRegion` Codable + `WeeklyPlan.swift`** — added synthesized `Codable`
   to `TrainingRegion` (one-line, String raw enum) in `Utils/WorkoutInsights.swift`;
   created `Models/WeeklyPlan.swift` (`Codable, Equatable`; `targetSessions`,
   `focusRegions`; computed `focusMuscles` expanding regions via Seam-3
   `TrainingRegion.muscles`, deduped preserving first occurrence).
2. **`WeeklyPlanService.swift`** — `@MainActor final class`, `static let shared`,
   `currentPlan()/save/clear/resetForTesting` over key `"xomfit.weeklyPlan"`,
   JSON-encoded. Mirrors `TemplateService` (graceful `nil` on missing/corrupt).
3. **`GoalBaseline` in `NudgeBaseline.swift`** — second `NudgeBaseline` conformer.
   Self-falling-back: delegates verbatim to wrapped `AdaptiveBaseline` when
   plan==nil, focus empty, or no focus-muscle candidate. Plan-driven pacing:
   `expectedByNow = setsPerSessionPerMuscle * targetSessions * weekFraction`; fires
   when `actual < deficitFraction * expectedByNow` AND `weekFraction >= minWeekFraction`;
   surfaces smallest actual/expected ratio (same tiebreak shape as Adaptive).
   Constants: `setsPerSessionPerMuscle=4.0`, `deficitFraction=0.5`,
   `minWeekFraction=0.4`. NO `minWeeklyBaselineSets` floor (plan is explicit intent).
4. **`TrainingNudgeService.swift`** — added `private static func resolvedBaseline()
   -> NudgeBaseline { GoalBaseline(plan: WeeklyPlanService.shared.currentPlan()) }`.
   Default-arg changed to a `nil` sentinel resolved inside the MainActor-isolated
   body (see Deviation 1). `MainTabView` call site unchanged.
5. **`WeeklyPlanViewModel.swift`** — `@MainActor @Observable`; loads/edits
   `targetSessions` + `focusRegions`, `hasPlan`, `toggle(_:)`, `save()` (clamps
   1...14), `clearPlan()`.
6. **`WeeklyPlanView.swift`** — `List`/`Section` screen styled with `Theme`:
   sessions stepper, region toggle rows (`TrainingRegion.allCases`), Save/Clear.
   VoiceOver labels + 44pt min targets + haptics.
7. **`SettingsView.swift`** — added "Weekly Plan" `NavigationLink` to `trainingSection`
   (between Fitness Goals and Reports) with a `weeklyPlanSummary` trailing label
   ("4× · Legs, Pull" / "Not set") mirroring `fitnessGoalsSummary`.
8. **`XomFitTests/GoalBaselineTests.swift`** — 9 deterministic tests (see below).
9. **Registered** `GoalBaselineTests.swift` in the `XomfitTests` target via the
   xcodeproj gem; verified it appears in `source_build_phase` and the executed
   test count rose from 152 → 161.
10. **Suite run** — `** TEST SUCCEEDED **`, 161 executed, 0 failures.

### Tests (9, all passing)
- testFiresWhenFocusMuscleBehindPlan
- testDoesNotFireWhenFocusMuscleOnPace
- testEarlyWeekSuppressed
- testPicksMostBehindFocusMuscle
- testNoPlanFallsBackToAdaptive (byte-for-byte adaptive equivalence)
- testEmptyFocusFallsBackToAdaptive
- testNoFocusDeficitFallsBackToAdaptive
- testGoalBaselineIsPure (writes neither gate nor plan key)
- testServiceUsesGoalBaselineWhenPlanSaved (resolvedBaseline wiring)

### Deviations
1. **`nudgeForLaunch` default-arg.** PLAN specified
   `baseline: NudgeBaseline = resolvedBaseline()`. Swift evaluates default-arg
   expressions in a nonisolated context, but `resolvedBaseline()` reads
   `@MainActor WeeklyPlanService.shared`, which fails to compile (actor isolation).
   Resolved by making the param `baseline: NudgeBaseline? = nil` and resolving via
   `baseline ?? resolvedBaseline()` inside the MainActor-isolated function body.
   Behavior is identical: `MainTabView` (passes no baseline) gets goal-or-adaptive;
   tests passing an explicit baseline still work. No call-site change.

### Verification
- Build: `** BUILD SUCCEEDED **` (iPhone 17 sim, Debug).
- Test: `** TEST SUCCEEDED **`, 161 executed, 0 failures (152 prior + 9 new).
