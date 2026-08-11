# XomFit Overhaul — Audit & Roadmap

**Date:** 2026-08-11
**Branch at audit:** `master` @ `a662df9`
**Status:** Draft — awaiting track selection

---

## 1. What's In Flight

### Uncommitted on `master` (6 files, 121 insertions)
| File | What it is |
|---|---|
| `Services/SyncManager.swift` | Implements `.postFeedItem` retry (was a no-op stub) — #386 |
| `ViewModels/WorkoutLoggerViewModel.swift` | Queues feed post on failure instead of swallowing it — #386 |
| `Views/Feed/FeedCommentsView.swift` | +11 lines |
| `Views/Feed/FeedView.swift` | +5 lines |
| `Views/Workout/SetRowView.swift` | +63 lines |
| `Views/Workout/WorkoutBuilderView.swift` | ±43 lines |

These are real fixes sitting on a protected branch with no branch/PR. **Needs a home before anything else starts.**

### Open PRs
| PR | Title | State |
|---|---|---|
| #468 | PR celebration throughout workout flow | CLEAN — mergeable |
| #467 | kg/lbs toggle for weight entry | CLEAN — mergeable |
| #466 | Fix template save buttons (#465) | CLEAN — mergeable |
| #457 | WorkoutFocusView scroll | **CONFLICTING** — stale since 2026-06-10 |
| #438 | Rebuild EditableExerciseRow spacing | **CONFLICTING** — stale since 2026-05-30 |

### Open Issues
`#470` kg/lbs toggle · `#469` PR celebration · `#465` template save · `#464` triage 21 quarantined tests · `#389` SoundCloud · `#388` stretches not curated · `#387` finish sheet soundtrack/location · `#386` feed broken · `#385` profile photo propagation

