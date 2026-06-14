# Plan: Workout Generator System — Phase 1: Generator (Core)

**Epic**: workout-generator
**Sub-feature ID**: P1 (Phase 1 — GENERATOR / foundation)
**Status**: Ready
**Created**: 2026-06-14
**Last updated**: 2026-06-14
**Depends on**: none (foundation — runs first)

> Parent epic: `docs/features/workout-generator/PLAN.md`. This sub-plan implements
> **Phase 1 — GENERATOR** only. The epic's **Shared Seams** section is the source of
> truth for the three cross-phase contracts. This plan **pins** the concrete Swift
> signatures for Seam 2 and Seam 3 (Phase 1 introduces both); Phases 2 and 3 consume
> them verbatim and must not redefine them.

## Summary
A fully-local, zero-token, offline constrained-random workout generator. Tap a dice CTA on the
Workout tab → pick muscles (split quick-pick chips and/or the full 13-`MuscleGroup` grid) + time
budget + set count → get a runnable `WorkoutTemplate` preview with per-row reroll → Start Now or
Save. Full-gym catalog, no equipment filtering in v1. Conceptually distinct from the AI Coach (no
chat, no network, no "thinking" state) — they share only the `WorkoutTemplate` output type
(`Models/WorkoutTemplate.swift`) and the downstream Start/Save plumbing
(`WorkoutLoggerViewModel.startFromTemplate`, `TemplateService.saveCustomTemplate`).

## Approach
Anchor on the epic's Phase 1 algorithm rules. The only genuinely new logic is `WorkoutGenerator`
(pure, seeded) plus the two seams it introduces; everything else is assembly over existing
infrastructure. Layering, strictly MVVM:

- **`WorkoutGenerator`** (pure value type in `Services/`) — no service calls, no I/O, no
  `@MainActor`. Takes plain inputs (targets, time, sets, familiarity map, seed) and returns a
  `WorkoutTemplate`. Deterministic given a seed via an **injectable seeded RNG** so the engine is
  unit-testable without UI.
- **`WorkoutGeneratorViewModel`** (`@MainActor @Observable`) — owns config state (`Set<MuscleGroup>`,
  time, set count, current seed) and the preview template. It is the *only* layer that touches
  services: pulls cached history via `WorkoutService.fetchWorkoutsFromCache`, derives the
  familiarity map via Seam 2, calls the pure engine, and bridges Start/Save.
- **Views** (`Views/Workout/Generator/`) — pure presentation; bind to the view model. Never call
  `WorkoutGenerator`, `WorkoutService`, `TemplateService`, or `WorkoutLoggerViewModel` directly.

Confirmed facts from source that the plan relies on:
- `ExerciseCategory` cases are `.compound, .isolation, .cardio, .stretching` (`Models/Exercise.swift:69`).
  Strength gen uses `.compound` + `.isolation` only; `.cardio`/`.stretching` are excluded.
- `MuscleGroup` has exactly 13 cases (`Models/Exercise.swift:25-29`):
  `chest, back, shoulders, biceps, triceps, quads, hamstrings, glutes, calves, abs, forearms, traps, lats`.
- Time heuristic = **2 min/set**: `WorkoutBuilderViewModel.estimatedDuration` is
  `exercises.reduce(0) { $0 + $1.targetSets * 2 }` (`WorkoutBuilderViewModel.swift:24`).
- `WorkoutTemplate.TemplateExercise` needs `{ id, exercise, targetSets, targetReps: String, notes }`
  (`Models/WorkoutTemplate.swift:12`). `category` is `TemplateCategory` (`:27`).
- `startFromTemplate(_:userId:)` prefills weight/reps from last-set history (`WorkoutLoggerViewModel.swift:317`).
- `saveCustomTemplate(_:)` forces `isCustom = true` and dedupes by `id` (`TemplateService.swift:24`).
- Familiarity = per-exercise logged frequency: walk `workout.exercises[].exercise.id` over cached
  `[Workout]` (`Models/Workout.swift:180-183`).
- `computeMuscleGroups` to lift lives at `ProgressViewModel.swift:164` and counts
  `workoutExercise.sets.count` per `exercise.muscleGroups` entry into `[MuscleGroup: Int]`.

## Shared Seams — definitions this phase OWNS

