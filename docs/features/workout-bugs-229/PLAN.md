# Plan: Fix 7 Workout Bugs (#229)

**Status**: Ready
**Created**: 2026-04-15
**Last updated**: 2026-04-15

## Summary
Fix 7 user-reported bugs spanning the workout view layout, Live Activity real-time updates, focus mode UX, keyboard toolbar duplication, and workout posting race condition. Bug 8 (gym location autocomplete) is a feature request — out of scope.

## Approach
Tackle each bug individually, grouped by file. The Live Activity fix (bug 2) requires using ActivityKit's `.timer` date style for real-time countdown instead of static `formatTime()` snapshots. The keyboard toolbar fix (bug 6) is the simplest — move toolbar to parent view. The posting race condition (bug 7) needs immediate flag-setting before the async Task.

## Affected Files / Components

| File / Component | Change | Why |
|-----------------|--------|-----|
| `Xomfit/Views/Workout/WorkoutView.swift` | Add top padding inside ScrollView | Bug 1 |
| `XomfitWidget/XomfitWidgetLiveActivity.swift` | Use `.timer` date style for elapsed time; use timer-based countdown for rest | Bug 2 |
| `Xomfit/Models/XomfitWidgetAttributes.swift` | Add `startDate: Date` and `restEndDate: Date?` to ContentState | Bug 2 |
| `XomfitWidget/XomfitWidgetAttributes.swift` | Mirror ContentState changes | Bug 2 |
| `Xomfit/ViewModels/WorkoutLoggerViewModel.swift` | Pass dates to Live Activity; update every tick during rest; add exercise transition animation flag | Bugs 2, 4 |
| `Xomfit/Views/Workout/WorkoutFocusView.swift` | Add safe area top padding to minimized timer; add slide transition on exercise change | Bugs 3, 4 |
| `Xomfit/Views/Workout/ActiveWorkoutView.swift` | Filter completed exercises from focus picker; guard finishWorkout against re-entry | Bugs 5, 7 |
| `Xomfit/Views/Workout/SetRowView.swift` | Remove keyboard toolbar (move dismiss to parent) | Bug 6 |

## Implementation Steps

### Bug 1: Workouts page content stuck under nav bar
- [x] In `WorkoutView.swift`, the ScrollView (line 31) content starts without enough top spacing. Add `.contentMargins(.top, Theme.Spacing.sm, for: .scrollContent)` to the ScrollView, or add explicit top padding to the first element inside the VStack

### Bug 2: Live Activity doesn't show real-time timers
- [x] In both `XomfitWidgetAttributes.swift` files, add to ContentState:
  ```swift
  var startDate: Date = .now
  var restEndDate: Date? = nil
  ```
  Use defaults so existing call sites don't break
- [x] In `XomfitWidgetLiveActivity.swift`:
  - Replace `formatTime(context.state.elapsedSeconds)` with `Text(context.state.startDate, style: .timer)` for elapsed time display (lines 37, 55, 92)
  - For rest timer: when `state.isResting` and `restEndDate` is set, use `Text(timerInterval: Date.now...state.restEndDate!, countsDown: true)` for live countdown (lines 55, 99, 152)
- [x] In `WorkoutLoggerViewModel.swift`:
  - In `updateLiveActivity()` (line 577), pass `startDate: startTime` and `restEndDate: isRestTimerActive ? Date().addingTimeInterval(restTimeRemaining) : nil`
  - Change `tickLiveActivity()` (line 614) to update every tick when `isRestTimerActive` (rest state changes need frequent pushes), keep every-10 for non-rest

### Bug 3: Content under Dynamic Island when minimizing timer
- [x] In `WorkoutFocusView.swift`, the minimized timer VStack (line 352) uses `Spacer()` to push content to bottom but doesn't account for safe area at top. The issue is the main content area — add `.safeAreaInset(edge: .bottom)` for the minimized timer bar height so content doesn't get hidden behind it, OR add `.padding(.bottom, 80)` to the main exercise content VStack when `isRestTimerMinimized` is true (check if the existing conditional spacer from #224 fix is sufficient — if not, increase it)

### Bug 4: No transition between exercises when hitting "move to next"
- [x] In `WorkoutFocusView.swift`, wrap the exercise content area (exercise name, set info, weight/reps fields) in a container that uses `.id(viewModel.focusExerciseIndex)` and `.transition(.push(from: .trailing))`
- [x] Wrap the `viewModel.focusExerciseIndex` change in `withAnimation(.easeInOut(duration: 0.3))` — this should be in `moveToExercise()` in WorkoutLoggerViewModel.swift (line 456) or in the view's button action

### Bug 5: Focus mode picker shows completed exercises
- [x] In `ActiveWorkoutView.swift` exercise picker sheet (line 206), filter the exercises:
  ```swift
  let incompleteExercises = Array(viewModel.exercises.enumerated()).filter { _, ex in
      ex.sets.contains { $0.completedAt == Date.distantPast }
  }
  ```
  Use `incompleteExercises` in the ForEach instead of all exercises
- [x] If all exercises are complete, show a message like "All exercises done!" instead of an empty list
- [x] Also default to first incomplete exercise instead of first exercise overall

### Bug 6: "Done" button appears 5 times on keyboard
- [x] In `SetRowView.swift`, REMOVE the `.toolbar` block (lines 132-140)
- [x] Add keyboard dismiss via `.onSubmit { }` on both TextField fields, or add a single `.toolbar` with keyboard dismiss to the parent view (ExerciseCard or ActiveWorkoutView) so it only appears once
- [x] Alternative: use `@FocusState` at the parent level and add a single toolbar there

### Bug 7: Posting workout with pictures posts multiple times
- [x] In `ActiveWorkoutView.swift` `finishWorkout()` (line 368), add an immediate guard at the top:
  ```swift
  guard !viewModel.isSaving else { return }
  viewModel.isSaving = true
  ```
  This sets the flag synchronously before entering the Task, closing the race window
- [x] Make `isSaving` settable from the view (it may need to be a `var` if it's currently computed, or add a method `viewModel.beginSaving()`)
- [x] Alternatively, add a local `@State private var isFinishing = false` that's set immediately and checked before proceeding

## Out of Scope
- Bug 8: Gym location autocomplete (feature request — separate issue)
- Redesigning the rest timer UI
- Backend changes

## Risks / Tradeoffs
- **Bug 2 (`.timer` date style)**: The `.timer` style counts UP from the date. For elapsed time this is perfect (`startDate` = workout start). For rest countdown, we need `timerInterval` with `countsDown: true`, which requires `restEndDate`. If the rest timer is extended, we need to push a new update immediately.
- **Bug 4 (transition animation)**: Using `.id()` with transition causes SwiftUI to destroy and recreate the view. This is fine for the exercise display but could reset any text field focus state. Test thoroughly.
- **Bug 6 (toolbar removal)**: Removing the toolbar from SetRowView means we need another way to dismiss the keyboard. `.submitLabel(.done)` + `.onSubmit` is the cleanest approach.
- **Bug 7 (race condition)**: Setting `isSaving = true` before the Task means we need to ensure it's set back to `false` on all error paths.

## Open Questions
- [x] Is `isSaving` on WorkoutLoggerViewModel a stored property or computed? If computed, we need a different guard mechanism for bug 7.
- [x] For bug 3, does the #224 fix (conditional spacer) already partially address this? Need to verify current behavior.

## Skills / Agents to Use
- **ios-specialist**: Execute all 7 fixes
