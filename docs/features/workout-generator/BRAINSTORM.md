# Brainstorm — Workout Generator + Daily Nudge

**Date:** 2026-06-14
**Author:** Brainstorm agent (for Dominick / XomFit)
**Status:** Design exploration — no code written

Three bundled sub-features, recommended build order:
1. Constrained-random workout generator
2. First-daily-login toast (nudge into the generator)
3. Weekly planner (deferred — likely v2)

---

## Premise check + key findings from the codebase

A few things from reading the code that should shape the plan:

1. **An LLM workout generator already exists.** `AICoachViewModel` + `AICoachService` have a
   `build_workout` tool call that produces a runnable workout with a Save/Start card
   (`AICoachViewModel.startWorkout`, `AICoachView.swift:278`). The feature we're designing is
   the **deterministic, offline, zero-cost twin** of that. Frame it that way: the generator is
   "instant, free, no chat" — the coach is "conversational, smart, costs tokens + network".
   This is a real differentiator, not redundancy, but the plan should make the distinction
   crisp in the UI so they don't feel like two buttons doing the same thing.

2. **The builder already produces a runnable, non-persisted workout.**
   `WorkoutBuilderViewModel.buildTemplate()` returns a `WorkoutTemplate` without saving;
   `save()` persists via `TemplateService`. `WorkoutLoggerViewModel.startFromTemplate(_:userId:)`
   turns any template into a live session (and prefills weights from last-set history). So the
   generator's output type should be `WorkoutTemplate` — then Start Now and Save reuse 100% of
   existing plumbing. No new "runnable workout" abstraction needed.

3. **The toast pattern is fully built and battle-tested.** `BadgeToastService.badgeForLaunch`
   returns at most one `Badge`, persists "last seen" markers in UserDefaults, and
   `MainTabView`'s `.task` block shows it ~1s after mount via `.toast()`. The nudge slots into
   exactly this seam — it's a new branch/service alongside streak + PR, NOT new infrastructure.
   Note the existing once-per-*launch* semantics; the nudge needs once-per-*day*, which is a
   small addition (persist a `lastNudgeDay`).

4. **Set-frequency data is already computed the right way.** `ProgressViewModel.computeMuscleGroups`
   counts SETS per `MuscleGroup` (the correct signal for "what have I trained"). The volume-split
   logic in `BodyHeatmapViewModel` is explicitly the wrong tool — confirmed. Detection should
   lift `computeMuscleGroups`'s approach into a pure helper (it currently lives privately in a
   view model).

5. **`MuscleGroup` → region rollup doesn't exist yet** and there are two plausible region
   vocabularies already in the codebase: the `TemplateCategory` enum has both PPL
   (push/pull/legs) AND body-part (chest/back/shoulders/arms) cases. Pick one for the nudge.

6. **Cold-launch data is available without network.** `WorkoutService.fetchWorkoutsFromCache(userId:)`
   (UserDefaults-cached) is what `MainTabView` already feeds to `BadgeToastService`. The nudge
   can use the same cached array — no async fetch needed at launch.

7. **Deep-link routing exists** in `XomfitApp.onOpenURL` (`xomfit://workout`, `report`, etc.).
   But the toast lives *inside* `MainTabView` and the generator entry point is on `WorkoutView`.
   We don't actually need a URL round-trip — the toast action can flip shared state directly.
   A deep link is optional polish, not a requirement.

**Net:** This is mostly *assembly of existing primitives* plus one genuinely new piece — the
constrained-random selection algorithm. Scope the ambition on the algorithm and the nudge
intelligence, not on infrastructure.

---

## Phase 1 — Explore (the possibility space)

**Generator algorithm**
- Pure function: `(targets, timeBudget, setCount) -> WorkoutTemplate`.
- Exercise pool = `ExerciseDatabase.all` filtered by target muscle groups + equipment.
- Compound-first ordering (sort by `category == .compound`, then isolation).
- Time → exercise count: `estimatedDuration ~= sets * 2min` (matches existing builder math),
  so `exerciseCount ≈ timeBudget / (avgSets * 2)`.
