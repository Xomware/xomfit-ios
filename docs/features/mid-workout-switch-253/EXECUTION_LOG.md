# Execution Log: Mid-Workout Exercise Switcher (#253)

**Branch**: `feat/253-mid-workout-switch`
**Base**: `master`
**Date**: 2026-05-09

## Summary
Implemented the persistent current-exercise pill + jumper sheet end-to-end per the plan. All steps 1-7 complete. Step 8 (manual smoke test) is left to the user; build is clean.

## Steps Completed

- **Step 1 — VM helpers.** Added `currentExerciseName`, `currentSetNumber`, `currentExerciseTotalSets`, and `jumpToExercise(index:)` to `WorkoutLoggerViewModel`. The new method explicitly does NOT toggle `showExerciseTransition` (documented inline) so it stays decoupled from `moveToExercise(index:)`.
- **Step 2 — Jumper sheet.** Created `Xomfit/Views/Workout/ExerciseJumperSheet.swift`. Lists every exercise with leading status icon, per-set dots, completion fraction, "Current" badge for the focused exercise, and a chevron. Uses `.medium`/`.large` detents with drag indicator. VoiceOver label + hint per row.
- **Step 3 — Pill.** Added `currentExercisePill` private view in `ActiveWorkoutView`. Capsule on `Theme.surface` with `figure.strengthtraining.traditional` icon, exercise name, "Set N/M" framing, trailing `chevron.up.chevron.down`. Min 44pt tap target. Falls back to "All exercises complete" copy when `viewModel.allExercisesComplete` is true. Includes accessibility label + hint.
- **Step 4 — Sheet wiring.** Added `@State showExerciseJumper` and `@State pendingScrollIndex`. New `.sheet(isPresented: $showExerciseJumper)` modifier presents `ExerciseJumperSheet`, passing an `onJump` closure that sets `pendingScrollIndex`.
- **Step 5 — Scroll-to-card.** Wrapped the list-mode `LazyVStack` in a `ScrollViewReader`, assigned `.id(exIdx)` to each `ExerciseCard`, and added `.onChange(of: pendingScrollIndex)` that calls `proxy.scrollTo(idx, anchor: .top)` inside `withAnimation(.xomChill)`, then clears `pendingScrollIndex`.
- **Step 6 — Focus mode handling.** No code changes needed. `WorkoutFocusView` already keys on `viewModel.focusExerciseIndex` (`.id(...)` line 55) so the existing push transition fires when the jumper updates `focusExerciseIndex`.
- **Step 7 — Don't double-trigger transition card.** Confirmed `jumpToExercise` does not set `showExerciseTransition`. Inline comment in the VM documents the distinction between `moveToExercise` (transition-flow path) and `jumpToExercise` (free navigation).

## Coordination With #255
- Pill placed below the `headerBar`, NOT inside it. The pause button being added to `headerBar` will not collide.
- `WorkoutLoggerViewModel` was extended additively only (new computed properties + new method). I did not add or reference any `isPaused` property; the concurrent agent owns that.

## Build
- Command: `xcodebuild -project Xomfit.xcodeproj -scheme Xomfit -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build`
- Result: **BUILD SUCCEEDED**
- New/modified files: zero compiler warnings.
- Pre-existing warnings in unrelated files (Onboarding, FriendsViewModel, ProfileViewModel) untouched.
- One pre-existing environment dependency (`Xomfit/Config.swift`) had to be created from `Config.swift.template` to make the build pass; this file is gitignored and not part of the commit.

## Files Changed
- `Xomfit/ViewModels/WorkoutLoggerViewModel.swift` — additive: 4 new members.
- `Xomfit/Views/Workout/ActiveWorkoutView.swift` — added pill, jumper sheet wiring, ScrollViewReader.
- `Xomfit/Views/Workout/ExerciseJumperSheet.swift` — new file.

## Test Plan Status
Steps T1-T9 in `PLAN.md` are manual smoke tests that require launching the simulator and exercising the UI. Build verifies type-correctness; manual passes are deferred to the user.

## Out of Scope (per plan)
Reordering, renaming, search/filter, persistence, Live Activity surface, extra haptics — all left untouched.
