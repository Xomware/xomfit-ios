# Execution Log — Workout Generator Core (Phase 1)

## Pre-flight findings
- Seam 2 (`WorkoutInsights.setsPerMuscleGroup`) and Seam 3 (`TrainingRegion` +
  `MuscleGroup.region`) were **already present** in `Xomfit/Utils/WorkoutInsights.swift`
  and `ProgressViewModel.computeMuscleGroups` already refactored to call Seam 2
  (git status shows both files modified). Verified the implementations match the
  pinned plan signatures and the 13-case mapping exactly. Steps 1-3 = DONE (pre-existing).
- Project uses `PBXFileSystemSynchronizedRootGroup` for the `Xomfit/` app target —
  new source files are auto-included by living in the directory; no pbxproj edits.
- **No test target exists.** `xcodebuild -list` shows only `Xomfit` and
  `XomfitWidgetExtension`; the scheme's TestAction has no Testables. The on-disk
  `XomfitTests/` dir is NOT referenced by any target. `xcodebuild test` cannot run
  them. Test files are still written per steps 7-8 for when a target is wired.

## Steps
- [x] **1 — Seam 2 helper.** Already present in `WorkoutInsights.swift` (verified
      against pinned signatures + verbatim loop body).
- [x] **2 — Seam 2 refactor.** `ProgressViewModel.computeMuscleGroups` already calls
      the helper, keeping the sort/displayName map locally. Behavior-preserving.
- [x] **3 — Seam 3 rollup.** `TrainingRegion` + `MuscleGroup.region` already present
      with the full 13-case mapping. Verified by `WorkoutInsightsSeamTests`.
- [x] **4 — Seeded RNG.** `SeededGenerator` (SplitMix64) in `WorkoutGenerator.swift`,
      `internal` so tests can build it.
- [x] **5 — Engine core.** `WorkoutGenerator.generate(...)` — pool filter, time→count,
      weighted slot allocation, familiarity-weighted picks (log-scaled, no dups),
      compound-first sort, seeded rep schemes, template assembly. Pure, no services.
- [x] **6 — Reroll.** `WorkoutGenerator.reroll(...)` — on-theme sub-pool, excludes all
      existing exercises, re-sorts compound-first, deterministic per slot seed.
- [x] **7 — Engine unit tests.** `XomfitTests/WorkoutGeneratorTests.swift` +
      `SeededGeneratorTests`. (Written; see test-target note — cannot run via xcodebuild.)
- [x] **8 — Seam unit tests.** `XomfitTests/WorkoutInsightsSeamTests.swift`. (Written;
      same test-target caveat.)
- [x] **9 — View model.** `WorkoutGeneratorViewModel` (`@MainActor @Observable`):
      config state, `toggleRegion`/`toggleMuscle`/`isRegionSelected`, `generate`,
      `rerollSlot`, `saveTemplate`, `reset`, and `preseed(muscle:)` for Phase 2.
- [x] **10 — Familiarity map.** Private `familiarityMap(userId:)` walks cached workouts'
      `exercises[].exercise.id`, summing `sets.count`.
- [x] **11 — Config view.** `WorkoutGeneratorConfigView` — PPL+Core chips, 13-muscle
      grid, time slider, set stepper, Generate CTA (disabled when empty). VM-only binding.
- [x] **12 — Preview view.** `WorkoutGeneratorPreviewView` — rows with sets×reps + muscle
      tag, per-row reroll dice, Start Now / Save footer. No chat/spinner; "instant·offline" copy.
- [x] **13 — Entry point.** `WorkoutView` — "Generate" CTA (dice + "Instant · No AI ·
      Offline"), sheet owning the gen VM. Start Now routed through the existing
      `requestStart(...)` warmup gate, mirroring the TemplateDetailView path.
- [x] **14 — Wire Save / list refresh.** Save → `viewModel.saveTemplate()`; sheet
      `onDismiss` + `onSaved` trigger `WorkoutTabViewModel.load(userId:)`.
- [x] **15 — Build + verify.** App target builds clean (BUILD SUCCEEDED, iPhone 17,
      Debug). See test-target note below for the test action.

## Test-target note (honest status)
`xcodebuild -list` shows only `Xomfit` and `XomfitWidgetExtension` — **there is no
unit-test target** in `Xomfit.xcodeproj`, and `Xomfit.xcscheme`'s `<TestAction>` has
no `<Testables>`. The on-disk `XomfitTests/` directory (28+ existing test files) is
NOT referenced by any target, so `xcodebuild test` fails with
"Scheme Xomfit is not currently configured for the test action." This is a
pre-existing project condition, not introduced here. New test files were written to
match the existing convention (`@testable import XomFit`, XCTest) and will execute
once a test target is wired. Pool-size assumptions used by the tests were verified
against `ExerciseDatabase` (chest=33, back=39 > calves=6, abs=19) so the assertions
are correct.

## Final status
- App target build: **BUILD SUCCEEDED** (iPhone 17, Debug).
- Tests: **written, not runnable** — no test target exists in the project (see note).
</content>
</invoke>