### Seam 2 — `WorkoutInsights.setsPerMuscleGroup(...)`
**Location:** `Xomfit/Utils/WorkoutInsights.swift` (extend the existing pure-helper `enum`).
**Signatures (pinned — Phases 2/3 inherit verbatim):**
```
static func setsPerMuscleGroup(workouts: [Workout]) -> [MuscleGroup: Int]
static func setsPerMuscleGroup(workouts: [Workout], since: Date) -> [MuscleGroup: Int]
```
- Body of the no-arg variant is **exactly** the loop currently in `ProgressViewModel.computeMuscleGroups`:
  for each `workout.exercises`, add `workoutExercise.sets.count` to each entry in
  `workoutExercise.exercise.muscleGroups`. Returns the unsorted `[MuscleGroup: Int]` map.
- The `since:` variant pre-filters `workouts` to `workout.startTime >= since` then delegates.
- **Refactor obligation (regression risk):** rewrite `ProgressViewModel.computeMuscleGroups` to call
  the no-arg helper, then apply the *existing* sort + display mapping it already does:
  `.sorted { $0.value > $1.value }.map { (group: $0.key.displayName, sets: $0.value) }`. The helper
  returns the raw map; the **sort/display step stays in `ProgressViewModel`** so the Progress chart
  output is byte-for-byte identical. This is behavior-preserving — verify the chart is unchanged.

### Seam 3 — `MuscleGroup` → region rollup (Push/Pull/Legs/Core)
**Location:** `Xomfit/Utils/WorkoutInsights.swift` — a small `enum TrainingRegion` + a `MuscleGroup`
extension, co-located with Seam 2 (do **not** spin up a separate file in Phase 1; the epic permits
promoting to `Models/TrainingRegion.swift` later if it grows).
**Type + signatures (pinned):**
```
enum TrainingRegion: String, CaseIterable, Identifiable {
    case push, pull, legs, core
    var id: String { rawValue }
    var displayName: String            // "Push" / "Pull" / "Legs" / "Core"
    var muscles: [MuscleGroup]         // reverse map (region → constituent muscles)
    var templateCategory: WorkoutTemplate.TemplateCategory  // push→.push, pull→.pull, legs→.legs, core→.custom
}
extension MuscleGroup { var region: TrainingRegion { ... } }  // forward map (all 13 cases)
```
**Full 13-case forward mapping (`MuscleGroup.region`):**

| Region | `MuscleGroup` cases |
|--------|---------------------|
| `.push` | `chest`, `shoulders`, `triceps` |
| `.pull` | `back`, `lats`, `biceps`, `traps`, `forearms` |
| `.legs` | `quads`, `hamstrings`, `glutes`, `calves` |
| `.core` | `abs` |

**Reverse map (`TrainingRegion.muscles`)** is the inverse of the table above (e.g. `.legs` →
`[.quads, .hamstrings, .glutes, .calves]`). Tapping a split chip multi-selects exactly
`region.muscles`; there is no separate split data path. `templateCategory`: `.push→.push`,
`.pull→.pull`, `.legs→.legs`, `.core→.custom` (no abs-only `TemplateCategory` case exists).

## Affected Files / Components
| File / Component | Change | Why |
|------------------|--------|-----|
| `Xomfit/Services/WorkoutGenerator.swift` | **create** | Pure constrained-random engine + seeded RNG; no services |
| `Xomfit/ViewModels/WorkoutGeneratorViewModel.swift` | **create** | `@MainActor @Observable` config/preview/reroll bridge; the only service-touching layer |
| `Xomfit/Views/Workout/Generator/WorkoutGeneratorConfigView.swift` | **create** | Split chips + 13-muscle grid + time slider + set stepper |
| `Xomfit/Views/Workout/Generator/WorkoutGeneratorPreviewView.swift` | **create** | Exercise list, per-row reroll, Start Now / Save footer |
| `Xomfit/Views/Workout/WorkoutView.swift` | **modify** | Add "Generate" dice CTA + sheet presentation, framed "Instant · No AI · Offline" |
| `Xomfit/Utils/WorkoutInsights.swift` | **modify** | Introduce Seam 2 helper + Seam 3 (`TrainingRegion` + `MuscleGroup.region`) |
| `Xomfit/ViewModels/ProgressViewModel.swift` | **modify** | Refactor `computeMuscleGroups` to call Seam 2 (behavior-preserving) |
| `XomfitTests/WorkoutGeneratorTests.swift` (or repo test target) | **create** | Engine unit tests (deterministic via seed) |
| `XomfitTests/WorkoutInsightsSeamTests.swift` | **create** | Seam 2 + Seam 3 unit tests |
| `Xomfit/Models/WorkoutTemplate.swift` | read-only | Output type; `TemplateExercise` shape; `TemplateCategory` |
| `Xomfit/Models/Exercise.swift` | read-only | `MuscleGroup` (13), `ExerciseCategory`, `Exercise.id/muscleGroups` |
| `Xomfit/Models/ExerciseDatabase.swift` | read-only | `.all` = full-gym pool; `byId` for reroll |
| `Xomfit/ViewModels/WorkoutLoggerViewModel.swift` | read-only | `startFromTemplate` = "Start now" |
| `Xomfit/Services/TemplateService.swift` | read-only | `saveCustomTemplate` = "Save as template" |
| `Xomfit/Services/WorkoutService.swift` | read-only | `fetchWorkoutsFromCache` for familiarity |
| `Xomfit/ViewModels/AICoachViewModel.swift` | read-only | Distinction reference — generator stays visually/conceptually separate |