- Rep schemes by category: compound → "5" / "6-8", isolation → "10-12" / "12-15", cardio → time.
- Per-muscle slot allocation: distribute exercise slots across selected groups (round-robin or
  weighted by group "size" — e.g. back gets more than calves).
- Single-exercise reroll: swap one slot for another from the same group's pool, excluding
  what's already in the workout.
- Familiarity bias: weight the pool toward exercises the user has actually logged
  (frequency map from `computeStrengthData`-style data) vs pure novelty.
- Equipment filtering: respect an equipment-availability preference (home vs gym).
- Superset auto-pairing for short time budgets (pair antagonist isolations).
- Seeded RNG so a reroll is reproducible / testable.

**Generator UX**
- Entry: new CTA on `WorkoutView` ("Generate" / dice icon) next to Build / Log Past.
- Config screen: muscle/region chips + time budget slider + set-count stepper.
- Preview screen: list of exercises, each with a reroll (dice) button per row.
- Footer: "Start Now" (→ `startFromTemplate`) and "Save as Template" (→ `TemplateService`).
- Reroll-all button. Maybe "lock" a row so reroll-all keeps it.

**Nudge baseline**
- Adaptive: trailing-4-week personal set/frequency pattern → flag under-trained regions.
- Explicit weekly goal (planner) as baseline.
- Hybrid: adaptive by default, planner overrides when set.
- Pure recency: "you haven't trained legs in N days".
- Balance-based: region with the lowest share of recent sets.

**Nudge UX / anti-nag**
- Once/day max (persist `lastNudgeDay`).
- Respect week-start preference (`WorkoutInsights.userCalendar()`).
- Don't nag early in the week with thin data (e.g. suppress until day 3 of the week, or until
  ≥2 sessions logged this week).
- Suppress if a workout is already active or one was logged today.
- Suppress if too few total workouts (cold start — needs a baseline to compare against).
- Global toggle in Settings.
- "Snooze region for the week" after dismiss.
- Yield to streak/PR toast (one toast per launch — priority order).

**Detection granularity**
- Coarse regions for the nudge (push/pull/legs OR chest/back/legs/shoulders/arms/core).
- Full 13 `MuscleGroup`s for generator exercise picking.
- Map missing region → seed set of `MuscleGroup`s for the generator.

**Output / persistence**
- Ephemeral start-now only.
- Save-as-template only.
- Both (recommended — trivial given existing plumbing).

---

## Phase 2 — Converge

### Option 1: Lean MVP — "Dice Button"

**What:** Deterministic generator + a simple recency-based daily toast. Ship the core loop,
defer the smart stuff.

**How it works:** A pure `WorkoutGenerator` service takes selected regions + time budget,
filters `ExerciseDatabase`, orders compound-first, allocates slots round-robin across groups,
applies category-based rep schemes, and returns a `WorkoutTemplate`. Preview screen with
per-row reroll. Start Now and Save both reuse existing template plumbing. The nudge is pure
**recency**: "You haven't trained {region} in N days" using coarse PPL rollup over cached
workouts, once/day, yielding to streak/PR toasts. No familiarity bias, no trailing-average
math, no equipment preference (assume full gym).

**Pros:**
- Smallest surface area; almost all infra already exists.
- Recency nudge is dead simple to reason about and explain to the user.
- Ships the whole user-visible loop (generate → preview → start) in one pass.
- Pure functions = trivially testable.

**Cons / Risks:**
- Recency-only nudge is naive: "haven't trained X in N days" ignores *how much* you train X.
  Someone who does legs once a week on purpose gets nagged.
- No familiarity bias means it can suggest exercises the user has never done and doesn't like.
- No equipment filter → suggests barbell lifts to a dumbbell-only home lifter.

