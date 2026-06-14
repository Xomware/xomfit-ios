# Plan: Workout Generator System — Phase 3: Weekly Planner

**Epic**: workout-generator
**Sub-feature ID**: P3 (Phase 3 — PLANNER / additive)
**Status**: Ready
**Created**: 2026-06-14
**Last updated**: 2026-06-14
**Depends on**: P2 (workout-generator-nudge) — hard dependency; ships an alternate `NudgeBaseline`
strategy and needs Seam 1 + `TrainingNudgeService` live from Phase 2 (both confirmed built).
(Transitively depends on P1.)

> Parent epic: `docs/features/workout-generator/PLAN.md`. This sub-plan implements
> **Phase 3 — PLANNER** only. The epic's **Shared Seams** section is the source of truth; this
> plan **references** the contracts, never redefines them.

## Summary
Let the user set an explicit weekly training goal — target sessions/week plus focus regions (e.g.
"4x this week, focus Legs + Pull"). When a plan exists, the nudge baseline becomes goal-driven
(surfaces the focus muscle the user is most behind on relative to the plan's pacing); when no plan
is set, it falls back to the Phase-2 `AdaptiveBaseline` byte-for-byte. Local-only persistence
(UserDefaults, mirroring `TemplateService`), a lightweight set-goal screen reached from Settings →
Training, and a second `NudgeBaseline` conformer. Purely additive: the toast/`MainTabView` decision
flow is unchanged beyond which baseline gets injected.

## Approach
Per the epic's locked Phase-3 decisions and the recommendation in
`docs/features/workout-generator/BRAINSTORM.md` (Option 2 + deferred Option 3, with the nudge
baseline pluggable from day one). Phase 2 already left the seam open: `TrainingNudgeService`
delegates the firing decision to an injected `NudgeBaseline` and owns only the gating (once-per-day,
cold-start, workout-logged-today). Phase 3 supplies a `GoalBaseline` that wraps the existing
`AdaptiveBaseline` and is selected by the service when a plan exists.

Concrete grounding from the codebase (read, not assumed):
- **Seam 1 (`NudgeBaseline`)** — `Xomfit/Models/NudgeBaseline.swift`. Protocol method is
  `func underTrainedMuscle(workouts: [Workout], now: Date) -> UnderTrainedMuscle?`; `now` is always
  injected (never `Date()` internally). `UnderTrainedMuscle = { muscle: MuscleGroup; reason: String }`.
  `AdaptiveBaseline` is a pure `struct` with tuning constants `trailingWeeks`, `minWeeklyBaselineSets`,
  `deficitFraction`, `minWeekFraction`. `GoalBaseline` is added in the SAME file as a second conformer.
- **Seam 2 (sets-per-muscle)** — `WorkoutInsights.setsPerMuscleGroup(workouts:)` and the windowed
  `setsPerMuscleGroup(workouts:since:)`. `GoalBaseline` CONSUMES these for deficit math.
- **Seam 3 (region rollup)** — `TrainingRegion` enum (`push/pull/legs/core`) with `.muscles`
  (reverse map) and `MuscleGroup.region` (forward map) in `WorkoutInsights.swift`. `GoalBaseline`
  expands `WeeklyPlan.focusRegions` to `MuscleGroup`s via `TrainingRegion.muscles`.
- **Persistence pattern** — `TemplateService` (`@MainActor final class`, `UserDefaults` data key,
  `JSONEncoder`/`JSONDecoder`, `static let shared`). `WeeklyPlanService` mirrors this exactly.
- **Service wiring** — `TrainingNudgeService.nudgeForLaunch(workouts:baseline:now:)` has a default
  `baseline: NudgeBaseline = AdaptiveBaseline()`. Default is changed to resolve a `GoalBaseline`
  wrapping adaptive so `MainTabView`'s existing call site (`MainTabView.swift:206`) needs no change.
- **UI home** — `SettingsView.trainingSection` (`Xomfit/Views/Profile/SettingsView.swift:260`)
  already groups "Fitness Goals" and "Reports" as `NavigationLink`s. A "Weekly Plan" row slots in
  here, matching the existing `target` SF Symbol style and trailing-summary pattern.

### Why no `MainTabView` / call-site change
`MainTabView.swift:206` calls `TrainingNudgeService.nudgeForLaunch(workouts:)` with no explicit
baseline, relying on the default-arg. We change the default-arg to resolve the goal-or-adaptive
baseline internally (the service reads the saved plan and constructs the wrapper). The view layer is
untouched; the deep-link / `GeneratorPreseed` hop is unchanged because `GoalBaseline` still returns
a single `UnderTrainedMuscle`.

## Shared Seams — OWNS vs CONSUMES (see epic for canonical definitions)

| Seam | This phase |
|------|-----------|
| **Seam 1 — `NudgeBaseline` protocol** | **OWNS the `GoalBaseline` impl** — adds a second conformer in `NudgeBaseline.swift`; protocol unchanged |
| **Seam 2 — `WorkoutInsights.setsPerMuscleGroup(...)`** | **CONSUMES** (deficit math); does NOT redefine |
| **Seam 3 — `TrainingRegion` / `MuscleGroup.region`** | **CONSUMES** — `focusRegions` expand to `MuscleGroup`s via `TrainingRegion.muscles` |

Also **OWNS** the `WeeklyPlan` model and `WeeklyPlanService` (new contracts local to Phase 3).

## Affected Files / Components
| File / Component | Change | Why |
|-----------------|--------|-----|
| `Xomfit/Models/WeeklyPlan.swift` | **create** | `Codable` value type: `targetSessions: Int`, `focusRegions: [TrainingRegion]`. Named `WeeklyPlan` (NOT `TrainingGoal` — that enum exists at `Models/TrainingGoal.swift`) |
| `Xomfit/Services/WeeklyPlanService.swift` | **create** | `@MainActor final class`, `static let shared`, load/save/clear via `UserDefaults` JSON. Mirrors `TemplateService` |
| `Xomfit/Models/NudgeBaseline.swift` | **modify** | Add `GoalBaseline: NudgeBaseline` (goal-driven; delegates to wrapped `AdaptiveBaseline` when plan is nil) with named firing constants |
| `Xomfit/Services/TrainingNudgeService.swift` | **modify** | Add a `resolvedBaseline()` helper + change `nudgeForLaunch` default-arg to use it (GoalBaseline wrapping adaptive when a plan exists). No signature break |
| `Xomfit/ViewModels/WeeklyPlanViewModel.swift` | **create** | `@MainActor @Observable`; wraps `WeeklyPlanService` load/save; exposes editable `targetSessions` + `focusRegions` + `hasPlan` |
| `Xomfit/Views/Profile/WeeklyPlanView.swift` | **create** | Lightweight set/edit screen: session-count stepper + region multi-select chips + Save/Clear |
| `Xomfit/Views/Profile/SettingsView.swift` | **modify** | Add a "Weekly Plan" `NavigationLink` row to `trainingSection` with a plan-summary trailing label |
| `XomFitTests/GoalBaselineTests.swift` | **create** | Deterministic `GoalBaseline` firing + fallback-selection tests (injected plan + workouts + fixed `now`) |
| `Xomfit.xcodeproj/project.pbxproj` | **modify (via xcodeproj gem)** | Register `GoalBaselineTests.swift` in the `XomfitTests` target — explicit file refs, won't run otherwise |

## Key Contracts

### `WeeklyPlan` (model shape)
```
struct WeeklyPlan: Codable, Equatable {
    var targetSessions: Int          // workouts/week target, e.g. 4 (clamp 1...14)
    var focusRegions: [TrainingRegion]   // Seam-3 vocab; [] == "no specific focus"
    // No stored weekStart: week boundaries come from WorkoutInsights.userCalendar()
    // at evaluation time so the plan tracks the user's weekStartDay preference live.

    /// Focus muscles expanded via the Seam-3 reverse map (deduped, stable order).
    var focusMuscles: [MuscleGroup] {
        focusRegions.flatMap { $0.muscles }   // dedupe preserving first occurrence
    }
}
```
- Persisted as a single JSON blob under one UserDefaults key (mirrors `TemplateService` encode/decode).
- `focusRegions == []` is valid: it means "I have a session-count goal but no body-part focus";
  `GoalBaseline` then has no focus muscles to pace and effectively defers to the adaptive fallback
  for muscle selection (see firing logic).

### `WeeklyPlanService` (API)
```
@MainActor
final class WeeklyPlanService {
    static let shared: WeeklyPlanService
    func currentPlan() -> WeeklyPlan?      // nil when never set / cleared
    func save(_ plan: WeeklyPlan)
    func clear()
    static func resetForTesting()          // clears the key (test seam, like TrainingNudgeService)
}
```
- Key: `"xomfit.weeklyPlan"`. Load returns `nil` on missing/corrupt data (graceful, like
  `TemplateService.loadCustom`).

### `GoalBaseline` (signature + selection mechanism)
```
struct GoalBaseline: NudgeBaseline {
    let plan: WeeklyPlan?
    let fallback: AdaptiveBaseline

    init(plan: WeeklyPlan?, fallback: AdaptiveBaseline = AdaptiveBaseline())

    func underTrainedMuscle(workouts: [Workout], now: Date) -> UnderTrainedMuscle?
}
```
**Selection mechanism (the fallback wiring):** lives in `TrainingNudgeService`, not the views.
```
// TrainingNudgeService
private static func resolvedBaseline() -> NudgeBaseline {
    GoalBaseline(plan: WeeklyPlanService.shared.currentPlan())   // fallback defaulted
}

static func nudgeForLaunch(
    workouts: [Workout],
    baseline: NudgeBaseline = resolvedBaseline(),   // <- changed default-arg only
    now: Date = Date()
) -> UnderTrainedMuscle? { ... existing gating unchanged ... }
```
`GoalBaseline` is **self-falling-back**: when `plan == nil` (or the plan has no usable focus
signal), `underTrainedMuscle` delegates verbatim to `fallback.underTrainedMuscle(...)`. So with no
plan the behavior is identical to Phase 2, and `MainTabView`'s existing call site (passing no
baseline) automatically gets goal-or-adaptive. Tests can still inject an explicit baseline.

