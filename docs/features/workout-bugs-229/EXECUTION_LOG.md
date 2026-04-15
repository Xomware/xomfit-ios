# Execution Log: Fix 7 Workout Bugs (#229)

**Started**: 2026-04-15
**Branch**: `fix/229-workout-bugs`

## Bug 6: Remove duplicate keyboard toolbar ✅
- Removed `.toolbar { ToolbarItemGroup(placement: .keyboard) }` from `SetRowView.swift` (was line 132-140)
- Added single keyboard toolbar to `ActiveWorkoutView.swift` using `UIApplication.sendAction(resignFirstResponder)` — appears only once regardless of how many SetRowViews are rendered

## Bug 1: Fix workouts page content under nav bar ✅
- Added `.navigationBarTitleDisplayMode(.large)` to `WorkoutView.swift` — explicitly sets large title mode instead of relying on `.automatic` which can behave unpredictably

## Bug 5: Focus picker shows completed exercises ✅
- Filtered exercise picker sheet in `ActiveWorkoutView.swift` to only show exercises with incomplete sets
- Shows remaining set count ("3 sets left") instead of total
- Added "All exercises complete!" message when all exercises are done
- Focus mode now defaults to first incomplete exercise instead of first exercise overall

## Bug 7: Posting workout multiple times ✅
- Added `guard !viewModel.isSaving else { return }` at top of `finishWorkout()` in `ActiveWorkoutView.swift`
- Set `viewModel.isSaving = true` synchronously before entering async Task, closing the race window between tap and async execution

## Bug 3: Content under Dynamic Island ✅
- Added `.safeAreaPadding(.top)` to main content VStack in `WorkoutFocusView.swift` — ensures content respects Dynamic Island safe area when timer is minimized

## Bug 4: No exercise transition animation ✅
- Wrapped exercise content (header, config, sets, weight, reps, done button) in a VStack with `.id(viewModel.focusExerciseIndex)` and `.transition(.push(from: .trailing))`
- Added `.animation(.easeInOut(duration: 0.3))` keyed to `focusExerciseIndex` — exercises now slide in from the right when navigating forward

## Bug 2: Live Activity real-time timers ✅
- Added `restEndDate: Date?` to `ContentState` in both `XomfitWidgetAttributes.swift` files
- Replaced all `formatTime(elapsedSeconds)` calls with `Text(startTime, style: .timer)` for real-time elapsed time
- Rest timer now uses `Text(timerInterval: Date.now...endDate, countsDown: true)` for live countdown
- Updated in: DI expanded trailing, compact trailing, lock screen top row, lock screen middle row, DI expanded bottom
- ViewModel now passes `restEndDate = Date().addingTimeInterval(restTimeRemaining)` when resting
- Changed `tickLiveActivity()` from every-10 updates to every-5 during rest (state sync) and every-30 otherwise (timer style handles display)
- Added `updateLiveActivity()` call to `extendRestTimer()` so extended rest immediately updates the end date

## Build ✅
- `xcodebuild -scheme Xomfit -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` — compiled successfully with no errors

## Files Changed
| File | Changes |
|------|---------|
| `Xomfit/Views/Workout/SetRowView.swift` | Removed keyboard toolbar |
| `Xomfit/Views/Workout/WorkoutView.swift` | Added `.navigationBarTitleDisplayMode(.large)` |
| `Xomfit/Views/Workout/ActiveWorkoutView.swift` | Single keyboard toolbar, filtered focus picker, finishWorkout guard |
| `Xomfit/Views/Workout/WorkoutFocusView.swift` | Safe area padding, exercise transition animation |
| `Xomfit/Models/XomfitWidgetAttributes.swift` | Added `restEndDate` to ContentState |
| `XomfitWidget/XomfitWidgetAttributes.swift` | Added `restEndDate` to ContentState (mirror) |
| `XomfitWidget/XomfitWidgetLiveActivity.swift` | Real-time timer style for elapsed + rest countdown |
| `Xomfit/ViewModels/WorkoutLoggerViewModel.swift` | Pass restEndDate, update frequency, extend timer updates |