**Best if:** You want the feature live this week and are willing to iterate the intelligence
later. Good "walking skeleton".

---

### Option 2: Adaptive — "Knows Your Patterns" (recommended)

**What:** Everything in Option 1, but the nudge uses your **trailing-4-week personal set
pattern** (zero-config) and the generator has **familiarity bias** + **equipment preference**.

**How it works:** Extract `computeMuscleGroups`'s set-counting into a pure
`MuscleFrequency` helper. The nudge computes each coarse region's share of sets over the
trailing 4 weeks, compares the *current* week's sets-so-far against that personal baseline,
and flags the region that's most under its own norm (not a fixed goal). Anti-nag: suppress
until ≥2 sessions logged this week (avoids early-week false positives), once/day, yields to
streak/PR. Generator adds a familiarity weight (exercises you've logged rank higher, with a
small novelty injection) and an equipment-availability preference stored in Settings
(home/gym/custom). Output supports both Start Now and Save.

**Pros:**
- Nudge adapts to *your* habits — no "train everything equally" assumption baked in.
- Familiarity bias makes generated workouts feel personal, not random.
- Equipment filter makes it actually usable for home lifters.
- Still 100% local, no network, no token cost — a clean contrast to the AI Coach.
- Reuses the existing set-frequency logic; the "trailing 4wk vs this week" math is the only
  genuinely new analysis.

**Cons / Risks:**
- "Trailing-average vs this-week" needs careful edge-case handling (new users with <4wk data,
  weeks with zero sessions, week-boundary math). More test cases than Option 1.
- Equipment preference adds a Settings surface + a migration default.
- Slightly more to build before first ship.

**Best if:** This is the default. It's the smallest version that makes both the nudge and the
generator feel *intelligent* rather than mechanical, and it stays fully offline.

---

### Option 3: Full Build — "Planner-Backed"

**What:** Option 2 plus the **weekly planner** (sub-feature 3): an explicit goal ("4x this
week, focus legs+back") that becomes the nudge baseline, with the adaptive pattern as
fallback when no goal is set (the hybrid).

**How it works:** A `WeeklyPlan` model (target sessions + focus regions + week start),
persisted locally. A planner screen to set it. The nudge prioritizes the plan: progress
against explicit targets first, fall back to adaptive trailing-average when no plan exists.
Generator can pre-seed from the plan's focus regions. Optionally a progress ring/widget for
"3 of 4 sessions this week".

**Pros:**
- Most powerful: users who want structure get goal-tracking; users who don't get adaptive.
- Nudge becomes genuinely directive ("1 more session to hit your weekly goal").
- Sets up future surfaces (home widget, weekly recap).

**Cons / Risks:**
- Biggest scope; the planner is a whole new model + screen + persistence + nudge integration.
- For a solo personal app, goal-setting friction may go unused — adaptive already covers the
  90% case with zero config.
- Risk of building the planner before validating whether the adaptive nudge alone is enough.

**Best if:** Only after Option 2 ships and you find yourself *wanting* explicit weekly targets.
Don't build speculatively.

---

## Phase 3 — Recommendation

**Build Option 2 (Adaptive), explicitly deferring the planner (Option 3).**

Reasoning:
- The infrastructure (toast seam, runnable templates, set-frequency counting, cached workouts)
  is already there, so the *marginal* cost of the adaptive version over the lean MVP is small —
  mostly the trailing-average comparison and a familiarity weight. The intelligence is where
  the value is; skipping it (Option 1) ships something that nags wrong and suggests random
  lifts.
- The planner (Option 3) is the one piece that's genuinely large and genuinely deferrable. The
  adaptive nudge is zero-config and covers the common case. Build the planner only if you
  reach for it after living with Option 2. The brief already flags it as "later / possibly v2"
  — agree, keep it out of the first cut.

**Decisions on the named design tensions:**

1. **Nudge baseline → Adaptive now, hybrid later.** Trailing-4-week personal pattern, zero-config.
   Design the nudge so a future `WeeklyPlan` can override the baseline without a rewrite (inject
   the baseline as a value the nudge consumes).
2. **Detection granularity → coarse regions for the nudge, full 13 for the generator.** Use the
   **PPL rollup** (push / pull / legs) for the nudge — it matches the user's existing
   `TemplateCategory` mental model, maps cleanly onto the 13 groups, and keeps the toast copy
   simple ("haven't hit Pull much this week"). Keep core/abs as a 4th bucket if it falls out
   cleanly; don't over-fragment. The generator still picks from all 13.
3. **Generator output → both Start Now and Save.** Output a `WorkoutTemplate`; reuse
   `startFromTemplate` and `TemplateService.saveCustomTemplate`. Near-zero extra cost.
4. **Generator algorithm → constrained-random with familiarity bias + light novelty.**
   Compound-first, equipment-filtered, time→count via the existing ~2min/set heuristic,
   category-based rep schemes, seeded RNG for reproducible rerolls, per-row reroll within the
   same muscle pool. Bias toward logged exercises with a small novelty injection so it's
   personal but not stale.
5. **Anti-nag controls → once/day + yield to streak/PR + suppress until ≥2 sessions this week +
   suppress if workout active/logged today + Settings toggle.** Persist `lastNudgeDay`,
   respect `WorkoutInsights.userCalendar()`.

**What this depends on:**
- Equipment-availability preference: confirm whether you want a home/gym toggle in v1. If you
  always train at a full gym, drop the equipment filter from v1 and it collapses toward Option
  1's simplicity on that axis (recommend keeping it — it's cheap and you've mentioned home
  training patterns).
