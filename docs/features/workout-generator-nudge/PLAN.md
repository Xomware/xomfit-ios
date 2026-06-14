# Plan: Workout Generator System — Phase 2: Toast Nudge

**Epic**: workout-generator
**Sub-feature ID**: P2 (Phase 2 — TOAST / nudge)
**Status**: Ready
**Created**: 2026-06-14
**Last updated**: 2026-06-14
**Depends on**: P1 (workout-generator-core) — hard dependency; deep-links into the Phase-1 generator
and consumes Seam 2 introduced there.

> Parent epic: `docs/features/workout-generator/PLAN.md`. This sub-plan implements
> **Phase 2 — TOAST (nudge)** only. The epic's **Shared Seams** section is the source of
> truth; this plan **references** the contracts, never redefines them.

## Summary
Once per day, after the streak/PR badge check returns nil, surface a dismissible toast flagging the
**single specific `MuscleGroup`** the user is most under-training this week *relative to their own
trailing-4-week pattern*. Tapping it opens the Phase-1 generator pre-seeded with that one
`MuscleGroup`. Adaptive (zero-config) baseline, body-part granular (one of 13), not region/split
level. Success = a genuinely neglected muscle gets a gentle, non-nagging nudge at most once per day,
and the nudge never competes with the existing streak/PR celebration.

## Approach
Mirror the existing `BadgeToastService` seam shape exactly, but as a **sibling** service
(`TrainingNudgeService`) so the once-per-launch badge path is untouched. The nudge decision is a
pure-ish `@MainActor enum` that takes workouts + an injected `NudgeBaseline` (Seam 1, default
`AdaptiveBaseline`) + an injectable `now: Date`, applies the once-per-day gate via a new
`lastNudgeDay` UserDefaults key, and returns an optional `UnderTrainedMuscle`. `MainTabView`'s
existing launch `.task` (line 179) chains it **after** `BadgeToastService.badgeForLaunch` returns
nil — badge always wins that launch.

The load-bearing core is the `AdaptiveBaseline` firing condition: **proportional pacing** against
each muscle's own trailing-4-week weekly average, pro-rated by how far into the week we are. This is
the must-get-right part (13-group nag risk) and is fully unit-tested with injected workouts + a
pinned `now`.

**Deep-link vs state flip (open question resolved):** the generator sheet (`showGenerator` +
`generatorViewModel`) is owned by `WorkoutView`, but `MainTabView` owns `destination`. The
xomfit:// routes in `XomfitApp.swift` are for *external* entry; an in-process tap doesn't need a URL
round-trip. **Decision: in-process shared-state flip.** Introduce a tiny `@Observable`
`GeneratorPreseed` holder injected into the environment from `XomFitApp`. The nudge tap sets
`preseed.pending = muscle` and flips `MainTabView.destination = .workout`; `WorkoutView` observes
`preseed.pending`, calls `generatorViewModel.preseed(muscle:)` + `showGenerator = true`, then clears
it. The `xomfit://generate?muscle=` route is **deferred** (noted in Out of Scope) — not needed for
the in-app nudge and adds URL-parsing surface for no Phase-2 benefit.

## Shared Seams — OWNS vs CONSUMES (see epic for canonical definitions)

| Seam | Definition lives in | This phase |
|------|---------------------|------------|
| **Seam 1 — `NudgeBaseline` protocol** | Epic §Shared Seams | **OWNS / introduces** — protocol + `AdaptiveBaseline` impl + `UnderTrainedMuscle` value |
| **Seam 2 — `WorkoutInsights.setsPerMuscleGroup(...)`** | `Xomfit/Utils/WorkoutInsights.swift` (already shipped P1) | **CONSUMES** — both the unwindowed and `since:` variants |
| **Seam 3 — region rollup** | `Xomfit/Utils/WorkoutInsights.swift` | **NOT used** — nudge is body-part granular |

Phase 3 adds `GoalBaseline` as a second `NudgeBaseline` conformer; the protocol must stay clean and
injectable so neither `TrainingNudgeService` nor `MainTabView` change in Phase 3.