## Key Types & Method Signatures

### `WorkoutGenerator` (pure engine)
```
struct WorkoutGenerator {
    // Tunables (single source of truth — see Risks):
    static let minutesPerSet = 2                 // time → count heuristic
    static let familiarityWeight = 3.0           // bias multiplier (logged exercises)
    static let noveltyFloor = 1.0                 // base weight so unlogged lifts still appear

    func generate(
        targets: [MuscleGroup],
        timeBudgetMinutes: Int,
        targetSets: Int,
        familiarity: [String: Int],              // exerciseId → logged-set count (from Seam-2/history walk)
        seed: UInt64
    ) -> WorkoutTemplate

    func reroll(
        slot: Int,
        in template: WorkoutTemplate,
        targets: [MuscleGroup],
        familiarity: [String: Int],
        seed: UInt64
    ) -> WorkoutTemplate
}
```

### Seeded RNG (injectable for determinism)
```
struct SeededGenerator: RandomNumberGenerator {   // deterministic, e.g. SplitMix64
    init(seed: UInt64)
    mutating func next() -> UInt64
}
```
The engine creates a `SeededGenerator(seed:)` internally and uses Swift's
`RandomNumberGenerator`-taking APIs (`randomElement(using:)`, `shuffled(using:)`). Same seed → same
output. Tests pass fixed seeds and assert exact templates.

### Algorithm rules (locked)
1. **Pool** = `ExerciseDatabase.all` filtered to exercises whose `muscleGroups` intersect `targets`,
   keeping only `category ∈ {.compound, .isolation}` (exclude `.cardio`, `.stretching`). No equipment filter.
2. **Exercise count** = `max(2, min(poolCount, timeBudgetMinutes / (targetSets * minutesPerSet)))`.
   (e.g. 60 min, 3 sets → 60/6 = 10 → clamped to pool size.)
3. **Slot allocation across groups** — weight each selected group by its filtered pool size so
   large groups (back/legs) get more slots than small ones (calves/abs); round-robin distributes the
   integer remainder. Produces an ordered list of `(group, count)` slot intents.
4. **Per-slot pick** — within a group's sub-pool, pick weighted by familiarity:
   `weight = noveltyFloor + familiarityWeight * log(1 + familiarity[exercise.id] ?? 0)`. Draw with
   `randomElement(using:)` over the weighted set; exclude exercises already chosen for this template
   (no duplicates across slots).
5. **Compound-before-isolation ordering** — after all slots are picked, stable-sort the final list so
   `category == .compound` precede `.isolation`. Within a category, preserve selection order.