- UI relationship to the AI Coach: confirm the generator should be a *separate* deterministic
  entry point (recommended) rather than folded into the coach.

---

## Implementation notes for the planner (handoff)

- **New pure service:** `WorkoutGenerator` (struct/enum, pure functions, seeded RNG). Output
  `WorkoutTemplate`. Mirror the testability of `WorkoutInsights`.
- **New pure helper:** lift set-frequency counting out of `ProgressViewModel.computeMuscleGroups`
  into a shared `MuscleFrequency`/`WorkoutInsights` function so both Progress and the nudge use
  one source of truth. Add the `MuscleGroup → Region` rollup here.
- **New service:** `TrainingNudgeService` alongside `BadgeToastService`, same once-per-X +
  UserDefaults "last seen" pattern, but keyed on `lastNudgeDay`. Returns an optional nudge
  value; the view decides priority (streak/PR first).
- **Toast integration:** extend `MainTabView`'s existing `.task` block — after the streak/PR
  badge check returns nil, ask `TrainingNudgeService`. The nudge toast's action seeds the
  generator config and routes to it (shared state flip; a `xomfit://generate?region=` deep
  link is optional polish).
- **Generator UI:** config screen + preview screen, presented as a sheet from a new `WorkoutView`
  CTA (sits next to Build / Log Past). Reroll per row, Start Now / Save in the footer.
- **Settings:** equipment-availability preference (`@AppStorage`) + nudge on/off toggle.
- **Reuse:** `startFromTemplate` (prefills weights), `TemplateService.saveCustomTemplate`,
  `fetchWorkoutsFromCache`, `WorkoutInsights.userCalendar()`, the warmup `requestStart` flow.
- **MVVM:** views go through view models; `WorkoutGenerator` / `TrainingNudgeService` /
  `MuscleFrequency` are pure and called from view models, not views.
- **Tests:** generator determinism (seeded), time→count, compound ordering, equipment filter,
  reroll exclusion; nudge edge cases (cold start, zero-session week, week boundary, suppression
  rules).

---

Brainstorm saved: docs/features/workout-generator/BRAINSTORM.md
Recommendation: Option 2 — Adaptive ("Knows Your Patterns")
Next: /plan workout-generator — I'll use this doc as context