### Debt
- **9 stashes**, oldest from the `develop` era. Most are almost certainly dead.
- 21 quarantined stale test files (#464).
- ~30 stale local/remote branches.

---

## 2. Root Causes Found

These are verified in code, not guesses. Several of your complaints trace to the same few defects.

### 2.1 🔴 Workout saves silently drop half the model

`WorkoutService.saveToSupabase()` (`Services/WorkoutService.swift:490`) writes flattened payloads that omit fields the app model carries.

**`WorkoutExerciseInsertPayload` (`:145`) persists only** `id, workout_id, exercise_id, exercise_name, sort_order`.
**Dropped every save:**
- `selectedGrip`
- `selectedAttachment`  ← *"doesn't keep track of diff weights for diff attachments"*
- `selectedPosition`
- `selectedLaterality`  ← breaks volume math on reload
- `supersetGroupId`     ← supersets vanish
- `restSeconds`
- `notes`

**`WorkoutSetInsertPayload` (`:158`) persists only** `id, workout_exercise_id, set_number, weight, reps, rpe, is_completed, is_pr, completed_at`.
**Dropped every save:**
- `weightMode` (`.total` / `.perSide`) ← **a 25 lb-per-side set reloads as 25 lb total; volume halves**
- `isDropSet`
- `videoLocalURL` / `videoRemoteURL`

`buildWorkout(from:)` (`:575`) reconstructs `WorkoutSet` with 7 of 11 fields, so the loss is symmetric — nothing recovers it.

**Why it feels intermittent:** the local UserDefaults cache stores the *full* JSON-encoded model, so everything looks correct until the cache is repopulated from Supabase. Then weights change under you. This is your *"recent lift weights aren't saving correctly"* bug.

### 2.2 🔴 Partial writes on save failure

`saveToSupabase` upserts **one row per network round trip** in nested loops — one call per exercise, one per set. A 6-exercise / 24-set workout is 31 sequential round trips. If trip #18 throws:
- The workout row and 17 child rows are already committed.
- The whole workout is queued for retry via `.saveWorkout`.
- Retry uses `saveWorkout` (upsert-only), **not** `updateWorkout` (delete-then-write) — so orphans survive.
- If the app is killed before retry, the remaining sets are gone from the server permanently.

### 2.3 🔴 PRs are keyed wrong and fail silently

`PRService.checkForPR()` (`Services/PRService.swift:55`):
- Matches on `exercise_id` **+ exact rep count**. 225×5 after a previous 225×6 registers as a *new PR* — a strictly worse set. Meanwhile 230×5 after 225×6 doesn't compare against the better lift at all.
- No estimated-1RM comparison, even though `WorkoutSet.estimated1RM` and `Exercise.estimateMax` (Epley) already exist and are unused here.
- `catch { return nil }` with the comment *"PR detection is non-critical — fail silently."* Any network blip = PR silently never recorded, no log, no retry, no queue. This is your *"PRs aren't saving"*.
- Not segmented by attachment/grip/laterality — a rope pushdown PR and a straight-bar pushdown PR fight for the same record. (Blocked on 2.1 anyway.)

### 2.4 🔴 Push notifications have never worked

Three independent kill switches, all live:

1. **`Xomfit.entitlements`** → `aps-environment = development`. TestFlight and App Store builds issue **production** APNs tokens. Sandbox APNs rejects them with `BadDeviceToken`.
2. **`supabase/migrations/20260402_push_notification_triggers.sql:41`** → `'use_sandbox', true` hardcoded, with the comment *"flip to false for production"*. Never flipped.
3. Same file, `notify_user()` → `IF edge_url IS NULL OR service_key IS NULL THEN RETURN;`. If `app.settings.supabase_url` / `app.settings.service_role_key` aren't set as project settings, **every push silently no-ops**. Needs verification against the live project, but this is the likely reason nothing has ever arrived.

The iOS side is fine: `AppDelegate` registers, saves tokens to `push_tokens` + `profiles.apns_device_token`, and handles foreground presentation and taps. `send-push/index.ts` looks correct.

**What you're seeing:** local notifications (`scheduleRestTimerNotification`, `scheduleWarmupNotification` — `UNTimeIntervalNotificationTrigger`) fire fine because they're scheduled on-device. Every *remote* notification dies. That's exactly *"notifications only when app is open."*

### 2.5 🔴 The Watch app was never added to the Xcode project

`grep -c "XomfitWatch" Xomfit.xcodeproj/project.pbxproj` → **0**. Targets are `Xomfit`, `XomfitTests`, `XomfitWidgetExtension`.

`XomfitWatch/` has 4 written Swift files. `Xomfit/Services/WatchSyncService.swift` (220 lines) and `Models/WatchWorkoutState.swift` exist on the phone side. `docs/features/apple-watch-256/SETUP.md` documents a required one-time manual Xcode target-add — **it was never done**. The watch app has literally never been compiled or installed.

*(Note: `WatchSyncService` uses `WCSession`. There is no HealthKit workout session anywhere in the codebase, which means no background execution on-watch and no heart rate — see roadmap.)*

### 2.6 🟡 Exercise library is thin and structurally can't hold variations

- 194 exercises in `ExerciseDatabase.swift` (932 lines), hardcoded.
- `Exercise` carries `supportedGrips` / `supportedAttachments` / `supportedPositions` — but they're *optional* and, per 2.1, never persisted with a logged workout.
- No `instructions` beyond a one-line `description` + `tips: [String]`.
- No per-variant history or PR tracking (needs 2.1 + 2.3 fixed first).
- `Models/Animations/ExerciseAnimationLibrary.swift` (287 lines) + `AnimationAssetManager.swift` exist — partial scaffolding for form demos.

### 2.7 🟡 Muscle diagrams exist but are barely used

`Views/Common/BodySilhouetteView.swift` (399 lines) already renders a body map. Used in exactly two places: `Profile/FullBodyHeatmapView.swift` and `Workout/ExerciseDetailSheet.swift`. Not in the exercise picker, not in workout summaries, not in the finish sheet, not on templates.

### 2.8 🟡 The in-workout list ↔ focus flow is two disconnected screens

- `ActiveWorkoutView.swift` — **2,448 lines**
- `WorkoutFocusView.swift` — **1,067 lines**
- `WorkoutDetailView.swift` — 1,445 lines

Two separately-built screens with no shared transition, which is why moving between overview and zoomed-in *"feels disjointed."* Note PR #457 (`fix/focus-view-scroll`) and the recently-merged #462/#463 scroll fixes are all patching symptoms of the same overgrown views. There have been **at least 5 separate branches** fighting scroll bugs in this area.

### 2.9 🟢 Exercise levels — net new

Nothing exists. Closest neighbors: `BadgeSystem.swift` / `BadgeCatalog.swift` (achievement badges, not strength tiers) and `UserFitnessProfile.swift` (has novice/intermediate/elite language for programming, not per-exercise ranks).

---

## 3. Proposed Roadmap

Ordered by dependency, not excitement. **Track 1 is non-negotiable** — Tracks 3–5 all write data that Track 1 currently throws away.

### Track 0 — Clear the board (½ day)
- Move the 6 uncommitted files to a branch, PR, merge.
- Merge #466, #467, #468 (all clean).
- Close or rebase #457 and #438 — both conflicting and 2+ months stale. #457 likely gets superseded by Track 5.
- Drop dead stashes; prune merged branches.

### Track 1 — Fix the data layer 🔴 (2–3 days) — **blocks everything else**
1. Add migration: `workout_exercises` gains `selected_grip`, `selected_attachment`, `selected_position`, `selected_laterality`, `superset_group_id`, `rest_seconds`, `notes`. `workout_sets` gains `weight_mode`, `is_drop_set`, `video_url`.
2. Extend both insert payloads + `buildWorkout(from:)` to round-trip every field. Add a round-trip test.
3. Replace the nested per-row upsert loops with **batch upserts** (one call for all exercises, one for all sets). Kills the partial-write window and cuts 31 round trips to 3.
4. Route retries through `updateWorkout` (delete-then-write) so orphans can't survive.
5. Rewrite `checkForPR`: compare on **estimated 1RM** across all rep ranges, keep per-rep-range bests as a secondary record, segment by variant key (`exercise_id` + attachment + grip + laterality). Stop swallowing errors — log and enqueue via `SyncManager`.

### Track 2 — Make notifications actually deliver 🔴 (1 day)
1. `aps-environment` → `production` (works for both dev and TestFlight when signed correctly).
2. Drive `use_sandbox` from build config instead of hardcoding `true`.
3. Verify `app.settings.supabase_url` / `service_role_key` are set on the live project; fail loudly (log to a table) instead of silent `RETURN`.
4. End-to-end test on a real device from a TestFlight build.
5. **Then** add in-app PR/badge notifications on top — they're worthless until delivery works.

### Track 3 — Apple Watch, for real 🔴 (2–4 days)
1. Do the one-time Xcode target add from `docs/features/apple-watch-256/SETUP.md`, commit the `.pbxproj`.
2. Verify `WCSession` pairing actually reaches the phone.
3. Add an `HKWorkoutSession` — without it the watch app suspends in the background and you get no heart rate. This is the difference between a toy and a real gym watch app.
4. Watch-side set logging that syncs back.

### Track 4 — Exercise system overhaul 🟡 (4–6 days)
1. Expand the library — target 400+, prioritizing variations of what you already lift.
2. Structured `instructions: [String]` (setup / execution / common mistakes) replacing the one-line description.
3. Per-variant history + PRs surfaced in the exercise detail sheet *(depends on Track 1)*.
4. Wire `BodySilhouetteView` into the exercise picker, workout summary, finish sheet, and template cards — the component already exists, it's just not used.
5. Form demos — decide between the existing `ExerciseAnimationLibrary` scaffolding vs. licensed illustration/video. Needs a research pass.

### Track 5 — In-workout UX rebuild 🟡 (5–8 days)
1. Unify overview ↔ focus into one screen with a real transition (matched geometry / scroll-driven zoom) rather than two screens.
2. Decompose `ActiveWorkoutView` (2,448 lines) — this is why every scroll fix breaks something else.
3. Rework the exercise list: clearer set state, current-exercise emphasis, obvious next action.
4. This should absorb and close #457.

### Track 6 — Strength levels 🟢 (3–5 days) — the fun one
Bronze → Silver → Gold → Diamond → Olympian → God, per exercise.

- Thresholds from **bodyweight-relative strength standards**, adjusted by sex and age (the Symmetric Strength / Strength Level model). Requires bodyweight — `BodyMeasurement.swift` / `BodyComposition.swift` already exist.
- Rank on **estimated 1RM**, so any rep range counts *(depends on Track 1's e1RM PR work)*.
- Show next-tier target weight on the exercise card — that's the hook: *"92 lb from Gold."*
- Tier-up celebration reusing the #468 PR celebration work.
- Profile display: tier distribution across major lifts.
- **Design question to settle first:** do tiers apply to every exercise (needs 194+ threshold tables — a large data problem) or to a curated set of ~20 benchmark lifts? Strong recommendation: **start with the benchmark set.**

---

## 4. Recommended Sequence

```
Track 0  ──►  Track 1  ──┬──►  Track 6  (levels — needs e1RM PRs)
  (½d)        (2-3d)     │
                         ├──►  Track 4  (exercises — needs variant persistence)
Track 2  ────────────────┘     
  (1d)  ── parallel, independent

Track 3  ── parallel, independent
  (2-4d)

Track 5  ── after Track 1; big, do it as its own epic
  (5-8d)
```

**Suggested first move:** Track 0 + Track 1 together. That's ~3 days and it fixes the "app is lying to me about my lifts" problem, which is the one actively costing you trust in your own data. Track 2 can run alongside since it touches nothing Track 1 touches.

---

## 5. Open Questions

1. **Levels scope** — all 194 exercises, or ~20 benchmark lifts? (Recommend: benchmark lifts.)
2. **Form demos** — build on `ExerciseAnimationLibrary`, license illustrations, or embed video? Needs `/research`.
3. **Watch scope** — mirror-only (see current set on wrist) or full standalone logging?
4. **Design refresh** — you mentioned wanting a newer feel. Is that a full design-system pass (`Theme.swift` + all `Xom*` components), or does the in-workout rebuild in Track 5 cover enough of what's bothering you?
5. Is Supabase `app.settings.*` configured on the live project? Determines whether 2.4 is a 1-hour fix or a half-day.
