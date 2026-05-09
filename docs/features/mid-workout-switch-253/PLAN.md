# Plan: Mid-Workout Exercise Switcher

**Status**: Ready
**Created**: 2026-05-09
**Last updated**: 2026-05-09
**Issue**: [#253](https://github.com/Xomware/xomfit-ios/issues/253)
**Branch**: `feature/253-mid-workout-switch`

## Summary
Mid-workout it is hard to switch between exercises — the only "choose different" affordance lives inside the post-set transition card, and the focus mode entry picker only appears when starting fresh (post #238 fix). Add a persistent, tappable "current exercise" pill at the top of the active workout that opens a bottom-sheet jumper listing every exercise with completion state, working in both list mode and focus mode. Success: at any point during a workout the user can see what they're on, tap it, pick another exercise, and land there in one gesture.

## Approach
Reuse the same VM state already in place (`focusExerciseIndex`, `focusSetIndex`, `syncFocusToCurrentExercise`, `moveToExercise`). No new persistence, no new model fields.

- Add a compact `CurrentExercisePill` rendered between the existing header bar and the rest-timer config / focus-view content. Visible whenever `viewModel.exercises` is non-empty.
- Pill content: exercise name + "Set N/M" (where N is the current set, M is total sets for that exercise).
- Tap → presents an `ExerciseJumperSheet` (bottom sheet, `.medium` detent) listing every exercise with status (completed / in-progress / not-started) and per-set dots.
- Tapping an exercise in the sheet sets `focusExerciseIndex` and `focusSetIndex` (first incomplete set, or set 0 if all complete) and dismisses the sheet. In list mode this scrolls the list to that exercise card; in focus mode the existing `id`-driven push transition already handles the visual jump.
- This replaces no existing UI — the post-set transition card and the focus-mode entry picker continue to work unchanged.

The existing `showStartingExercisePicker` sheet (lines 199-241 of `ActiveWorkoutView.swift`) is the closest existing pattern. The new jumper is a generalized version of it: shows all exercises (not just incomplete), works any time (not just at focus-mode entry), and is reachable from a persistent pill (not just from the eye toggle).

## Affected Files / Components

| File / Component | Change | Why |
|------------------|--------|-----|
| `Xomfit/Views/Workout/ActiveWorkoutView.swift` | Add `currentExercisePill` view + `showExerciseJumper` `@State` + `.sheet` for jumper. Insert pill below `headerBar` in both branches of the `if viewModel.focusMode` block. | Persistent indicator + tap target in both modes. |
| `Xomfit/Views/Workout/ExerciseJumperSheet.swift` (new) | New file: bottom-sheet view listing all exercises with per-exercise completion summary + per-set dots. Tap jumps focus indices. | Centralized, reusable jumper UI. |
| `Xomfit/ViewModels/WorkoutLoggerViewModel.swift` | Add a small computed `currentExerciseSummary: (name: String, setNumber: Int, totalSets: Int)?` or two computed accessors driving the pill text. Add `jumpToExercise(index:)` that mirrors `moveToExercise` but does not depend on the transition card flow. | Single source of truth for "what's current"; clean call site for the jumper. |
| `Xomfit/Views/Workout/ActiveWorkoutView.swift` (list-mode `ScrollView`) | Wrap `LazyVStack` in a `ScrollViewReader` and assign each `ExerciseCard` an `.id(exIdx)` so the jumper can `proxy.scrollTo(idx, anchor: .top)` when the user picks from list mode. | Tap-to-jump is meaningless in list mode without scrolling to the card. |

## Implementation Steps

- [ ] **Step 1 — VM helpers.** In `WorkoutLoggerViewModel.swift`, add:
  - `var currentExerciseName: String?` — name of `exercises[focusExerciseIndex]` if that index is valid, else `nil`.
  - `var currentSetNumber: Int` — `focusSetIndex + 1` clamped to `[1, focusExercise?.sets.count ?? 1]`.
  - `var currentExerciseTotalSets: Int` — `focusExercise?.sets.count ?? 0`.
  - `func jumpToExercise(index: Int)` — guards `exercises.indices.contains(index)`, sets `focusExerciseIndex = index`, then sets `focusSetIndex` to the first incomplete set in that exercise (mirror `syncFocusToCurrentExercise` logic for a single exercise) — fallback to `0` if all complete. Does **not** toggle `showExerciseTransition`.
  - These do not change existing behavior; they're additive.

- [ ] **Step 2 — Build the jumper sheet.** Create `Xomfit/Views/Workout/ExerciseJumperSheet.swift`. Mirror the styling of the existing `showStartingExercisePicker` sheet (lines 199-241) but iterate over **all** `viewModel.exercises`. Per row:
  - Exercise name (bold).
  - Per-set dots: small filled circles for completed sets (`Theme.accent`), hollow stroked circles for incomplete (`Theme.textSecondary`). Reuse the visual language from `WorkoutFocusView.setIndicator` at smaller scale.
  - Trailing "current" badge when `idx == viewModel.focusExerciseIndex`.
  - Completed-state row tint (subtle dimming) when all sets for that exercise are done — they remain tappable (user might want to add another set or just look back).
  - Tap → call `viewModel.jumpToExercise(index: idx)` then dismiss the sheet.
  - Use `.presentationDetents([.medium, .large])` and `.presentationDragIndicator(.visible)`.

- [ ] **Step 3 — Add the pill.** In `ActiveWorkoutView.swift`, inside the outer `VStack(spacing: 0)`, immediately after `headerBar` and before the `if !viewModel.isRestTimerActive && !viewModel.focusMode { restTimerConfig }` line, insert a private `currentExercisePill` view.
  - Layout: rounded capsule, `Theme.surface` background, `.padding(.horizontal, Theme.Spacing.md)`, `.padding(.top, Theme.Spacing.xs)`. Inner `HStack`: small `figure.strengthtraining.traditional` icon, `Text(viewModel.currentExerciseName ?? "—")` (semibold), middle dot separator, `Text("Set \(viewModel.currentSetNumber)/\(viewModel.currentExerciseTotalSets)")` muted, `Spacer()`, trailing `chevron.up.chevron.down` to signal interactivity.
  - Hidden when `viewModel.exercises.isEmpty` (the empty state already handles that case).
  - Hidden when `viewModel.allExercisesComplete` — replace with a small "All exercises complete" row (still tappable to open the jumper) so the user can re-enter a finished exercise to add another set.
  - Min 44pt tap target. `.accessibilityLabel("Current: \(name), set \(N) of \(M). Tap to switch exercises.")` `.accessibilityHint("Opens exercise list")`.
  - Wrap as a `Button { showExerciseJumper = true; Haptics.selection() } label: { ... }.buttonStyle(.plain)`.

- [ ] **Step 4 — Wire the sheet.** Add `@State private var showExerciseJumper = false` near the other sheet flags (around line 10-19). Add a new `.sheet(isPresented: $showExerciseJumper) { ExerciseJumperSheet(viewModel: viewModel) }` modifier alongside the existing sheets at the bottom of `body`.

- [ ] **Step 5 — Scroll-to-card in list mode.** Wrap the list-mode `LazyVStack` (lines 62-72) inside a `ScrollViewReader`. Assign each `ExerciseCard` an `.id(exIdx)`. Expose a callback or use a `@State var pendingScrollIndex: Int?` driven by the jumper. After `jumpToExercise` runs, set `pendingScrollIndex` and use `.onChange(of: pendingScrollIndex)` inside the `ScrollViewReader` to call `proxy.scrollTo(idx, anchor: .top)` then clear it.
  - Simpler alternative: have `ExerciseJumperSheet` accept an `onJump: (Int) -> Void` closure that the parent uses to set `pendingScrollIndex`. Closure approach keeps the sheet decoupled from `ScrollViewReader`. Use this.

- [ ] **Step 6 — Focus mode handling.** No extra work — `WorkoutFocusView` already keys its content on `viewModel.focusExerciseIndex` (`.id(viewModel.focusExerciseIndex)` line 55) with a push transition. Setting `focusExerciseIndex` from the jumper triggers the existing animation. Verify in T2 below.

- [ ] **Step 7 — Don't double-trigger transition card.** Confirm `jumpToExercise` does NOT set `showExerciseTransition = true`. The jumper is independent of post-set flow. Add a comment in the VM to document the distinction between `moveToExercise` (transition-flow path) and `jumpToExercise` (free navigation).

- [ ] **Step 8 — Manual smoke test pass.** Run T1-T6 (below) on simulator.

- [ ] **Step 9 — Commit.** `#253 active workout: persistent current-exercise pill + jumper sheet`

## Test Plan (manual)

- **T1 — Pill renders.** Start workout with 3 exercises. Pill shows first exercise name + "Set 1/3".
- **T2 — Updates on set complete.** Complete set 1 → pill updates to "Set 2/3". Complete all 3 → pill updates to next exercise (after dismissing the existing transition card).
- **T3 — List-mode jump.** Scroll to the bottom (4th+ exercise). Tap pill → sheet opens. Tap first exercise → sheet dismisses, list scrolls to first exercise card. `focusExerciseIndex` is updated.
- **T4 — Focus-mode jump.** Toggle focus (eye icon). Pill still visible above focus content. Tap pill → sheet opens. Tap a different exercise → sheet dismisses, focus view animates to that exercise (existing push transition).
- **T5 — Completed-exercise tap.** Complete all sets of exercise 1. Tap pill, tap exercise 1 in jumper → focus lands on its last set; user can `addSet` if they want another. No transition card pops.
- **T6 — Existing flows untouched.** (a) Eye-toggle starting picker still appears on fresh multi-exercise workouts (#238 logic). (b) Post-set transition card still appears when completing all sets of an exercise. (c) "Choose Different" inside the transition card still works.
- **T7 — Empty state.** Start a workout with no exercises queued. Pill is hidden. Add an exercise → pill appears.
- **T8 — All complete state.** Complete every set across every exercise. Pill shows "All exercises complete" row, still tappable. Tapping opens the jumper; tapping any exercise jumps focus to its last set.
- **T9 — Accessibility.** VoiceOver reads pill label; double-tap opens jumper. Dynamic Type at largest size doesn't truncate the pill into a broken layout (test at AccessibilityExtraExtraExtraLarge).

## Out of Scope
- Reordering exercises from inside the jumper sheet (use existing card up/down chevrons).
- Renaming or removing exercises from the jumper.
- Filter/search in the jumper — workouts have <20 exercises in practice.
- Persisting jumper UI state across app launches.
- Live Activity surface changes (Dynamic Island still shows current exercise via existing `currentExercise` field).
- Haptics beyond a single `.selection` on pill tap.

## Risks / Tradeoffs
- **Conflict with #238 focus-mode entry picker.** The eye-toggle picker (`showStartingExercisePicker`) only fires on fresh workouts (`completedSets == 0`). The new jumper is reachable any time. Both can coexist — they target different moments — but we must not auto-open the jumper from the eye toggle. **Mitigation**: T6a covers this. Do not modify the eye-toggle logic in this PR.
- **Visual crowding under the Dynamic Island.** Pill sits directly under `headerBar`. On smaller devices with island present + rest-timer chip in header, the area gets dense. **Mitigation**: pill uses subtle `Theme.surface` (not accent) and small font. If Test T1 shows visual collision, reduce vertical padding to `Theme.Spacing.xs`.
- **List-mode scroll jank.** Wrapping `LazyVStack` in `ScrollViewReader` and assigning `.id(idx)` to each card is fine, but `LazyVStack` can mis-target `scrollTo` if a card is far off-screen and not yet rendered. **Mitigation**: use `anchor: .top` and call `scrollTo` inside `withAnimation(.xomChill)`. If jank appears, fall back to `ScrollView` with eager rendering for workouts <10 exercises.
- **Pill state drift.** If `focusExerciseIndex` ever points outside `exercises.indices`, the pill must not crash. **Mitigation**: VM helpers guard with `exercises.indices.contains`; pill renders "—" / hides gracefully.
- **Don't break the eye/focus-picker flow added in #238.** The new code path (`jumpToExercise`) is purely additive — `syncFocusToCurrentExercise()` and `showStartingExercisePicker` logic remain untouched. **Mitigation**: T6a explicitly checks the #238 flow still triggers exactly when expected.
- **Focus-mode set indicator shows the same thing.** The horizontal set-dots strip in `WorkoutFocusView.setIndicator` already shows current set within current exercise. The pill is somewhat redundant in focus mode but provides the cross-exercise jumper entry point that focus mode currently lacks. Accepted tradeoff — small redundancy is worth a consistent affordance across modes.

## Open Questions
- [ ] Should pill text on a multi-set in-progress exercise show "Set 2/3" (current set focused) or "1/3 done" (sets completed)? Plan picks the former for parity with the focus-mode set dots; revisit if user feedback prefers progress phrasing.
- [ ] Should the jumper sheet auto-open the first time a user enters list mode mid-workout, as a discoverability nudge? Default: no. Reconsider after a week of use.

## Skills / Agents to Use
- **ios-standards skill**: confirm `@Observable` patterns and the new sheet conforms to project SwiftUI conventions (`foregroundStyle`, `clipShape(.rect())`, `NavigationStack`).
- **swift-ios-engineer agent**: implement Steps 1-7 end-to-end (single file additions + one new file + two cross-cutting edits in `ActiveWorkoutView`).
- **code-reviewer agent**: post-implementation review focused on (a) `jumpToExercise` does not interact with `showExerciseTransition`, (b) `ScrollViewReader` does not regress list-mode rendering, (c) accessibility labels are present on the pill and jumper rows.
