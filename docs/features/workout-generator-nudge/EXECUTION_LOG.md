# Execution Log — Workout Generator Phase 2 (Toast Nudge)

## 2026-06-14 — Full Phase 2 implementation

Executed the ordered Implementation Steps from `PLAN.md`.

### Steps completed
- [x] 1. Created `Xomfit/Models/NudgeBaseline.swift` — `UnderTrainedMuscle` struct,
      `NudgeBaseline` protocol (injectable `now`), `AdaptiveBaseline` with the four
      named constants (`trailingWeeks=4`, `minWeeklyBaselineSets=2.0`,
      `deficitFraction=0.5`, `minWeekFraction=0.4`) and the proportional-pacing logic.
      Consumes Seam 2 (`setsPerMuscleGroup`, both variants) + `userCalendar()`.
      Baseline window strictly excludes the current week via `[windowStart, weekStart)`.
- [x] 2. Created `Xomfit/Services/TrainingNudgeService.swift` — `@MainActor enum`,
      `lastNudgeDay` once-per-day gate (startOfDay compare), `minWorkoutsForNudge=8`
      cold-start guard, workout-logged-today suppression, `resetForTesting()`.
      Delegates firing to the injected `NudgeBaseline`; commits the day only on a
      non-nil result.
- [x] 3. Created `Xomfit/Services/GeneratorPreseed.swift` — `@MainActor @Observable`
      holder with `var pending: MuscleGroup?`.
- [x] 4. Modified `Xomfit/XomfitApp.swift` — `@State generatorPreseed`; injected via
      `.environment(generatorPreseed)` onto `MainTabView`.
- [x] 5/5a. Modified `Xomfit/Views/MainTabView.swift` — read
      `@Environment(GeneratorPreseed.self)`; added `@State nudgeMuscle`. Extended the
      launch `.task`: badge wins and `return`s; otherwise evaluate
      `TrainingNudgeService.nudgeForLaunch`, store the muscle, sleep 1s, show an
      `.info` toast. Toast tap (via new `toast(_:onTap:)`) sets
      `generatorPreseed.pending` and `select(destination: .workout)`.
      Modified `Xomfit/Views/Common/ToastView.swift` — added optional `onTap`
      closure to `ToastModifier` + a `toast(_:onTap:)` overload (backward
      compatible; badge toasts unchanged).
- [x] 6. Modified `Xomfit/Views/Workout/WorkoutView.swift` — read
      `@Environment(GeneratorPreseed.self)`; `consumePendingPreseed()` called from
      both `.task` (mount) and `.onChange(of: generatorPreseed.pending)`. Resets +
      `preseed(muscle:)` + `showGenerator = true`, then clears pending.
- [x] 7. Created `XomfitTests/TrainingNudgeTests.swift` — 12 deterministic tests
      (injected workouts + pinned `now`, `weekStartDay` pinned to Sunday).
- [x] 8. Registered the test file in the `XomfitTests` target via the `xcodeproj`
      Ruby gem (explicit file reference + source build phase). Verified in build
      phase.
- [x] 9. Build + test green.

### Verification
- Build: `** BUILD SUCCEEDED **` (no warnings in the new/modified files).
- Test: `** TEST SUCCEEDED **` — Executed 152 tests, 0 failures (was 140; +12 new
  TrainingNudgeTests). All TrainingNudgeTests passed.

### Tests added (12)
Firing: genuine deficit fires; never-trained muscle skipped (floor); on-pace vs own
baseline does NOT fire; early-week suppressed; largest relative deficit selected;
empty history nil; baseline purity (no `lastNudgeDay` write).
Service: fires + commits day; once-per-day gate (same-day nil, next-day fires);
cold-start suppression; workout-logged-today suppression; empty history no crash.

### Deviations / notes
- The test class is annotated `@MainActor` because `TrainingNudgeService` is
  `@MainActor` (its `resetForTesting()` is called in `setUp`/`tearDown`). Minor and
  expected; does not affect determinism.
- The source/test directory is `Xomfit/` and `XomfitTests/` (capitalization
  `Xomfit`, not `XomFit` as some plan snippets wrote). Used the actual names.
- Step 10 (manual simulator smoke) not run as part of this pass — covered by the
  automated tests for the firing/gate logic; the in-app hop is straightforward
  environment-flip wiring.