## Affected Files / Components
| File / Component | Change | Why |
|-----------------|--------|-----|
| `Xomfit/Models/NudgeBaseline.swift` | **create** | Seam 1: `NudgeBaseline` protocol + `UnderTrainedMuscle` value + `AdaptiveBaseline` impl + named tuning constants |
| `Xomfit/Services/TrainingNudgeService.swift` | **create** | `@MainActor enum`; once-per-day gate via `lastNudgeDay`; suppression rules; returns `UnderTrainedMuscle?` |
| `Xomfit/Services/GeneratorPreseed.swift` | **create** | Tiny `@MainActor @Observable` holder for the in-process nudge → generator hop |
| `Xomfit/XomfitApp.swift` | **modify** | Instantiate `GeneratorPreseed`, inject via `.environment` into `MainTabView` |
| `Xomfit/Views/MainTabView.swift` | **modify** | Extend launch `.task` (line 179): after badge nil, call `TrainingNudgeService`; toast action sets preseed + flips destination |
| `Xomfit/Views/Workout/WorkoutView.swift` | **modify** | Observe `GeneratorPreseed.pending`; open generator pre-seeded; clear pending |
| `XomFitTests/TrainingNudgeTests.swift` | **create + register** | Deterministic firing-condition + gate/suppression tests (must be added to `XomFitTests` target in `project.pbxproj`) |
| `Xomfit/Services/BadgeToastService.swift` | read-only | Pattern reference (lastSeen keys, `@MainActor enum`, `resetForTesting`) — not modified |
| `Xomfit/Utils/WorkoutInsights.swift` | read-only | Seam 2 + `userCalendar()` — consumed, not modified |
| `Xomfit/ViewModels/WorkoutGeneratorViewModel.swift` | read-only | `preseed(muscle:)` hook already exists (line 79) |

## Seam 1 — Pinned Protocol Surface (`NudgeBaseline.swift`)

```swift
/// The single muscle the nudge will surface, plus user-facing copy.
struct UnderTrainedMuscle: Equatable {
    let muscle: MuscleGroup
    let reason: String   // e.g. "You usually hit chest by now this week"
}

/// Strategy the training nudge consumes to decide "what counts as under-trained."
/// Phase 2 ships `AdaptiveBaseline`; Phase 3 adds `GoalBaseline`. Injectable so the
/// service/MainTabView never change when the strategy changes.
protocol NudgeBaseline {
    /// Returns the single most-behind muscle, or nil if nothing should be nudged.
    /// `now` is injected (NOT `Date()` internally) so the decision is deterministically testable.
    func underTrainedMuscle(workouts: [Workout], now: Date) -> UnderTrainedMuscle?
}

struct AdaptiveBaseline: NudgeBaseline {
    // Named, single-source tuning constants (see firing condition below).
    static let trailingWeeks: Int = 4
    static let minWeeklyBaselineSets: Double = 2.0   // < this avg/week ⇒ muscle skipped (never/barely trained)
    static let deficitFraction: Double = 0.5         // fire only if actual < 0.5 * expectedByNow
    static let minWeekFraction: Double = 0.4         // require ≥40% of the week elapsed before firing

    func underTrainedMuscle(workouts: [Workout], now: Date) -> UnderTrainedMuscle? { /* ... */ }
}
```

`TrainingNudgeService` surface:

```swift
@MainActor
enum TrainingNudgeService {
    private static let lastNudgeDayKey = "xomfit.nudge.lastNudgeDay"

    /// Once-per-day gated nudge decision. Default baseline is AdaptiveBaseline.
    /// `now` injectable for tests; commits `lastNudgeDay` when it returns non-nil.
    static func nudgeForLaunch(
        workouts: [Workout],
        baseline: NudgeBaseline = AdaptiveBaseline(),
        now: Date = Date()
    ) -> UnderTrainedMuscle?

    static func resetForTesting()   // clears lastNudgeDay, mirrors BadgeToastService
}
```

## AdaptiveBaseline Firing Condition (LOAD-BEARING — proportional pacing)

Computed with `WorkoutInsights.userCalendar()` so `weekStartDay` is respected. `now` is injected.

Let `cal = userCalendar()`, `weekStart = cal.dateInterval(of: .weekOfYear, for: now)!.start`,
`daysElapsed = cal.dateComponents([.day], from: weekStart, to: now).day! + 1` (clamped 1...7),
`weekFraction = Double(daysElapsed) / 7.0`.

Trailing baseline window start: `windowStart = cal.date(byAdding: .day, value: -7 * trailingWeeks, to: weekStart)!`
(the 4 full weeks **before** the current week — current week excluded from the baseline).

For **each** `MuscleGroup`:
1. `baselineSets = WorkoutInsights.setsPerMuscleGroup(workouts:, since: windowStart)[muscle]` over the
   pre-current-week window, ending at `weekStart`. `avgWeekly = baselineSets / Double(trailingWeeks)`.
2. **Skip** if `avgWeekly < minWeeklyBaselineSets` (condition **b** — never/barely-trained muscles
   cannot nag).