## GoalBaseline firing logic (concrete acceptance criterion)

`GoalBaseline.underTrainedMuscle(workouts:now:)` resolves in this order:

1. **No plan / no focus → adaptive.** If `plan == nil` OR `plan.focusMuscles.isEmpty`, return
   `fallback.underTrainedMuscle(workouts: workouts, now: now)` and stop. (Session-count-only plans
   still nudge via the adaptive personal-pattern logic; the planner adds focus directionality, not a
   regression.)
2. **Week framing.** Use `WorkoutInsights.userCalendar()` for `weekStart`; compute `daysElapsed`
   (clamped 1...7) and `weekFraction = daysElapsed / 7.0` exactly as `AdaptiveBaseline` does.
   - **Condition (c) — late enough in week:** if `weekFraction < Self.minWeekFraction`, return nil
     (no early-week firing; respects `weekStartDay`).
3. **Plan-derived expected pace per focus muscle.** The plan implies a per-session muscle dose. For
   each focus muscle:
   - `expectedWeeklySets = Self.setsPerSessionPerMuscle * Double(plan.targetSessions)`
   - `expectedByNow = expectedWeeklySets * weekFraction`
   - `actual = Double(WorkoutInsights.setsPerMuscleGroup(workouts:since: weekStart)[muscle, default: 0])`
   This is the proportional-pacing shape reused from `AdaptiveBaseline`, but **driven by the PLAN's
   targets**, not the trailing-4-week history.
