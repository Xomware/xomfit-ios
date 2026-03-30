# Plan: Progress Tab

**Status**: Ready
**Created**: 2026-03-30
**Last updated**: 2026-03-30

## Summary
Build out the Progress tab (`XomProgressView`) from its current placeholder state into a full analytics dashboard. The tab will show workout summary stats, lift progression charts, weekly volume trends, muscle group breakdown, and recent PRs. All data comes from existing `WorkoutService` (local) and `PRService` (Supabase) -- no new services needed. Success = a useful, chart-driven progress view that matches the app's dark theme and MVVM patterns.

## Approach
Single ViewModel (`ProgressViewModel`) computes all derived stats from raw workout and PR data. The view uses Swift Charts (`LineMark`, `BarMark`) for visualizations. No new models needed -- `StrengthDataPoint` and related types in `AdvancedStats.swift` already exist. `PRBadgeRow` is currently `private` in `ProfileView.swift`, so we'll extract it to a shared component to avoid duplication.

## Affected Files / Components
| File / Component | Change | Why |
|-----------------|--------|-----|
| `Xomfit/ViewModels/ProgressViewModel.swift` | **New file** | @Observable VM -- loads workouts + PRs, computes summary stats, strength data points, weekly volume, muscle group sets |
| `Xomfit/Views/Progress/XomProgressView.swift` | **Rewrite** | Replace placeholder with full ScrollView layout: summary cards, lift chart, volume chart, muscle breakdown, recent PRs |
| `Xomfit/Views/Shared/PRBadgeRow.swift` | **New file** (extracted) | Move `PRBadgeRow` out of `ProfileView.swift` so both Progress and Profile can use it |
| `Xomfit/Views/Profile/ProfileView.swift` | **Minor edit** | Remove private `PRBadgeRow` struct, import shared version |

## Implementation Steps
- [ ] **Step 1** -- Extract `PRBadgeRow` to `Xomfit/Views/Shared/PRBadgeRow.swift`. Remove the `private` copy from `ProfileView.swift`. Verify ProfileView still builds.
- [ ] **Step 2** -- Create `Xomfit/ViewModels/ProgressViewModel.swift` with:
  - `@Observable @MainActor final class ProgressViewModel`
  - Properties: `isLoading`, `errorMessage`, `totalWorkouts`, `currentStreak`, `totalVolume`, `totalPRs`, `recentPRs: [PersonalRecord]`, `strengthDataPoints: [StrengthDataPoint]`, `weeklyVolumes: [(label: String, volume: Double)]`, `muscleGroupSets: [(group: String, sets: Int)]`, `availableExercises: [String]`, `selectedExercise: String`
  - `func loadData(userId: String) async` -- fetches workouts from `WorkoutService.shared.fetchWorkouts(userId:)` and PRs from `PRService.shared.fetchPRs(userId:)`, then calls private compute methods
  - `private func computeSummary(workouts:prs:)` -- total workouts, total volume, total PRs, current streak (consecutive calendar days with workouts looking back from today, max 7)
  - `private func computeStrengthData(workouts:)` -- for each exercise that appears in workouts, extract best estimated 1RM per workout date as `StrengthDataPoint`. Populate `availableExercises` sorted by frequency desc. Default `selectedExercise` to the most frequent exercise.
  - `private func computeWeeklyVolume(workouts:)` -- bucket workouts into calendar weeks (last 8 weeks), sum `totalVolume` per week. Label format: "Mar 24" (month + day of week start).
  - `private func computeMuscleGroups(workouts:)` -- iterate all exercises in all workouts, count total completed sets per `MuscleGroup`. Sort desc by set count.
  - `var filteredStrengthData: [StrengthDataPoint]` -- computed property filtering `strengthDataPoints` to `selectedExercise`
- [ ] **Step 3** -- Rewrite `Xomfit/Views/Progress/XomProgressView.swift`:
  - `@Environment(AuthService.self) private var authService`
  - `@State private var viewModel = ProgressViewModel()`
  - `userId` computed from `authService.currentUser?.id.uuidString ?? ""`
  - `NavigationStack` > `ZStack` with `Theme.background.ignoresSafeArea()` > conditional on `viewModel.isLoading` / empty / content
  - Loading: `ProgressView().tint(Theme.accent)`
  - Empty (0 workouts): centered message "Log your first workout to see progress here"
  - Content: `ScrollView` > `VStack(spacing: Theme.paddingMedium)` with sections:
    1. **Summary cards** -- `LazyVGrid(columns: 2)` with 4 stat cards (icon, value, label). Total Workouts (dumbbell), Streak (flame), Volume (scalemass), PRs (trophy). Each card uses `.cardStyle()`.
    2. **Lift progression** -- section header "Strength Over Time", `Picker` for exercise (segmented or menu style), `Chart` with `LineMark` + `PointMark` for `filteredStrengthData`. X = date, Y = estimated1RM. Foreground: `Theme.accent`. Wrapped in `.cardStyle()`.
    3. **Weekly volume** -- section header "Weekly Volume", `Chart` with `BarMark`. X = week label, Y = volume. Foreground: `Theme.accent`. Wrapped in `.cardStyle()`.
    4. **Muscle group breakdown** -- section header "Muscle Groups", `Chart` with horizontal `BarMark`. X = sets, Y = muscle group name. Foreground: `Theme.accent`. Wrapped in `.cardStyle()`.
    5. **Recent PRs** -- section header "Recent PRs", `ForEach` over `viewModel.recentPRs` with `PRBadgeRow`. Wrapped in `.cardStyle()`.
  - `.task { await viewModel.loadData(userId: userId) }`
  - `.navigationTitle("Progress")`, `.toolbarColorScheme(.dark, for: .navigationBar)`
- [ ] **Step 4** -- Add `Xomfit/Views/Shared/` group to the Xcode project if not already present (verify the folder exists in the file system).
- [ ] **Step 5** -- Build and test in simulator. Verify: loads with no workouts (empty state), loads with workout data (all charts render), exercise picker switches lift chart, scrolling is smooth.

## Out of Scope
- Backend analytics endpoints or server-side aggregation
- Date range picker / time period filtering (can be added later)
- Export or share functionality
- Workout frequency heatmap (calendar grid) -- future enhancement
- Muscle balance / imbalance analysis
- Animations or transitions between chart states

## Risks / Tradeoffs
- **Performance with large workout history**: All computation is on-device from UserDefaults. For users with hundreds of workouts, the strength data computation could be slow. Mitigation: compute once on load, not on every view update. If needed later, cache computed results.
- **PRBadgeRow extraction**: Changing `ProfileView.swift` introduces a small regression risk. Mitigation: it's a straightforward extraction of a self-contained view -- verify Profile tab still renders.
- **Streak calculation simplicity**: "Consecutive days looking back from today" is simple but won't show historical streaks. Accepted tradeoff for v1.
- **Chart readability on small data sets**: Charts with 1-2 data points look sparse. Accepted -- the tab gets more useful as the user logs more workouts.

## Open Questions
- [x] Exercise picker: **Menu** (compact, supports 10+ exercises)
- [x] Volume formatting: reuse `formattedVolume` pattern from `Workout` — "12.5k" for 1000+, "1.2M" for 1M+

## Skills / Agents to Use
- **Code agent**: Execute steps 1-4 (extraction, ViewModel, View rewrite)
- **iOS standards skill**: Reference for Swift Charts API usage and @Observable patterns