3. `expectedByNow = avgWeekly * weekFraction`.
4. `actualThisWeek = setsPerMuscleGroup(workouts:, since: weekStart)[muscle]` (default 0).
5. Muscle is a **candidate** iff `Double(actualThisWeek) < deficitFraction * expectedByNow`
   (condition **a** — genuine personal deficit vs the muscle's OWN by-now pace, not a flat
   cross-muscle average).
6. `ratio = expectedByNow == 0 ? 0 : Double(actualThisWeek) / expectedByNow` (smaller = more behind).

Then, gating condition **c** (early-week suppression): if `weekFraction < minWeekFraction`, return
nil regardless of candidates (not enough of the week has elapsed for an absence to be meaningful).

Among all candidates, surface the **single** one with the **smallest `ratio`** (largest relative
deficit); ties broken by larger `expectedByNow`, then by `MuscleGroup.allCases` order for
determinism. Return `UnderTrainedMuscle(muscle:, reason:)`; nil if no candidates.

**Acceptance criterion (concrete):** Given a fixed `now` mid-week and injected workouts where chest
has a 12-set/4-week baseline (avg 3.0/wk) and 0 chest sets this week at `weekFraction = 0.57`
(`expectedByNow ≈ 1.71`, `actual 0 < 0.5*1.71`), AND biceps has only 4 sets across 4 weeks (avg
1.0/wk < 2.0 floor), the baseline returns `chest` (biceps skipped by the floor) and never a list.

## Toast Precedence & Once-Per-Day Gating
- **Precedence:** in `MainTabView`'s launch `.task`, `BadgeToastService.badgeForLaunch` is called
  first. If it returns a badge, show it and **return** — the nudge is not evaluated this launch
  (streak/PR always wins; one toast per launch).
- **Once-per-day gate (in `TrainingNudgeService`):** read `lastNudgeDay` (a `Date?`). If
  `userCalendar().isDate(lastNudgeDay, inSameDayAs: now)` is true, return nil immediately. When a
  nudge IS surfaced, write `cal.startOfDay(for: now)` to `lastNudgeDay`. Tapping/deep-linking does
  not re-fire because the day is already committed on first surface.
- **Suppression rules (all in `TrainingNudgeService`, before invoking the baseline):**
  - Workout logged today → suppress (`workouts` contains one with `startOfDay == startOfDay(now)`).
  - Cold start → suppress if total workouts `< minWorkoutsForNudge` (named constant, e.g. 8).
  - Early-week / no-signal → delegated to the baseline (`minWeekFraction`, `minWeeklyBaselineSets`).
- **Toast style/copy:** `Toast(style: .info, message: "<emoji> Light on \(muscle.displayName) this week — generate a quick session?")`. Distinct `.info` style separates it from the badge's `.success`.

## Implementation Steps
- [ ] 1. **Create `Xomfit/Models/NudgeBaseline.swift`** — `UnderTrainedMuscle` struct, `NudgeBaseline`
      protocol (with injectable `now`), `AdaptiveBaseline` struct with the four named constants and
      the proportional-pacing logic above. Pure value types, no service calls. Consumes Seam 2 +
      `WorkoutInsights.userCalendar()`.
- [ ] 2. **Create `Xomfit/Services/TrainingNudgeService.swift`** — `@MainActor enum` mirroring
      `BadgeToastService`: `lastNudgeDay` key, `nudgeForLaunch(workouts:baseline:now:)`, suppression
      rules (workout-today, cold-start), once-per-day gate, `minWorkoutsForNudge` constant,
      `resetForTesting()`. Delegates the firing decision to the injected `NudgeBaseline`.
- [ ] 3. **Create `Xomfit/Services/GeneratorPreseed.swift`** — `@MainActor @Observable final class
      GeneratorPreseed { var pending: MuscleGroup? }`. The shared in-process channel for the
      nudge → generator hop.
- [ ] 4. **Modify `Xomfit/XomfitApp.swift`** — add `@State private var generatorPreseed = GeneratorPreseed()`;
      inject `.environment(generatorPreseed)` onto `MainTabView()` alongside the existing
      `authService`/`workoutSession` environments.
- [ ] 5. **Modify `Xomfit/Views/MainTabView.swift`** — read `@Environment(GeneratorPreseed.self)`.
      Extend the existing launch `.task` (line 179): after the `if let badge = ...` block (which
      already `return`s implicitly by being the only branch), add an `else` path — if no badge, call
      `TrainingNudgeService.nudgeForLaunch(workouts:)`; if it returns a muscle, sleep ~1s then set
      `launchBadgeToast = Toast(style: .info, message: ...)`. Store the nudged muscle in `@State`.
      Wire the toast tap: because `ToastView` auto-dismisses and taps just clear it, add an explicit
      tap path — set `generatorPreseed.pending = muscle` and `select(destination: .workout)` when the
      nudge toast is tapped. (Add a lightweight nudge-specific toast tap; see step 5a.)