4. **Condition (a) — genuine deficit vs plan:** keep a focus muscle as a candidate only when
   `actual < Self.deficitFraction * expectedByNow`.
5. **Most-behind selection:** among candidates, pick the smallest `actual / expectedByNow` ratio
   (ties broken by larger `expectedByNow`, then `MuscleGroup.allCases` order — identical tiebreak
   shape to `AdaptiveBaseline`). Surface exactly that one muscle.
6. **Empty candidates → adaptive.** If no focus muscle is behind plan pace, return
   `fallback.underTrainedMuscle(...)` (so a user on-pace with their focus still gets the gentle
   adaptive nudge for some other genuinely-neglected muscle — no worse than Phase 2).
7. **Goal-directive copy.** A firing focus-muscle nudge uses plan-aware copy, e.g.
   `"\(muscle.displayName) is behind your weekly plan"`, distinct from the adaptive
   "You usually hit … by now this week" reason. (The toast in `MainTabView` renders only the muscle;
   `reason` is for future surfaces/tests.)

**Named constants on `GoalBaseline` (single source of truth):**
```
static let setsPerSessionPerMuscle: Double = 4.0   // assumed working-set dose per focus muscle per session
static let deficitFraction: Double = 0.5           // mirror AdaptiveBaseline: < 50% of expected-by-now fires
static let minWeekFraction: Double = 0.4           // mirror AdaptiveBaseline: no early-week firing
```
These mirror `AdaptiveBaseline`'s names/values for consistency; `setsPerSessionPerMuscle` is the one
genuinely new dial and is documented as the tunable lever. Note: `GoalBaseline` deliberately does
NOT apply `minWeeklyBaselineSets` (that floor is a personal-history concept; the plan is the user's
explicit intent, so a focus muscle is "expected" even with no trailing history).

