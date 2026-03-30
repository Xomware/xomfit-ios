# Plan: Workout Cloud Sync

**Status**: Ready
**Created**: 2026-03-30
**Last updated**: 2026-03-30

## Summary
Workouts currently persist only in UserDefaults, meaning they are device-local and will be lost on reinstall. This feature adds Supabase persistence for all workout CRUD operations while keeping UserDefaults as a local cache and offline fallback. Success = every new workout lands in Supabase, fetches pull from Supabase first, and the app degrades gracefully when offline.

## Approach
Write-through cache pattern: save locally first (instant), then push to Supabase (async, fire-and-don't-block). Fetches try Supabase first and update the local cache on success; fall back to cache on failure. This matches how PRService and FeedService already work in the codebase. No migration of existing UserDefaults data in v1 -- only new workouts get synced.

## Affected Files / Components
| File / Component | Change | Why |
|-----------------|--------|-----|
| `Xomfit/Services/WorkoutService.swift` | Major rewrite: add Supabase row types, insert/fetch/delete via Supabase, cache-first fallback | Core of the feature |
| `Xomfit/Views/Workout/WorkoutView.swift` | Switch `loadWorkouts()` to async via `.task`, make delete async | Callers must await new async APIs |
| `Xomfit/ViewModels/ProgressViewModel.swift` | Await `fetchWorkouts(userId:)` | Already async context, minimal change |
| `Xomfit/ViewModels/WorkoutLoggerViewModel.swift` | No change needed | Already calls `saveWorkout` with `try await` |

## Implementation Steps

### Step 1 -- Add Supabase row types to WorkoutService
- [ ] Add `WorkoutRow` (Codable, snake_case CodingKeys) mapping to `workouts` table columns: `id`, `user_id`, `name`, `start_time`, `end_time`, `notes`, `created_at`
- [ ] Add `WorkoutExerciseRow` mapping to `workout_exercises`: `id`, `workout_id`, `exercise_id`, `exercise_name`, `sort_order`
- [ ] Add `WorkoutSetRow` mapping to `workout_sets`: `id`, `workout_exercise_id`, `set_number`, `weight`, `reps`, `rpe`, `is_completed`, `is_pr`, `completed_at`
- [ ] Add corresponding insert payload structs (Encodable, snake_case keys) for each row type
- [ ] Follow the same pattern as `PRRow` / `PRInsertPayload` in `PRService.swift`

### Step 2 -- Add Supabase save logic
- [ ] Add private method `saveToSupabase(_ workout: Workout) async throws`
- [ ] Insert into `workouts` table first
- [ ] For each exercise (with index for `sort_order`), insert into `workout_exercises`
- [ ] For each set (with index for `set_number`), insert into `workout_sets`
- [ ] Use `supabase.from("table").insert(payload).execute()` pattern
- [ ] Update public `saveWorkout()` to: (1) save to UserDefaults, (2) call `saveToSupabase`, (3) catch and log Supabase errors without throwing

### Step 3 -- Add Supabase fetch logic
- [ ] Add private method `fetchFromSupabase(userId: String) async throws -> [Workout]`
- [ ] Use nested PostgREST select: `supabase.from("workouts").select("*, workout_exercises(*, workout_sets(*))").eq("user_id", value: userId).order("start_time", ascending: false)`
- [ ] Decode response into a nested Codable struct (or use the row types with nested arrays)
- [ ] Map each `WorkoutExerciseRow` back to `WorkoutExercise` by looking up `exercise_id` in `ExerciseDatabase.all`; if not found, create a minimal `Exercise` from `exercise_name`
- [ ] Map `WorkoutSetRow` to `WorkoutSet`
- [ ] Change `fetchWorkouts(userId:)` to `async`: try Supabase first, on success overwrite UserDefaults cache, on failure fall back to cache
- [ ] Add sync `fetchWorkoutsFromCache(userId:)` that returns UserDefaults data directly (for any caller that truly can't await)

### Step 4 -- Add Supabase delete logic
- [ ] Add private method `deleteFromSupabase(id: String) async throws`
- [ ] Delete from `workout_sets` via join or cascade (check if FK cascade is set; if not, delete sets first, then exercises, then workout)
- [ ] Change `deleteWorkout(id:)` to `async`: delete locally, then attempt Supabase delete, catch and log errors

### Step 5 -- Update WorkoutView
- [ ] Replace `.onAppear { loadWorkouts() }` with `.task { await loadWorkouts() }`
- [ ] Make `loadWorkouts()` async, calling `await WorkoutService.shared.fetchWorkouts(userId:)`
- [ ] Make the `.onDelete` handler call async delete: wrap in `Task { await ... }`
- [ ] Keep `.refreshable { await loadWorkouts() }` (already async-compatible)

### Step 6 -- Update ProgressViewModel
- [ ] On line 52, change `WorkoutService.shared.fetchWorkouts(userId: userId)` to `await WorkoutService.shared.fetchWorkouts(userId: userId)`
- [ ] `loadData` is already `async`, so this is a one-line change

### Step 7 -- Test manually
- [ ] Verify: complete a workout, check Supabase tables for rows
- [ ] Verify: kill app, reopen, workouts load from Supabase
- [ ] Verify: enable airplane mode, complete a workout, confirm it saves locally and doesn't crash
- [ ] Verify: enable airplane mode, fetch workouts, confirm cache fallback works
- [ ] Verify: delete a workout, confirm rows removed from all 3 Supabase tables

## Out of Scope
- Migrating existing UserDefaults workouts to Supabase (v1 starts fresh in cloud)
- Conflict resolution / merge logic for offline edits
- Real-time sync / Supabase Realtime subscriptions
- Background sync or retry queue for failed Supabase writes
- Workout update/edit flow (only save, fetch, delete)

## Risks / Tradeoffs
- **Data loss on failed Supabase write**: Workout exists in UserDefaults but not Supabase. Accepted for v1 -- user still has local data. A retry queue would fix this in v2.
- **Delete desync**: If Supabase delete fails, workout is gone locally but still in cloud. Accepted -- next fetch will re-populate it from Supabase, which is actually self-healing.
- **Nested PostgREST select performance**: Single request with joins is efficient for reasonable workout counts. If a user has thousands of workouts, pagination would be needed. Not a concern for v1.
- **ExerciseDatabase lookup miss**: If `exercise_id` doesn't match `ExerciseDatabase.all`, we create a minimal Exercise. This handles custom exercises or DB changes gracefully.
- **Breaking sync callers**: `fetchWorkouts(userId:)` becomes async. Only 2 call sites (WorkoutView, ProgressViewModel) and both are straightforward to update.

## Open Questions
- [x] FK constraints have `ON DELETE CASCADE` on both `workout_exercises.workout_id` and `workout_sets.workout_exercise_id`. Deleting from `workouts` cascades automatically — Step 4 only needs to delete the workout row.

## Skills / Agents to Use
- **Coder agent**: Execute Steps 1-6 in order. Start with the row types (Step 1) since everything depends on them.
- **Manual QA**: Step 7 requires running on simulator with Supabase connected.