- [ ] 5a. **Toast tap wiring** — the shared `.toast()` modifier dismisses on tap but has no action
      hook. Track the pending nudge muscle in `MainTabView` `@State`; present the nudge via the same
      `launchBadgeToast` binding but gate the destination flip on a separate `@State nudgeMuscle:
      MuscleGroup?` that is set when the nudge is shown and consumed on toast tap. Simplest concrete
      approach: add an `onTap` closure parameter to `ToastModifier`/`.toast()` (default no-op) so the
      nudge can flip destination + set `generatorPreseed.pending`; badge toasts pass no closure.
      (This is a small, backward-compatible addition to `Views/Common/ToastView.swift` — note it as a
      touched file.)
- [ ] 6. **Modify `Xomfit/Views/Workout/WorkoutView.swift`** — read `@Environment(GeneratorPreseed.self)`.
      Add `.onChange(of: generatorPreseed.pending)` (and an initial `.task` check) — when non-nil:
      `generatorViewModel.reset(); generatorViewModel.preseed(muscle: pending); showGenerator = true;
      generatorPreseed.pending = nil`. Reuses the existing `showGenerator` sheet + `generatorViewModel`.
- [ ] 7. **Create `XomFitTests/TrainingNudgeTests.swift`** — deterministic unit tests (see Test Plan).
      Use injected `[Workout]` fixtures + a pinned `now`. Call `resetForTesting()` in `setUp`.
- [ ] 8. **Register the new test file in the `XomFitTests` target.** The test target uses explicit
      `PBXFileReference` entries (NOT a synchronized group — verified: `project.pbxproj` lists each
      test file individually, e.g. `PRCalculatorTests.swift`, `WatchConnectivityManagerTests.swift`).
      The executor MUST add `TrainingNudgeTests.swift` to the `XomFitTests` target via the `xcodeproj`
      Ruby gem (or Xcode), or it will not compile/run. Example:
      ```ruby
      require 'xcodeproj'
      project = Xcodeproj::Project.open('Xomfit.xcodeproj')
      group = project.main_group.find_subpath('XomFitTests', true)
      file_ref = group.new_file('XomFitTests/TrainingNudgeTests.swift')
      test_target = project.targets.find { |t| t.name == 'XomFitTests' }
      test_target.add_file_references([file_ref])
      project.save
      ```
- [ ] 9. **Build + test** — `xcodebuild test -scheme Xomfit -destination 'platform=iOS Simulator,name=iPhone 16'`.
- [ ] 10. **Manual smoke** — Debug bypass build (`XOMFIT_AUTH_BYPASS=1`); confirm the badge path still
      wins when a streak fires, and that the nudge toast (mock fixtures) deep-links into the generator
      pre-seeded with the muscle. Optionally add a `XOMFIT_FORCE_NUDGE` debug env to surface it
      deterministically (not required).

## Test Plan (`TrainingNudgeTests.swift`, `XomFitTests` target)
All tests inject `[Workout]` fixtures + a fixed `now`; baseline/service take `now` explicitly so no
real-clock dependence. `resetForTesting()` in `setUp` clears `lastNudgeDay`.

- **Firing — genuine deficit fires:** established 4-week chest baseline, 0 chest this week, mid-week
  → returns `chest`.