## UI: location + how it's reached
- **Entry point:** Settings → **Training** section. Add a `NavigationLink` row labeled "Weekly Plan"
  (SF Symbol `calendar.badge.clock` or `target`), with a trailing summary computed from
  `WeeklyPlanService.shared.currentPlan()` — e.g. `"4× · Legs, Pull"` or `"Not set"` (mirror the
  existing `fitnessGoalsSummary` trailing-label pattern at `SettingsView.swift:58`).
- **`WeeklyPlanView`:** a `List`/`Form`-style screen (match `SettingsView` `Theme` styling) with:
  - A `Stepper` for `targetSessions` (range 1...14, default 4).
  - Region multi-select: four toggleable chips (`TrainingRegion.allCases`, using `.displayName` /
    `.icon`) backing `focusRegions`.
  - **Save** (writes via the view model → `WeeklyPlanService.save`) and **Clear plan** (calls
    `clear()`; reverts the nudge to adaptive).
- **MVVM:** `WeeklyPlanView` holds only view state and binds to `WeeklyPlanViewModel`
  (`@MainActor @Observable`). The view never touches `WeeklyPlanService` or `UserDefaults` directly.

## Implementation Steps
1. **Create `Xomfit/Models/WeeklyPlan.swift`** — `WeeklyPlan` struct per the shape above
   (`Codable, Equatable`, `targetSessions`, `focusRegions: [TrainingRegion]`, computed `focusMuscles`
   with dedup). `TrainingRegion` is already `Codable`? Verify: it's `String`-raw `CaseIterable` in
   `WorkoutInsights.swift` but does NOT currently declare `Codable`. **Add `Codable` conformance to
   `TrainingRegion`** (it's a `String` raw enum, so the conformance is synthesized for free) in
   `WorkoutInsights.swift` so `WeeklyPlan` encodes. This is the only edit to Seam-3.
2. **Create `Xomfit/Services/WeeklyPlanService.swift`** — `@MainActor final class`, `static let
   shared`, `currentPlan()` / `save(_:)` / `clear()` / `resetForTesting()` over key
   `"xomfit.weeklyPlan"`, JSON-encoded. Mirror `TemplateService` private init + encode/decode.
3. **Modify `Xomfit/Models/NudgeBaseline.swift`** — append `GoalBaseline: NudgeBaseline` with the
   three named constants and the 7-step firing logic. Reuse the `AdaptiveBaseline` week-framing math
   and the candidate min-tiebreak. Delegate to `fallback` in the no-plan / no-focus / no-candidate
   branches. Keep it a pure `struct` (no `UserDefaults` reads — the plan is injected via `init`).
4. **Modify `Xomfit/Services/TrainingNudgeService.swift`** — add
   `private static func resolvedBaseline() -> NudgeBaseline { GoalBaseline(plan: WeeklyPlanService.shared.currentPlan()) }`
   and change the `nudgeForLaunch` default-arg from `AdaptiveBaseline()` to `resolvedBaseline()`.
   Gating logic, key, and `resetForTesting` unchanged. (`resolvedBaseline` is `@MainActor`-safe;
   `WeeklyPlanService.shared` is `@MainActor`, matching the enum's `@MainActor` annotation.)
5. **Create `Xomfit/ViewModels/WeeklyPlanViewModel.swift`** — `@MainActor @Observable final class`;
   loads `WeeklyPlanService.shared.currentPlan()` into editable `targetSessions` + `focusRegions`
   (defaults 4 / `[]` when nil); `var hasPlan: Bool`; `func toggle(_ region:)`; `func save()` (builds
   a `WeeklyPlan`, calls `WeeklyPlanService.shared.save`); `func clearPlan()` (calls `clear()` + resets
   local state). No view logic.
6. **Create `Xomfit/Views/Profile/WeeklyPlanView.swift`** — the stepper + region chips + Save/Clear
   screen bound to `WeeklyPlanViewModel`, styled with `Theme` like `SettingsView`. Add VoiceOver
   labels and 44pt targets per `ios.md`.
7. **Modify `Xomfit/Views/Profile/SettingsView.swift`** — add a "Weekly Plan" `NavigationLink` to
   `trainingSection` (above or below "Fitness Goals"), with a `weeklyPlanSummary` computed trailing
   label mirroring `fitnessGoalsSummary`.
8. **Create `XomFitTests/GoalBaselineTests.swift`** — deterministic tests (below). Place the file in
   the on-disk `XomFitTests/` dir alongside `TrainingNudgeTests.swift`.
9. **Register the test file in the `XomfitTests` target** — the target uses explicit file refs, so a
   new file won't compile/run until added. Run from repo root:
   ```bash
   ruby -e "require 'xcodeproj'; p=Xcodeproj::Project.open('Xomfit.xcodeproj'); t=p.targets.find{|x|x.name=='XomfitTests'}; g=p.main_group['XomfitTests']; ref=g.new_reference('GoalBaselineTests.swift'); t.source_build_phase.add_file_reference(ref); p.save"
   ```
   (The `XomfitTests` group has `path = XomfitTests`; the existing `TrainingNudgeTests.swift` ref uses
   a bare filename `sourceTree = "<group>"`, resolving to the on-disk `XomFitTests/` dir on
   case-insensitive macOS. Use the same bare-filename form. After running, verify the ref exists in
   `project.pbxproj` and the path resolves to the real file.)
10. **Run the suite** — `xcodebuild test -scheme Xomfit -destination 'platform=iOS Simulator,name=iPhone 16'`.
    Confirm 152 prior tests still pass and the new `GoalBaselineTests` run (152 + N, 0 failures).

## Unit-test plan (`XomFitTests/GoalBaselineTests.swift`)
Reuse the fixture style from `TrainingNudgeTests.swift` (synthetic single-muscle exercises/workouts,
`midWeekNow()`, pinned `weekStartDay = 0`, `WeeklyPlanService.resetForTesting()` in setUp/tearDown).
All tests inject an explicit `GoalBaseline(plan:)` + workouts + fixed `now` — no real clock, no
shared persistence dependence.

- **`testFiresWhenFocusMuscleBehindPlan`** — plan `targetSessions: 4`, `focusRegions: [.legs]`; zero
  leg sets this week, `now` mid-week. Expect `result?.muscle` ∈ legs muscles (most-behind).
- **`testDoesNotFireWhenFocusMuscleOnPace`** — same plan; log enough leg sets this week to clear
  `deficitFraction * expectedByNow`. Expect the focus path yields no candidate; with no other signal,
  result is nil (or adaptive-driven — assert it does NOT surface a leg muscle as a plan deficit).
- **`testEarlyWeekSuppressed`** — Sunday `now` (`weekFraction < minWeekFraction`); focus deficit
  present. Expect nil.
- **`testPicksMostBehindFocusMuscle`** — `focusRegions: [.legs, .pull]`; partial pull sets, zero leg
  sets. Expect a leg muscle (smaller ratio) over a pull muscle.
- **`testNoPlanFallsBackToAdaptive`** — `GoalBaseline(plan: nil, fallback: AdaptiveBaseline())` with
  a chest trailing-4-week baseline + zero chest this week (the exact `AdaptiveBaseline` "genuine
  deficit" fixture). Assert result equals `AdaptiveBaseline().underTrainedMuscle(...)` for the same
  inputs — the byte-for-byte fallback equivalence guard.
- **`testEmptyFocusFallsBackToAdaptive`** — plan with `focusRegions: []` + the same adaptive fixture;
  assert result equals the adaptive result (session-count-only plan = adaptive behavior).
- **`testNoFocusDeficitFallsBackToAdaptive`** — focus muscles all on-pace, but a DIFFERENT muscle is
  in genuine adaptive deficit; assert the result is the adaptive muscle (step 6 fallback).
- **`testGoalBaselineIsPure`** — calling `underTrainedMuscle` does not write `xomfit.nudge.lastNudgeDay`
  or `xomfit.weeklyPlan` (baseline is pure; gating/persistence live elsewhere).
- *(Optional)* **`testServiceUsesGoalBaselineWhenPlanSaved`** — `@MainActor`: save a focus plan via
  `WeeklyPlanService.shared`, call `TrainingNudgeService.nudgeForLaunch(workouts:now:)` (default
  baseline), assert it surfaces the focus deficit, proving `resolvedBaseline()` wiring. Reset both
  services in tearDown.

## Acceptance Criteria
- [ ] User can set/edit a weekly goal (target sessions + focus regions) from Settings → Training that
      persists locally across launches; "Clear plan" removes it.
- [ ] With a plan set and a focus muscle behind plan pace, the nudge surfaces that single
      `MuscleGroup` with goal-directive copy.
- [ ] With no plan (or empty focus, or no focus deficit), the nudge behaves exactly as Phase 2
      (adaptive) — verified by the fallback-equivalence test.
- [ ] No changes to `MainTabView` or `TrainingNudgeService`'s decision flow beyond the default-arg
      baseline resolution; the `GeneratorPreseed` hop is unchanged.
- [ ] `GoalBaseline` firing logic matches the 7-step spec with the three named constants; it is a
      pure struct and writes no persistence.
- [ ] `WeeklyPlanService` mirrors `TemplateService` (UserDefaults JSON, graceful nil on corrupt data).
- [ ] MVVM honored: `WeeklyPlanView` touches only the view model; the service is the only persistence owner.
- [ ] `GoalBaselineTests.swift` is registered in the `XomfitTests` target via the xcodeproj gem and runs.
- [ ] Test suite: 152 prior tests still pass + new `GoalBaseline` tests, 0 failures.

## Out of Scope
- Changing the Seam 1 protocol surface or the Phase 2 toast / `MainTabView` decision flow.
- Backend / REST / Supabase persistence — `WeeklyPlan` is local-only.
- Generator pre-seed *from the plan's focus* as a new UI affordance (the nudge → generator hop
  already carries the single muscle; a dedicated "generate from plan" button is a future polish).
- Home widgets / weekly recap / progress-vs-plan dashboards.
- Per-muscle (rather than per-region) focus selection in the UI — regions only in v1.

## Risks / Tradeoffs
- **`setsPerSessionPerMuscle` calibration:** 4.0 is an assumption. Too high → over-fires focus
  nudges; too low → never fires. Mitigation: single named constant, unit-tested at known
  `weekFraction`; tunable in one place. *Accepted tradeoff for v1.*
- **Fallback equivalence regression:** the no-plan path must equal Phase 2 exactly. Mitigation: the
  dedicated `testNoPlanFallsBackToAdaptive` equivalence test compares against a live
  `AdaptiveBaseline()` call for identical inputs.
- **`TrainingRegion` Codable addition:** adding `Codable` to a shared Seam-3 type is a one-line,
  synthesized, additive change (String raw enum) — no behavior change for existing consumers. Verify
  it compiles cleanly across the generator's existing `TrainingRegion` usage.
- **Test-target case mismatch:** group `path = XomfitTests` vs on-disk `XomFitTests/`. Mitigation:
  use the same bare-filename ref form as `TrainingNudgeTests.swift`; verify the ref resolves and the
  test actually executes (don't assume registration succeeded — read the build output).

## Open Questions
- [ ] Goal-directive copy wording — `"X is behind your weekly plan"` vs `"1 more session to hit your
      goal"`. The epic's summary used the session-count phrasing; this plan nudges at muscle
      granularity, so muscle-centric copy is proposed. Confirm during execution (low risk — `reason`
      string only, not load-bearing for the toast which renders the muscle name).
- [ ] Should a session-count-only plan (no focus) eventually drive a count-based "1 more session"
      nudge instead of deferring to adaptive? Deferred — v1 treats empty focus as adaptive.

## Skills / Agents to Use
- **`ios-standards` skill** — Swift 6 / SwiftUI / iOS 17, `@Observable`, strict concurrency, MVVM,
  accessibility (Dynamic Type, VoiceOver, 44pt targets) for `WeeklyPlanView`.
- **MVVM discipline (project rule)** — `GoalBaseline` is pure model logic; persistence flows through
  `WeeklyPlanService`; the view binds only to `WeeklyPlanViewModel`.
- **xcodeproj gem (v1.27)** — register the new test file in the `XomfitTests` target (Step 9).
- **`/end-session`** — capture the `setsPerSessionPerMuscle` tuning value and the
  GoalBaseline-selection wiring into session memory after execution.
