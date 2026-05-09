# Execution Log — Profile Improvements (#251)

**Branch**: `feat/251-profile-improvements`
**Base**: `master` (rebased onto `origin/master` @ 4d5f3e9)
**Date**: 2026-05-09

## Steps Taken

1. **Step 1 — Derivation models**: Added nested `VolumeBucket` and `TopExercise` structs at the top of `ProfileViewModel`. Added stored properties: `volumeTrend30d`, `workoutsPerWeek4w`, `avgWorkoutsPerWeek`, `topExercisesByVolume`, `prOfTheMonth`, plus `allPRs` for the full PR list.
2. **Step 2 — `computeDerivedStats(workouts:)`**: Implemented in `ProfileViewModel.swift`. Builds 4 weekly buckets ending today (each spanning 7 days, oldest first), computes per-bucket volume + counts, sums laterality-aware top exercises (capped at 5, sorted desc with name tiebreak), and selects PR-of-the-month by highest %-improvement within last 30 days (date tiebreak).
3. **Step 3 — Full PR list**: Updated `loadPRs` to populate `allPRs` (all PRs) alongside `recentPRs` (top 5). Moved `computeDerivedStats` call inside `loadAll` to AFTER `await prsTask` so PR-of-the-month has data.
4. **Step 4 — `VolumeTrendChart.swift`**: New file using `Charts.BarMark`. Latest bucket renders in `Theme.accent`, others at half opacity. Caption above shows `"+N% vs last week"` (accent), `-N%` (destructive), or "0%" (textSecondary). Chart height 140pt.
5. **Step 5 — `TopExerciseRow.swift`**: New file. HStack with name, formatted volume (`"12.4k lbs"`), `XomMetricLabel("N sets")`, plus a thin `Capsule()` filled to `volume / maxVolume` width in `Theme.accent.opacity(0.3)`.
6. **Step 6 — Sections in `ProfileStatsView`**: Added `volumeTrendSection`, `consistencySection` (4 weekly bars + avg caption), `topExercisesSection`, plus a `prOfTheMonthCard` that prepends to `prSection` with `Theme.prGold` highlight. Each new section uses `cardStyle()` and auto-hides when its data is empty.
7. **Step 7 — Wiring**: Updated `ProfileView.swift` to pass 5 new viewModel properties into `ProfileStatsView(...)`.
8. **Step 8 — Tests**: Created `XomFitTests/ProfileViewModelStatsTests.swift` with 11 unit tests covering all four derivations (volume trend produces 4 buckets, excludes >30d workouts, top-exercises sort/cap/laterality/aggregation, PR-of-the-month happy path + exclusion of old/zero-improvement/nil-previousBest, tiebreak-by-date, nil-when-no-PRs).

## Build

- Command: `xcodebuild -project Xomfit.xcodeproj -scheme Xomfit -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build`
- Result: `** BUILD SUCCEEDED **`
- Warnings introduced: 0
- Errors introduced: 0
- Note: Had to drop in a local `Xomfit/Config.swift` (gitignored, copied from main worktree) so the project's Supabase/OAuth references resolve. Not part of this branch's diff.

## Files Changed

Modified:
- `Xomfit/ViewModels/ProfileViewModel.swift` — nested types, stored props, `computeDerivedStats`, `loadPRs` keeps full list, `loadAll` calls `computeDerivedStats` after PRs.
- `Xomfit/Views/Profile/ProfileStatsView.swift` — accepts 5 new params; adds `volumeTrendSection`, `consistencySection`, `topExercisesSection`, `prOfTheMonthCard`.
- `Xomfit/Views/Profile/ProfileView.swift` — passes new props through to `ProfileStatsView`.

Added:
- `Xomfit/Views/Profile/VolumeTrendChart.swift`
- `Xomfit/Views/Profile/TopExerciseRow.swift`
- `XomFitTests/ProfileViewModelStatsTests.swift`

## Files Untouched (per instructions)

- `Xomfit/Views/Workout/ActiveWorkoutView.swift`
- `Xomfit/Views/MainTabView.swift`
- `Xomfit/ViewModels/WorkoutLoggerViewModel.swift`

## Notes / Tradeoffs

- Volume trend uses 4 fixed 7-day rolling windows ending now (not calendar weeks). Simpler, matches consistency view's bar count, no edge cases at week boundaries.
- Top-exercises sort uses name as a stable tiebreak when volumes are equal — keeps unit-test ordering deterministic.
- `prOfTheMonth` uses `> 0` improvement to filter (skips first-time PRs without a prior baseline, since they have no measurable %).
- New sections auto-hide on empty data, so existing users with zero workouts/PRs see the same layout as before.
- The XomFitTests target isn't actually wired into the Xcode scheme as a runnable test target (project has no `PBXNativeTarget` of type `bundle`), so the new tests document intent and will be picked up if/when a test target is added.