- **Firing — flat-average false positive does NOT fire:** muscle below the cross-muscle average but
  *on pace vs its own baseline* (actual ≥ 0.5 * expectedByNow) → nil. (Guards against "below
  average" naive logic.)
- **Skip never-trained:** muscle with avg < `minWeeklyBaselineSets` → never surfaced even at 0 sets.
- **Early-week suppression:** same deficit but `weekFraction < minWeekFraction` → nil.
- **Single-most-behind selection:** two qualifying muscles → the one with the smaller actual/expected
  ratio is returned; result is a single `UnderTrainedMuscle`, never a list.
- **Once-per-day gate:** first call returns a muscle and commits `lastNudgeDay`; second call same
  `now` → nil; call with `now` advanced one day → fires again.
- **Workout-logged-today suppression:** a workout dated `startOfDay(now)` → nil.
- **Cold-start suppression:** total workouts < `minWorkoutsForNudge` → nil.
- **Zero-session week / empty history:** no workouts → nil (no crash).
- **Week-boundary / weekStartDay:** set `weekStartDay` to Monday vs Sunday and assert `weekStart`
  and the resulting deficit differ as expected (pin the UserDefaults key in the test).
- **`AdaptiveBaseline` purity:** calling `underTrainedMuscle` does not touch `lastNudgeDay`
  (gate lives only in the service).

## Acceptance Criteria (testable)
- [ ] New nudge branch in `MainTabView` launch task, after streak/PR, gated once-per-day via `lastNudgeDay`.
- [ ] Detection uses Seam 2 sets-per-`MuscleGroup` (both variants); never volume; never Seam 3.
- [ ] Baseline injected as `NudgeBaseline` (Seam 1); default `AdaptiveBaseline`; returns a single
      `UnderTrainedMuscle` or nil.
- [ ] Proportional-pacing firing condition (a genuine deficit vs own by-now pace, b established
      baseline ≥ floor, c ≥ `minWeekFraction` of week elapsed) honored; surfaces single most-behind.
- [ ] All four tuning constants are named statics on `AdaptiveBaseline`, tunable in one place.
- [ ] Toast precedence: badge wins the launch; nudge only evaluated when badge is nil.
- [ ] Tapping the nudge opens the Phase-1 generator pre-seeded with the single `MuscleGroup` via the
      `GeneratorPreseed` state flip; tapping/dismissing does not re-fire same day.
- [ ] Anti-nag: once/day, dismissible, respects `weekStartDay`, suppressed early-week / cold-start /
      workout-logged-today, yields to streak/PR.
- [ ] All Test Plan cases pass; `TrainingNudgeTests.swift` is registered in the `XomFitTests` target.
- [ ] `ProgressViewModel` chart and the existing badge toast behavior are unchanged.

## Out of Scope
- Phase 3 (planner): no `WeeklyPlan`, no `GoalBaseline`.
- Region-level nudging (body-part granular only).
- Modifying `BadgeToastService` (pattern reference only).
- `xomfit://generate?muscle=` external deep-link route — deferred; the in-process state flip covers
  the Phase-2 nudge. Revisit if an external/notification entry point is needed.
- Adapting the trailing window below 4 weeks for short-history users — cold-start suppression covers
  this for v1 (the < 4-week user simply won't be nudged until they have a baseline).

## Risks / Tradeoffs
- **Nag risk (primary):** 13 groups means something usually looks behind. Mitigated by proportional
  pacing vs each muscle's OWN baseline + the 2-set floor + 0.5 deficit fraction + min-week-elapsed,
  surfacing exactly one muscle, once/day, dismissible, yielding to badge. The four constants are
  centralized for one-place retuning, and the firing logic is the most-tested unit.
- **Toast tap has no action hook today:** the shared `.toast()` modifier only dismisses on tap. Adding
  an optional `onTap` closure (step 5a) is a small, backward-compatible change; badge toasts keep the
  default no-op so existing behavior is unchanged.
- **Cross-view hop (MainTabView owns destination, WorkoutView owns the sheet):** the `GeneratorPreseed`
  environment holder is the seam; risk is a race where `WorkoutView` mounts after the flip. Mitigated
  by checking `pending` both in `.onChange` and an initial `.task` on `WorkoutView`.
- **Window/boundary math:** off-by-one on `daysElapsed` / `weekStart` skews `expectedByNow`. Mitigated
  by injectable `now` + explicit week-boundary + weekStartDay unit tests.

## Open Questions (resolved unless noted)
- [x] Deep link vs state flip → **state flip** (`GeneratorPreseed`); xomfit route deferred.
- [x] Trailing window → **fixed 4 weeks**; short-history users covered by cold-start suppression.
- [x] Deficit metric → **proportional pacing** vs each muscle's own pro-rated weekly average.
- [ ] Final copy/emoji for the nudge toast message (cosmetic; pick during execute).
- [ ] `minWorkoutsForNudge` exact value (8 proposed) and `minWeekFraction` (0.4 proposed) — confirm
      against real history during smoke test; both are named constants so tuning is trivial.

## Skills / Agents to Use
- **`ios-standards` skill**: Swift 6 / SwiftUI / iOS 17, `@Observable`, strict concurrency, MVVM.
- **MVVM discipline**: `TrainingNudgeService` + `AdaptiveBaseline` are pure/service-level; views
  (`MainTabView`, `WorkoutView`) consume results only — no service/engine calls in views.
- **`xcodeproj` gem**: register the new test file in the `XomFitTests` target (step 8) — required or
  the test won't compile.
