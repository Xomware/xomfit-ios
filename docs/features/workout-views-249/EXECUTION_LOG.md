# Execution Log: #249 Workout Views — Tabs + Filter Chips

**Branch**: `feat/249-workout-views-filter` (off `master`)
**Date**: 2026-05-09

## Steps Completed

- [x] Step 1 — Added `WorkoutFilter` struct (`Xomfit/Models/WorkoutFilter.swift`) with `matches(_ template:)` and `matches(_ workout:)`. Empty filter passes everything; combined criteria AND together. Search hits name + description + exercise names.
- [x] Step 2 — Added `WorkoutFilterBar` (`Xomfit/Views/Workout/WorkoutFilterBar.swift`): search field with clear button + horizontal `XomBadge(.interactive)` rails for `MuscleGroup` and `Equipment`. Mirrors `ExercisePickerView` pattern. VoiceOver-aware (`isSelected` trait on chips).
- [x] Step 3 — Added `WorkoutTab` enum in `Xomfit/ViewModels/WorkoutTabViewModel.swift` (`.mine`, `.recent`, `.templates`, `.friends`) with `displayName` and `icon`.
- [x] Step 4 — Added `WorkoutTabViewModel` (`@Observable`, `@MainActor`) holding all four data arrays + `selectedTab` (persisted to `UserDefaults`) + `filter`. Exposes `filteredTemplatesMine`, `filteredTemplatesBuiltIn`, `filteredRecent`, `filteredFriendWorkouts` and `isEmptyAfterFilter(for:)`.
- [x] Step 5 — Added `WorkoutService.fetchFriendsRecentWorkouts(currentUserId:limit:)`. Fans out via `withTaskGroup` over `FriendsService.fetchFriends` IDs, merges, sorts by `startTime` desc, caps at 30. Never throws — failures logged.
- [x] Step 6 — Refactored `WorkoutView`: kept `Start Workout` + `Build Workout` CTAs and the first-workout onboarding card untouched at top (preserves #257 entry-point coordination). Added `WorkoutFilterBar` + `Picker(.segmented)` + per-tab `LazyVStack` of row-style cards.
- [x] Step 7 — Wired tap actions: Mine / Recent / Templates open `previewTemplate` sheet → `TemplateDetailView`. Friends open a read-only `WorkoutDetailView` in a `NavigationStack`-wrapped sheet (no edit/delete UI). `Workout` is `Identifiable` only (not `Hashable`), so a sheet is required — `navigationDestination(item:)` would need a `Hashable` conformance change we didn't want to risk in this PR.
- [x] Step 8 — Per-tab empty states using `XomEmptyState`:
  - Mine empty → CTA to Build Workout
  - Recent empty → CTA to Start Workout
  - Friends empty → "Add friends to see their recent workouts here" (no nav CTA — Friends lives behind Feed's nav stack and is not directly addressable from here)
  - Filter empty (any tab) → CTA to clear the filter
- [x] Step 9 — `selectedTab` persisted to `UserDefaults` key `xomfit_workout_selected_tab` via `didSet`. Default tab is `.templates` for first launch.
- [x] Step 10 — Clean build, zero warnings.

## Build Result

```
xcodebuild -project Xomfit.xcodeproj -scheme Xomfit \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build
```

`** BUILD SUCCEEDED **` — 0 warnings, 0 errors.

## Files Touched

**Created**
- `Xomfit/Models/WorkoutFilter.swift`
- `Xomfit/Views/Workout/WorkoutFilterBar.swift`
- `Xomfit/ViewModels/WorkoutTabViewModel.swift`

**Modified**
- `Xomfit/Services/WorkoutService.swift` — new `fetchFriendsRecentWorkouts` method
- `Xomfit/Views/Workout/TemplateCardView.swift` — added `style: .compact | .row` parameter (default `.compact`, preserves all existing carousel callsites)
- `Xomfit/Views/Workout/RecentWorkoutCard.swift` — added `style: .compact | .row` parameter (default `.compact`)
- `Xomfit/Views/Workout/WorkoutView.swift` — full refactor from stacked carousels to tabs + filter, kept CTAs and onboarding card

## Coordination Notes (#257)

- `Start Workout` CTA — kept at top, untouched.
- `Build Workout` CTA — kept at top, untouched.
- First-workout onboarding card — kept at top, untouched.
- Layout changed from stacked carousels → segmented tabs + filter bar + vertical list. Entry points preserved; only the discovery surfaces (carousel sections) refactored into tabs.
- The other agent adding "Log Past Workout" can append a new button alongside the existing two CTAs without touching the new tab/filter logic.

## Out of Scope (per plan)

- Rating filter — no `WorkoutTemplate` rating field.
- Save-friend's-workout — separate model/feature.
- Server-side filtering / pagination — client-side over fetched arrays.
- Friends backend RPC — current fan-out is acceptable at <50 friends with the 30-item cap.

## Manual Test Plan Status

Manual UI verification deferred to user — build is green and structure matches the plan. Test cases enumerated in `PLAN.md` Manual Test Plan section.
