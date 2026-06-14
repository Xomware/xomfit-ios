# Plan: Workout Generator System (EPIC)

**Status**: Ready
**Created**: 2026-06-14
**Last updated**: 2026-06-14

> **This is an EPIC plan.** It will be split via `/orchestrate` into three sub-feature
> plans — one per phase — each executed independently in dependency order. The
> **Shared Seams** section below defines cross-phase contracts that ALL three sub-plans
> must honor; orchestrated sub-plans must not redefine them. Do not execute this doc
> directly: flip status to `Ready` after review, then `/orchestrate`.

## Summary
A fully-local, zero-token, offline "workout generator" system for XomFit, built in three
dependency-ordered phases: (1) a constrained-random **generator** that turns body-part +
time-budget + set-count input into a runnable `WorkoutTemplate` (full-gym catalog, no equipment
filtering in v1); (2) a once-per-day **toast nudge** that detects the single under-trained
**`MuscleGroup`** (body-part level, vs the user's own pattern) and deep-links into the pre-seeded
generator; (3) an explicit weekly **planner** that supplies a goal-driven baseline to the nudge.
Success = a user can tap a dice button, get a sane personalized workout instantly with no
network/AI cost, get gently and *non-naggingly* nudged toward a genuinely neglected muscle once a
day, and (later) set an explicit weekly target.

## Approach
Per `docs/features/workout-generator/BRAINSTORM.md`, the recommendation was Option 2 (Adaptive).
This EPIC commits to the **full three-phase vision** (Option 2 + the deferred Option 3 planner),
sequenced so the nudge baseline is a **pluggable strategy from day one**. The planner is then
purely additive — it ships an alternate baseline strategy, not a retrofit of the nudge.

Everything operates on the canonical **13-case `MuscleGroup` enum** end to end. The Seam-3 region
rollup (Push/Pull/Legs/Core) is a *presentation/grouping* convenience — it powers the generator's
split quick-pick chips (a "split" tap just multi-selects its constituent muscles) and any
region-flavored copy. The **nudge operates at individual-muscle granularity** and surfaces one
specific `MuscleGroup`; it does not reason at region level.

The system is the deterministic, instant, offline **twin** of the existing AI Coach
`build_workout` tool (`AICoachService.swift:435`, payload built in `AICoachViewModel.buildTemplate(from:)`
at `AICoachViewModel.swift:392`). That tool is conversational, model-driven, costs tokens + network.
The generator is constrained-random, runs on-device, costs nothing. Both emit a `WorkoutTemplate`,
so both reuse the same Start/Save plumbing — the difference is the *entry point and framing*, not
the output type.

Nearly all infrastructure already exists. The only genuinely new logic is the constrained-random
selection algorithm and the trailing-4-week baseline comparison. Everything else is assembly:
- Output type is `WorkoutTemplate` (`Models/WorkoutTemplate.swift`) → reuse
  `WorkoutLoggerViewModel.startFromTemplate(_:userId:)` (`WorkoutLoggerViewModel.swift:317`, which
  also prefills weights from last-set history) and `TemplateService.saveCustomTemplate(_:)`
  (`TemplateService.swift:24`). No new runnable-workout abstraction.
- Toast seam already exists: `BadgeToastService.badgeForLaunch(workouts:)` (`BadgeToastService.swift:33`)
  feeds `MainTabView`'s `.task` block (`MainTabView.swift:179`) via `.toast($launchBadgeToast)`,
  using `WorkoutService.fetchWorkoutsFromCache(userId:)` (`WorkoutService.swift:331`) — no async
  fetch at launch.
- Set-frequency signal already computed correctly in `ProgressViewModel.computeMuscleGroups`
  (`ProgressViewModel.swift:164`) — counts SETS per `MuscleGroup`. Lift it into a pure shared helper.
  The volume-split in `BodyHeatmapViewModel` is explicitly the wrong tool.
- Week-start preference handled by `WorkoutInsights.userCalendar()` (`WorkoutInsights.swift:15`).

## Shared Seams (cross-phase contracts — define once, honor everywhere)

These three abstractions are the load-bearing contracts. They must be introduced exactly once
and consumed identically across phases. Orchestrated sub-plans inherit these signatures verbatim.

### Seam 1 — `NudgeBaseline` strategy protocol
The abstraction the toast nudge consumes to decide "what counts as under-trained." Introduced in
**Phase 2** with the adaptive impl; **Phase 3** adds a second impl. The toast never changes when
the strategy changes.

- **Lives in:** new `Xomfit/Models/NudgeBaseline.swift` (pure value types, no services).
- **Surface (intent, not final Swift):**
  - `protocol NudgeBaseline` with a single method that, given this-week's sets-per-`MuscleGroup`
    and the trailing history, returns an optional `UnderTrainedMuscle` — the **single specific
    `MuscleGroup`** to nudge plus a reason string. (Returns a `MuscleGroup`, NOT a region — the
    nudge is body-part granular per locked decision 3.)
  - Two concrete impls:
    - `AdaptiveBaseline` (Phase 2) — compares this week's sets-per-`MuscleGroup` against the user's
      own trailing-4-week personal pattern for each muscle; flags the single muscle most behind
      *its own established norm* (see firing condition in Phase 2 — this is load-bearing).
    - `GoalBaseline` (Phase 3) — compares the current week against an explicit `WeeklyPlan`;
      falls back to `AdaptiveBaseline` when no plan is set (the hybrid).
- **Consumed by:** `TrainingNudgeService` (Phase 2). The service picks which baseline to inject
  (default adaptive; Phase 3 makes it `GoalBaseline` wrapping adaptive).

### Seam 2 — Shared sets-per-muscle helper
One source of truth for "sets logged per `MuscleGroup`," lifted out of the private
`ProgressViewModel.computeMuscleGroups` so Progress, the generator (familiarity/coverage), and the
nudge (detection) all agree.

- **Lives in:** `Xomfit/Utils/WorkoutInsights.swift` (already the home of pure workout-derived
  helpers; matches its stated design — pure, testable, no side effects).
- **Surface (intent, not final Swift):**
  - `static func setsPerMuscleGroup(workouts: [Workout]) -> [MuscleGroup: Int]` — pure, counts
    `workoutExercise.sets.count` per `exercise.muscleGroups` entry (exactly the Progress logic).
  - `static func setsPerMuscleGroup(workouts: [Workout], since: Date) -> [MuscleGroup: Int]` —
    windowed variant for trailing-window baseline math.
- **Refactor obligation (Phase 2):** `ProgressViewModel.computeMuscleGroups` is rewritten to call
  this helper so there is exactly one implementation. Behavior must stay identical (verify the
  Progress muscle-group chart is unchanged).

### Seam 3 — `MuscleGroup` → coarse region rollup
The single mapping from the 13-case `MuscleGroup` enum onto a coarse region vocabulary. **Scope
note (locked decision 2 + 3):** this rollup is now used by the **generator's split quick-pick
presets** (tapping "Push" multi-selects its muscles) and for any region-flavored copy. The
**nudge no longer consumes it for detection** — the nudge operates at individual-`MuscleGroup`
granularity and surfaces one muscle directly (Seam 1). The reverse map is still the mechanism that
turns a split preset into a set of selected `MuscleGroup`s in the generator UI.

- **Lives in:** `Xomfit/Utils/WorkoutInsights.swift` (alongside Seam 2) — or a small dedicated
  `Xomfit/Models/TrainingRegion.swift` if it grows. Sub-plan chooses; define it ONCE.
- **Vocabulary decision (locked):** PPL + core rollup, mapping onto the existing
  `TemplateCategory` PPL vocabulary (`WorkoutTemplate.swift:27`) so generator split chips and any
  region copy match the user's mental model ("Push", "Pull", "Legs", "Core").
- **Rollup table (the 13 `MuscleGroup` cases → region):**

  | Region | `MuscleGroup` cases |
  |--------|---------------------|
  | **Push** | `chest`, `shoulders`, `triceps` |
  | **Pull** | `back`, `lats`, `biceps`, `traps`, `forearms` |
  | **Legs** | `quads`, `hamstrings`, `glutes`, `calves` |
  | **Core** | `abs` |

- **Reverse map (region → constituent `MuscleGroup`s):** inverse of the above; e.g. the generator's
  "Legs" split chip multi-selects `[.quads, .hamstrings, .glutes, .calves]`. Selecting a split chip
  is purely a multi-select shortcut — there is no separate split code path; the user can then toggle
  individual muscles on/off in the same grid.
- **Region → `TemplateCategory`:** `Push → .push`, `Pull → .pull`, `Legs → .legs`, `Core → .custom`
  (no abs-only category exists). Used when the generator labels its output template's `category`.

## Affected Files / Components (system-wide)
| File / Component | Change | Why |
|------------------|--------|-----|
| `Xomfit/Models/WorkoutTemplate.swift` | read-only (output type) | Generator emits this; reuse Start/Save |
| `Xomfit/Models/Exercise.swift` | read-only | Pool source; `category`, `muscleGroups`, 13-case `MuscleGroup` (`equipment` unused in v1) |
| `Xomfit/Models/ExerciseDatabase.swift` | read-only | `ExerciseDatabase.all` is the full-gym generator pool; `byId` for reroll |
| `Xomfit/Utils/WorkoutInsights.swift` | **modify** | Add Seam 2 helper + Seam 3 rollup |
| `Xomfit/ViewModels/ProgressViewModel.swift` | **modify** | Refactor `computeMuscleGroups` to call Seam 2 |
| `Xomfit/ViewModels/WorkoutLoggerViewModel.swift` | read-only | `startFromTemplate` = "Start now" |
| `Xomfit/Services/TemplateService.swift` | read-only | `saveCustomTemplate` = "Save as template" |
| `Xomfit/Services/WorkoutService.swift` | read-only | `fetchWorkoutsFromCache` for history/familiarity + nudge |
| `Xomfit/Services/BadgeToastService.swift` | read-only (pattern reference) | Nudge mirrors this seam, does not modify it |
| `Xomfit/Views/MainTabView.swift` | **modify** | Add nudge branch to launch `.task`; toast action seeds generator with a `MuscleGroup` |
| `Xomfit/Views/Workout/WorkoutView.swift` | **modify** | New "Generate" CTA next to Build / Log Past |
| `Xomfit/XomfitApp.swift` | **modify** (Phase 2, optional) | New `xomfit://generate?muscle=` route alongside existing |
| `Xomfit/Services/AICoachService.swift` / `AICoachViewModel.swift` | read-only | Distinction reference — generator must stay visually/conceptually separate |
| **NEW** `Xomfit/Services/WorkoutGenerator.swift` | create (P1) | Pure constrained-random algorithm (full catalog, no equipment filter) |
| **NEW** `Xomfit/ViewModels/WorkoutGeneratorViewModel.swift` | create (P1) | MVVM bridge for config/preview/reroll |
| **NEW** `Xomfit/Views/Workout/Generator/*.swift` | create (P1) | Config (split chips + muscle grid) + preview screens |
| **NEW** `Xomfit/Models/NudgeBaseline.swift` | create (P2) | Seam 1 protocol + `AdaptiveBaseline` + `UnderTrainedMuscle` |
| **NEW** `Xomfit/Services/TrainingNudgeService.swift` | create (P2) | Nudge decision, `lastNudgeDay` gate |
| **NEW** `Xomfit/Models/WeeklyPlan.swift` | create (P3) | Weekly goal model (NOT `TrainingGoal` — that name is taken by the training-style enum in `Models/TrainingGoal.swift`) |
| **NEW** `Xomfit/ViewModels/WeeklyPlanViewModel.swift` + view | create (P3) | Set/persist weekly goal |

---

## Phase 1 — GENERATOR (foundation)

**Goal:** Tap a dice CTA on the Workout tab → pick muscles (split quick-pick chips and/or the full
13-`MuscleGroup` grid) / time budget / set count → get a constrained-random `WorkoutTemplate`
preview with per-row reroll → Start Now or Save. Full-gym catalog (no equipment filtering in v1).
Fully local, instant, zero tokens. Conceptually distinct from the AI Coach.

**Depends on:** Seam 2 (sets-per-muscle helper) for familiarity bias and Seam 3 (rollup) for the
split quick-pick presets — but Phase 1 can land the seams it needs itself if it runs first.
**Recommendation:** introduce Seam 2 + Seam 3 in Phase 1 (the generator uses both); Phase 2
consumes Seam 2 and Seam 1 without redefining.

**Input model (locked decision 2 — BOTH selection modes, one underlying representation):**
- The only underlying selection state is `Set<MuscleGroup>` (the 13 cases). There is no separate
  "split" data type or split code path.
- The config UI offers **two ways to fill that set**:
  1. **Split quick-pick chips** — `Push` / `Pull` / `Legs` / `Core`. Tapping a chip multi-selects
     its constituent muscles via the Seam-3 reverse map (e.g. "Push" → `chest`, `shoulders`,
     `triceps`). Tapping again can clear them (toggle).
  2. **Full individual-muscle grid** — all 13 `MuscleGroup` chips, individually toggleable.
- The two are not exclusive: a user can tap "Push" then toggle off `triceps` and toggle on `back`.
  The generator only ever sees the resulting `Set<MuscleGroup>`.

**Equipment (locked decision 1 — assume FULL GYM for v1):**
- The generator picks from the **entire** `ExerciseDatabase.all` catalog. There is **no equipment
  filtering and no equipment UI** in v1.
- A home/dumbbell/bodyweight equipment filter is a noted **future enhancement, explicitly out of
  scope for v1** (see Out of Scope). Dropping it simplifies the constrained-random algorithm
  (pool = catalog ∩ target muscles only).

**Files to create:**
- `Xomfit/Services/WorkoutGenerator.swift` — pure `struct`/`enum`, seeded RNG, no services.
- `Xomfit/ViewModels/WorkoutGeneratorViewModel.swift` — `@MainActor @Observable`; owns config
  state (`Set<MuscleGroup>` + time + set count) + preview template; calls `WorkoutGenerator`,
  `WorkoutService.fetchWorkoutsFromCache`, `startFromTemplate`, `saveCustomTemplate`.
- `Xomfit/Views/Workout/Generator/WorkoutGeneratorConfigView.swift` — split quick-pick chips
  (Push/Pull/Legs/Core) + full 13-muscle grid + time slider + set-count stepper.
- `Xomfit/Views/Workout/Generator/WorkoutGeneratorPreviewView.swift` — exercise list, per-row
  reroll (dice) button, footer Start Now / Save.

**Files to modify:**
- `Xomfit/Views/Workout/WorkoutView.swift` — add "Generate" CTA (dice icon) presenting the config
  sheet. Visually framed as the *instant/offline* twin of the AI Coach (e.g. subtitle "Instant ·
  No AI · Offline") so the two entry points read as distinct.
- `Xomfit/Utils/WorkoutInsights.swift` — add Seam 2 + Seam 3 (if Phase 1 runs first).

**Key types / methods (intent, not final Swift):**
- `WorkoutGenerator.generate(targets: [MuscleGroup], timeBudgetMinutes: Int, targetSets: Int, familiarity: [String: Int], seed: UInt64) -> WorkoutTemplate`
  *(no `equipment` parameter — full-catalog in v1, locked decision 1.)*
- `WorkoutGenerator.reroll(slot: Int, in template: WorkoutTemplate, targets: [MuscleGroup], familiarity: [String: Int], seed: UInt64) -> WorkoutTemplate`
- Algorithm rules:
  - Pool = `ExerciseDatabase.all` filtered by target `muscleGroups` only (no equipment filter in v1).
  - **Compound-first ordering:** sort `category == .compound` before `.isolation` (then cardio/stretch excluded).
  - **Time → exercise count:** existing heuristic is ~2 min/set (`estimatedDuration ≈ sets * 2`,
    matches `WorkoutBuilderViewModel.buildTemplate` math and built-in templates ~60 min / ~30 sets);
    derive `exerciseCount ≈ timeBudget / (targetSets * 2)`.
  - **Rep schemes by `ExerciseCategory`:** `.compound` → "5" or "6-8"; `.isolation` → "10-12" or
    "12-15"; `.cardio` → time-based (excluded from strength gen for v1).
  - **Slot allocation:** distribute slots across selected groups (weighted by group size so back/legs
    get more than calves; round-robin fallback).
  - **Familiarity bias (Seam 2):** weight pool toward exercises the user has logged (frequency from
    `setsPerMuscleGroup` / logged-exercise frequency over cached workouts), with small novelty injection.
  - **Per-slot reroll:** swap one slot for another from the same group's pool, excluding what's
    already in the template. Seeded RNG → reproducible/testable.
- Output `WorkoutTemplate`: `id = UUID().uuidString`, `isCustom = true`, `category` via Seam 3
  region→`TemplateCategory` (best-fit region for the selected muscles), `estimatedDuration` from
  the time math.

**AI-coach distinction (explicit design requirement):** the generator must not look or read like a
second AI Coach. No chat UI, no "thinking" state, no network spinner. The CTA copy and the preview
header must make clear this is the *instant, free, on-device* path. The AI Coach remains the
conversational path. They share only the `WorkoutTemplate` output type and the downstream Start/Save.

**Acceptance criteria:**
- [ ] Dice CTA on `WorkoutView` opens a config sheet with split quick-pick chips
      (Push/Pull/Legs/Core) AND the full 13-muscle grid, plus time slider and set stepper.
- [ ] Tapping a split chip multi-selects exactly its Seam-3 constituent muscles; the user can then
      toggle individual muscles; the generator only consumes the resulting `Set<MuscleGroup>`.
- [ ] Generating produces a `WorkoutTemplate` honoring: target groups only, full catalog (no
      equipment filter), compound-before-isolation order, category-appropriate rep schemes,
      exercise count from time budget.
- [ ] Per-row reroll swaps only that slot, from the same muscle pool, never duplicating an existing
      exercise; same seed → same result.
- [ ] "Start Now" runs `startFromTemplate` (weights prefilled from history); "Save as Template"
      calls `saveCustomTemplate` and the template appears in the templates list.
- [ ] No network call, no token spend, no AI Coach UI anywhere in the flow.
- [ ] No equipment UI or equipment filtering exists in v1.
- [ ] Seam 2 + Seam 3 exist and are pure/tested; `ProgressViewModel` muscle chart unchanged.
- [ ] Unit tests: determinism (seeded), time→count, compound ordering, split-chip→muscle expansion,
      reroll exclusion, slot allocation.

---

## Phase 2 — TOAST (nudge)

**Goal:** Once per day, after the streak/PR badge check returns nil, surface a dismissible toast
flagging the **single specific `MuscleGroup`** the user is most under-training this week *relative
to their own established pattern*. Tapping it deep-links into the Phase-1 generator pre-seeded with
that one `MuscleGroup`. Adaptive (zero-config) baseline. Body-part granular — NOT region/split level
(locked decision 3).

**Depends on:** Phase 1 (generator entry point + config that accepts a pre-seed `MuscleGroup`).
Seam 2 (consumes — does not redefine). Introduces Seam 1. (Seam 3 is NOT used by the nudge.)

**Files to create:**
- `Xomfit/Models/NudgeBaseline.swift` — Seam 1 protocol + `AdaptiveBaseline` impl + `UnderTrainedMuscle` value
  (`{ muscle: MuscleGroup; reason: String }`).
- `Xomfit/Services/TrainingNudgeService.swift` — mirrors `BadgeToastService` shape: `@MainActor enum`,
  pure-ish, persists a `lastNudgeDay` `UserDefaults` key; returns an optional nudge value.

**Files to modify:**
- `Xomfit/Views/MainTabView.swift` — extend the existing launch `.task` (`MainTabView.swift:179`):
  after `BadgeToastService.badgeForLaunch` returns nil, call `TrainingNudgeService`. Streak/PR
  always win (one toast per launch). Toast action seeds the generator with the single
  `MuscleGroup` (shared state flip preferred; deep link optional).
- `Xomfit/XomfitApp.swift` — (optional polish) add `xomfit://generate?muscle=<muscleGroup>`
  alongside existing `onOpenURL` routes (`XomfitApp.swift:186`) for the nudge action. **The deep
  link carries a single `MuscleGroup`, not a region.**

**Key types / methods (intent):**
- `TrainingNudgeService.nudgeForLaunch(workouts: [Workout], baseline: NudgeBaseline) -> UnderTrainedMuscle?`
  - Gate: at most **once per day** (new `lastNudgeDay` key; existing seam is once-per-*launch*).
  - Suppress: if a workout was logged today, if too few total workouts (cold start), and early in
    the week before enough signal — uses `WorkoutInsights.userCalendar()` for week boundaries.
  - Signal: SETS-per-`MuscleGroup` this week and over the trailing window via Seam 2 (NOT volume-split,
    NOT region rollup).
- `AdaptiveBaseline` — body-part-level adaptive detection over the 13 `MuscleGroup`s.

**AdaptiveBaseline firing condition (PROMOTED from open question to acceptance criterion —
load-bearing, locked decision 3):** Body-part-level detection across 13 groups has **high nag
risk**: with 13 muscles, something almost always looks "behind average." The threshold logic is the
*must-get-right* core of Phase 2, not an afterthought. The baseline fires for a muscle **only when
ALL of the following hold**, and it surfaces the **single most-behind muscle**, never a list:
  - **(a) Genuine personal deficit, not "below average this week."** The user normally trains this
    muscle by this point in the week (per their own trailing-4-week pattern) and has *not yet* done
    so this week. Compare this-week sets for the muscle against the muscle's own established
    expected-by-now level, NOT against a flat average across muscles.
  - **(b) Established baseline / enough signal.** The muscle must have a real baseline in the
    trailing 4 weeks — i.e. the user actually trains it. **Skip muscles the user never (or barely)
    trains** so the nudge can't invent a deficit for a muscle the user has chosen to ignore.
  - **(c) Enough into the week that an absence is meaningful.** Respect `weekStartDay` via
    `WorkoutInsights.userCalendar()`; **do not fire early-week** when there simply hasn't been time
    to hit the muscle yet.
  - Among all muscles satisfying (a)–(c), pick the **single most-behind** (largest deficit vs its
    own expected-by-now level) and surface only that one.

**Acceptance criteria:**
- [ ] New nudge branch in `MainTabView` launch task, after streak/PR, gated once-per-day via `lastNudgeDay`.
- [ ] Detection uses Seam 2 sets-per-`MuscleGroup`; never `BodyHeatmapViewModel` volume; never the
      Seam-3 region rollup (nudge is body-part granular).
- [ ] Baseline is injected as a `NudgeBaseline` (Seam 1); default `AdaptiveBaseline`; returns a
      single `UnderTrainedMuscle` (one `MuscleGroup` + reason) or nil.
- [ ] **Firing condition (load-bearing):** fires only when (a) genuine deficit vs the user's OWN
      established pattern for that muscle (not merely below this-week average), AND (b) the muscle
      has an established trailing-4-week baseline (muscles the user never trains are skipped), AND
      (c) far enough into the week (respects `weekStartDay`, no early-week firing). Surfaces the
      single most-behind muscle, not a list.
- [ ] Anti-nag honored: once/day, dismissible, respects `weekStartDay`, suppressed early-week /
      cold-start / workout-logged-today, yields to streak/PR.
- [ ] Tapping the nudge opens the Phase-1 generator pre-seeded with the single missing `MuscleGroup`.
- [ ] Unit tests: cold start, zero-session week, week boundary, each suppression rule, the three-part
      firing condition (genuine personal deficit vs flat-average false positive; never-trained muscle
      skipped; early-week suppressed), single-most-behind selection, once-per-day gate.

---

## Phase 3 — PLANNER (additive)

**Goal:** Let the user set an explicit weekly training goal ("4x this week, focus legs+back").
When set, it drives the nudge (directive: "1 more session to hit your goal"); when not, the nudge
falls back to the Phase-2 adaptive baseline. Local persistence + a simple set-goal UI.

**Depends on:** Phase 2 (Seam 1 `NudgeBaseline`, `TrainingNudgeService`). Purely additive — ships a
second `NudgeBaseline` impl; the toast/service code does not change.

**Files to create:**
- `Xomfit/Models/WeeklyPlan.swift` — `target sessions`, `focus regions` (Seam 3 vocabulary for the
  user-facing focus picker; internally expands to `MuscleGroup`s), week-start awareness; `Codable`.
  **Name is `WeeklyPlan`, not `TrainingGoal`** (that identifier is already an unrelated
  training-style enum at `Models/TrainingGoal.swift`).
- `GoalBaseline` impl (in `NudgeBaseline.swift`) — goal-driven when a `WeeklyPlan` exists; delegates
  to `AdaptiveBaseline` when nil (the hybrid). Returns the same `UnderTrainedMuscle` (single
  `MuscleGroup`) so the toast and deep link are unchanged.
- `Xomfit/ViewModels/WeeklyPlanViewModel.swift` + a set-goal view — read/write the plan to local storage.

**Files to modify:**
- `Xomfit/Services/TrainingNudgeService.swift` — inject `GoalBaseline` (wrapping adaptive) as the
  default baseline when a plan is present. No new branching in `MainTabView`.

**Key types / methods (intent):**
- `WeeklyPlan { targetSessions: Int; focusRegions: [TrainingRegion]; weekStart: ... }`, persisted via
  `@AppStorage`/`UserDefaults` (local only). Focus regions expand to `MuscleGroup`s via the Seam-3
  reverse map when the baseline computes per-muscle deficits.
- `GoalBaseline(plan: WeeklyPlan?, fallback: AdaptiveBaseline)` conforming to `NudgeBaseline`,
  returning a single `UnderTrainedMuscle`.

**Acceptance criteria:**
- [ ] User can set/edit a weekly goal (target sessions + focus regions) that persists locally.
- [ ] With a plan set, the nudge becomes goal-directive against the plan's targets, still surfacing
      a single `MuscleGroup`.
- [ ] With no plan, the nudge behaves exactly as Phase 2 (adaptive) — verified by test.
- [ ] No changes to `MainTabView`/`TrainingNudgeService` decision flow beyond baseline injection.
- [ ] Generator can pre-seed from the plan's focus regions (expanded to `MuscleGroup`s).
- [ ] Unit tests: goal-met vs goal-unmet, no-plan fallback equals adaptive, focus-region pre-seed.

---

## Out of Scope
- Any backend, REST, Supabase, or network call — the entire system is on-device/offline.
- Replacing or merging with the AI Coach `build_workout` flow — they stay separate entry points.
- Cardio/stretch generation (v1 generates strength workouts only).
- Superset auto-pairing (brainstormed; defer unless trivially cheap during Phase 1).
- Home widgets / weekly recap surfaces (possible future on top of Phase 3).
- **Equipment filtering / equipment UI (locked decision 1):** v1 assumes a full gym and picks from
  the entire catalog. A home/dumbbell/bodyweight equipment filter is a noted future enhancement,
  explicitly out of scope for v1.

## Risks / Tradeoffs
- **Nudge nag risk (Phase 2 — primary risk):** body-part-level detection across 13 `MuscleGroup`s
  means *something almost always looks behind*. This makes the `AdaptiveBaseline` threshold logic
  the single load-bearing, must-get-right part of Phase 2. Mitigation: the three-part firing
  condition (genuine personal deficit vs the user's own by-now pattern, established baseline only,
  late-enough-in-week) is promoted to a concrete acceptance criterion with dedicated tests; the
  nudge surfaces exactly one muscle and is gated once/day, dismissible, and yields to streak/PR.
- **Region rollup taxonomy (Seam 3):** PPL+core chosen for generator split chips and copy clarity,
  but `traps`/`forearms` in Pull and `shoulders` in Push are debatable. Lower stakes now that the
  nudge is body-part granular and doesn't depend on the rollup. Mitigation: the table lives in one
  place; re-tuning is a single-file edit and the generator split presets follow it automatically.
- **Familiarity-bias tuning (Phase 1):** too much bias → stale, same workout every time; too little →
  random/unliked lifts. Mitigation: explicit novelty-injection weight, seeded + unit-tested, tunable
  in one constant.
- **Reroll pool aggressiveness (Phase 1):** if the pool for a small muscle group is tiny, reroll may
  cycle through 2-3 options. Mitigation: reroll excludes current exercise only; accept small pools;
  optionally widen to related groups later.
- **Adaptive baseline edge cases (Phase 2):** users with < 4 weeks of data, zero-session weeks,
  week-boundary math, and never-trained muscles. Mitigation: explicit cold-start + never-trained
  suppression + dedicated edge-case tests.
- **AI-coach confusion:** two "make me a workout" entries risk feeling redundant. Mitigation: hard
  copy/visual distinction is an acceptance criterion in Phase 1.
- **Seam 2 refactor regression:** rewriting `ProgressViewModel.computeMuscleGroups` could shift the
  Progress chart. Mitigation: behavior-preserving refactor + verify chart unchanged.

## Open Questions
- [ ] Deep link vs shared-state flip for the nudge → generator hop: brainstorm says state flip is
      enough and the `xomfit://generate?muscle=` route is optional polish. Confirm before Phase 2.
- [ ] Trailing window length: fixed 4 weeks, or adapt when the user has < 4 weeks of history?
- [ ] Concrete deficit metric for `AdaptiveBaseline` "expected-by-now" (e.g. fraction of trailing
      weekly average pro-rated by day-of-week vs a fixed proportion) — pin during Phase 2 design.

## Skills / Agents to Use
- **`/orchestrate`**: split this EPIC into three sub-feature plans (`generator`, `toast-nudge`,
  `planner`) in dependency order; each gets its own `/plan` → `/execute`.
- **`ios-standards` skill**: enforce Swift 6 / SwiftUI / iOS 17 conventions (`@Observable`, modern
  APIs, strict concurrency, MVVM) in every sub-plan's implementation.
- **MVVM discipline (project rule)**: `WorkoutGenerator`, `TrainingNudgeService`, and the Seam-2/3
  helpers are pure and called from view models — never from views directly.
- **`/end-session`**: capture seam decisions + tuning constants into session memory after each phase.