6. **Rep schemes by category** (string `targetReps`, matching existing template vocabulary):
   `.compound` → "5" or "6-8"; `.isolation` → "10-12" or "12-15". Chosen per exercise via the seeded
   RNG (so it's deterministic, not always the same literal).
7. **Output `WorkoutTemplate`**: `id = UUID().uuidString`, `name` derived from the dominant region
   (e.g. "Push Generator" / "Mixed"), `description = "\(count) exercises, ~\(duration)min"`,
   `estimatedDuration = Σ targetSets * minutesPerSet`, `category` = `TrainingRegion` of the most-common
   target region via `.templateCategory` (fallback `.custom` for mixed/core), `isCustom = true`.
8. **Reroll** — recompute only the named `slot`: take that slot's group sub-pool, exclude every
   exercise currently in the template (so reroll never duplicates and never returns the current one
   unless the pool has size 1), weighted-pick one, re-apply the slot's rep scheme, and re-sort
   compound-before-isolation. All other slots unchanged. Deterministic per seed.

## Implementation Steps
- [ ] **1 — Seam 2 helper.** In `Xomfit/Utils/WorkoutInsights.swift`, add the two
      `setsPerMuscleGroup(...)` static funcs with the pinned signatures, body lifted verbatim from
      `ProgressViewModel.computeMuscleGroups` (return the raw `[MuscleGroup: Int]`).
- [ ] **2 — Seam 2 refactor (regression-sensitive).** Rewrite `ProgressViewModel.computeMuscleGroups`
      (`ProgressViewModel.swift:164`) to call `WorkoutInsights.setsPerMuscleGroup(workouts:)`, then
      apply the existing `.sorted { $0.value > $1.value }.map { ... displayName ... }` to populate
      `muscleGroupSets`. No other behavior change. Verify the Progress muscle-group chart is unchanged
      (visual check via the auth-bypass screenshot flow if available).
- [ ] **3 — Seam 3 rollup.** In the same file, add `enum TrainingRegion` (with `displayName`,
      `muscles`, `templateCategory`) and `extension MuscleGroup { var region: TrainingRegion }` using
      the pinned 13-case table.
- [ ] **4 — Seeded RNG.** In `Xomfit/Services/WorkoutGenerator.swift`, implement
      `SeededGenerator: RandomNumberGenerator` (SplitMix64). Keep it `internal` so tests can construct it.
- [ ] **5 — Engine core.** In the same file, implement `WorkoutGenerator` with the tunable constants,
      the pool filter, time→count, weighted slot allocation, familiarity-weighted per-slot pick (no
      duplicates), compound-before-isolation sort, rep-scheme assignment, and `WorkoutTemplate`
      assembly per Algorithm rules 1–7. Pure — no service/`@MainActor`/I/O.
- [ ] **6 — Reroll.** Implement `WorkoutGenerator.reroll(...)` per Algorithm rule 8.
- [ ] **7 — Engine unit tests.** Create `WorkoutGeneratorTests`: determinism (same seed →
      identical template; different seed → may differ), time→count formula, compound ordering,
      reroll exclusion/no-dup, slot allocation weighting, empty-targets and tiny-pool edge cases.
- [ ] **8 — Seam unit tests.** Create `WorkoutInsightsSeamTests`: Seam 2 set counting (single + `since:`
      window), Seam 3 forward map covers all 13 cases, reverse map round-trips, `templateCategory` map.
- [ ] **9 — View model.** Create `Xomfit/ViewModels/WorkoutGeneratorViewModel.swift`
      (`@MainActor @Observable`): config state (`selectedMuscles: Set<MuscleGroup>`,
      `timeBudgetMinutes: Int`, `targetSets: Int`, `seed: UInt64`), derived `previewTemplate`.
      Methods: `toggleRegion(_:)` (multi-select via `TrainingRegion.muscles`), `toggleMuscle(_:)`,
      `generate(userId:)` (fetch cache → build familiarity map via history walk → call engine),
      `rerollSlot(_:userId:)`, `startNow(using:userId:)` → `startFromTemplate`, `saveTemplate()` →
      `saveCustomTemplate`. Optional `preseed(muscle:)` entry point for Phase 2 (single muscle) — add
      now so Phase 2 needs no VM change.
- [ ] **10 — Familiarity map helper.** In the view model (or a small private func), build
      `[String: Int]` by walking cached workouts' `exercises[].exercise.id` and summing `sets.count`.
- [ ] **11 — Config view.** Create `WorkoutGeneratorConfigView.swift`: Push/Pull/Legs/Core chips
      (drive `toggleRegion`), full 13-`MuscleGroup` grid (drive `toggleMuscle`), time slider, set
      stepper, "Generate" button (disabled when `selectedMuscles` empty). Binds to the view model only.
- [ ] **12 — Preview view.** Create `WorkoutGeneratorPreviewView.swift`: exercise rows with name /
      target sets×reps / muscle tag, per-row dice reroll button (`rerollSlot`), footer Start Now /
      Save. No chat, no spinner, no "thinking" state. Header copy reinforces "Instant · Offline".
- [ ] **13 — Entry point.** In `WorkoutView.swift`, add a "Generate" CTA (dice icon, subtitle
      "Instant · No AI · Offline") alongside Build / Log Past; present `WorkoutGeneratorConfigView`
      via `@State` sheet, owning a `WorkoutGeneratorViewModel`. Route Start Now through the existing
      `requestStart(...)` warmup gate, mirroring the `TemplateDetailView` start path
      (`WorkoutView.swift:103-115`).
- [ ] **14 — Wire Save / list refresh.** Save calls `saveCustomTemplate`; on sheet dismiss, trigger
      the existing `viewModel.load(userId:)` so the new template appears in the list.
- [ ] **15 — Build + verify.** `xcodebuild -scheme Xomfit -destination 'platform=iOS Simulator,name=iPhone 16'`;
      run tests; screenshot the generator flow via the `XOMFIT_AUTH_BYPASS=1` path.

## Acceptance Criteria
- [ ] Dice CTA on `WorkoutView` opens a config sheet with Push/Pull/Legs/Core chips AND the full
      13-muscle grid, plus time slider and set stepper.
- [ ] Tapping a split chip multi-selects exactly its Seam-3 `muscles`; the user can then toggle
      individual muscles; the generator consumes only the resulting `Set<MuscleGroup>`.
- [ ] Generate produces a `WorkoutTemplate`: target groups only, full catalog (no equipment filter),
      compound-before-isolation order, category-appropriate rep schemes, count from time budget.
- [ ] Per-row reroll swaps only that slot from the same muscle pool, never duplicates an existing
      exercise; same seed → identical result.
- [ ] Start Now → `startFromTemplate` (weights prefilled); Save → `saveCustomTemplate` (template
      appears in the list).
- [ ] No network call, no token spend, no AI Coach UI anywhere in the flow. No equipment UI in v1.
- [ ] Seam 2 + Seam 3 exist, are pure and unit-tested; the Progress muscle-group chart is unchanged.
- [ ] Views never call `WorkoutGenerator`/services directly — all access goes through the view model.
- [ ] Unit tests pass: determinism (seeded), time→count, compound ordering, split→muscle expansion,
      reroll exclusion, slot allocation, Seam 2 counting, Seam 3 full mapping.

## Unit-Test Plan
- **Determinism (load-bearing):** `WorkoutGenerator` randomness is injected via `SeededGenerator`.
  Tests construct the engine, call `generate(seed: 42)` twice, assert identical `exercises` (ids,
  sets, reps, order). A different seed is allowed (not required) to differ.
- **Time→count:** assert `(60, 3) → 10` clamped to pool; `(30, 4) → 3`; small budgets clamp to `≥2`.
- **Compound ordering:** assert all `.compound` indices precede all `.isolation` in output.
- **Slot allocation:** with `[.back, .calves]`, back receives more slots than calves (pool-size weighting).
- **Reroll exclusion:** `reroll(slot:)` output's slot exercise ∉ the other slots and ≠ the prior one
  (when pool > 1); other slots byte-identical.
- **Split→muscle expansion (Seam 3):** `TrainingRegion.legs.muscles == [.quads, .hamstrings, .glutes, .calves]`;
  `MuscleGroup.region` defined for all 13 cases (exhaustive switch — no default).
- **Seam 2:** known fixture workouts → expected `[MuscleGroup: Int]`; `since:` window excludes older.

## Out of Scope
- Phase 2 (nudge) and Phase 3 (planner): no `NudgeBaseline`, `TrainingNudgeService`, `WeeklyPlan`.
- Equipment filtering / equipment UI (epic locked decision 1 — full gym v1).
- Cardio/stretch generation; superset auto-pairing; widening reroll pools to related groups.

## Risks / Tradeoffs
- **Seam 2 refactor regression** (highest): rewriting `ProgressViewModel.computeMuscleGroups` could
  shift the Progress chart. Mitigation: helper returns the raw map; the sort/display step stays in
  the view model so output is identical. Verify visually + with a Seam 2 unit test.
- **Familiarity-bias tuning:** too much → same workout every time; too little → random/unliked lifts.
  Mitigation: single tunable `familiarityWeight` (+ `noveltyFloor`) constant, seeded and unit-tested,
  log-scaled so heavy-history exercises don't dominate.
- **Reroll pool size for small groups** (e.g. abs/calves): reroll may cycle 2–3 options. Accepted —
  reroll excludes only exercises already in the template; widening to related groups is future work.
- **Seeded-randomness approach:** SplitMix64 chosen for simplicity/determinism; not crypto (fine —
  workout generation, not security). Must remain stable across runs for reroll reproducibility.
- **AI-coach confusion:** two "make me a workout" entry points. Mitigation: hard copy/visual
  distinction ("Instant · No AI · Offline", no chat/spinner) is an acceptance criterion.

## Open Questions
- [ ] Final `familiarityWeight` / `noveltyFloor` values — start at 3.0 / 1.0, tune after first build.
- [ ] Mixed-region output naming: "Mixed" vs listing top region — pick during view build (cosmetic).
- [ ] Should `generate` reuse the same `seed` until config changes, or roll a new seed each tap?
      Recommendation: new seed per "Generate" tap; stable seed within a preview for reroll reproducibility.

## Skills / Agents to Use
- **`ios-standards` skill**: Swift 6 / SwiftUI / iOS 17 — `@Observable`, modern APIs, strict
  concurrency, MVVM. Applies to the view model + views.
- **MVVM discipline (project rule)**: `WorkoutGenerator` + Seam helpers are pure and called from the
  view model, never from views.
