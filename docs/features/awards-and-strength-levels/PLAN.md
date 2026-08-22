# Plan: Awards, Milestones, and Strength Levels

**Status**: All three phases complete
**Created**: 2026-08-22

## Headline finding

**Bronze / Silver / Gold / Diamond already exists and is fully built.**
`StrengthTier` (`Xomfit/Models/StrengthTier.swift`) ranks every lift against
bodyweight-relative standards — seven tiers: Unranked, Bronze, Silver, Gold,
Diamond, Olympian, God — with per-tier colors, icons and blurbs.
`StrengthLevelService` computes the rank from estimated 1RM, bodyweight, sex and
age, and degrades gracefully when sex/age are missing. `StrengthTierBadge` and a
`StrengthTierDistributionBar` view both exist.

So the ask isn't "build levels." It's **three real gaps**:

| Gap | State |
|---|---|
| Tiers on the profile | **Missing.** `StrengthTier` is only rendered in `ExerciseDetailSheet` and `LifterDetailsSheet`. `StrengthLevelService.tierDistribution(from:)` and `StrengthTierDistributionBar` are both already written and **not used anywhere.** |
| A "you hit Diamond" moment | **Missing.** `PRCelebrationBanner` fires for a PR, but crossing a tier boundary is silent. |
| More badges | **Thin.** `BadgeCatalog.all` has ~6 entries across only 5 criteria kinds: `firstWorkout`, `streakDays`, `totalWorkouts`, `totalVolumeLbs`, `firstPR`. |

## Phase 1 — Surface the tiers on the profile ✅ DONE

Almost entirely wiring. Two finished components are sitting unused.

| File | Change |
|---|---|
| `Xomfit/Views/Profile/…` (alongside `BadgesSection`) | New `StrengthSection`: `StrengthTierDistributionBar` fed by `StrengthLevelService.tierDistribution(from: prs)`, plus the lifter's top-ranked lifts. |
| `Xomfit/Views/Profile/LifterDetailsSheet.swift` | Already collects bodyweight/sex/age. Link to it from the new section when the rank is provisional, so an unranked profile has a next action. |

**Risk to call out**: without bodyweight + sex + age the ranks are provisional and
can be visibly wrong. The service already reports this — the profile UI must show
"provisional" rather than a confident Gold, or the whole feature loses trust on
first view.

## Phase 2 — Tier-up celebration ✅ DONE

New tier is only knowable by comparing against the previous tier, so this needs
persistence — there is no stored "best tier per exercise" today.

| File | Change |
|---|---|
| `Xomfit/Models/PersonalRecord.swift` / a new `TierProgressStore` | Persist highest tier reached per exercise id. UserDefaults is fine — it's derivable from PR history, so losing it is recoverable. |
| `Xomfit/ViewModels/WorkoutLoggerViewModel.swift` | `checkForPR` already runs async after every completed set and is the natural hook. Compare new rank against stored best; on an increase, raise a tier-up event. |
| `Xomfit/Views/Workout/ActiveWorkoutView.swift` | Reuse the `PRCelebrationBanner` slot — **and attach it to the `NavigationStack`, not inside it**, or it repeats the focus-mode bug just fixed (see `wearables-and-nudges/PLAN.md`). |

Copy: "Diamond on Bench Press 💎".

**Decided**: replace, not queue. A tier-up supersedes the PR that caused it,
matched on exercise id so arrival order doesn't matter (the PR check is a network
round trip; the tier check is local and lands first). Celebrations are dropped
rather than queued — two banners back-to-back mid-set is noise.

## Phase 3 — More badges ✅ DONE

### 3a. Badges that need no new data

`BadgeEvaluator.unlocked(for:firstPRDate:)` reads `[Workout]` only. These are pure
additions to `BadgeCatalog.all` plus a criteria case each:

- Volume milestones — 100k / 500k / 1M lbs lifted (`totalVolumeLbs` case exists already).
- Workout-count milestones — 50 / 100 / 250 / 500.
- Streak milestones — 60 / 100 (`streakDays` exists).
- Tier-based: "First Gold", "First Diamond", "Diamond in three lifts". Needs a
  new `.tierReached(StrengthTier, count: Int)` criteria and PR data passed into
  the evaluator.
- Time-of-day / consistency: "Ten 6am workouts", "Trained every week for a month".

### 3b. "Beat the rest timer 10 times" — needs new tracking

This one is **not** derivable from any existing data. Nothing records whether a
set was completed before rest expired. `WorkoutSet` has `completedAt` but no
relationship to the rest window.

Two options:

1. **Persist a counter.** `completeSet` already knows `isRestTimerActive` and
   `restTimeRemaining` at the moment of completion — increment a
   `beatTheClock` count when a set completes with rest still running. Cheap, but
   the badge is then unauditable and unrecoverable if the counter is lost.
2. **Store it on the set.** Add `beatRestTimer: Bool` to `WorkoutSet`, persist it
   through the backend. Costs a schema change on `xomfit-backend`, but the badge
   becomes derivable from history like every other one.

**Chose option 2.** Migration `20260822_beat_rest_timer.sql`; `WorkoutSet.beatRestTimer`.

Original reasoning: — every other badge is a pure function of workout history,
and one counter that isn't breaks that property. But it's a backend change, so
flag it before starting.

**Also worth questioning**: rewarding "finish your set before rest ends" nudges
toward cutting rest short, which is bad training. Consider "10 sets started
within 15s of rest ending" — same behavior (be ready), better incentive.

## Sequencing

1. ~~Phase 1 — pure wiring of finished components.~~ Done.
2. ~~Phase 3a — additive catalog entries.~~ Done. Catalog 10 → 26 badges.
3. ~~Phase 2 — tier-up moment.~~ Done.
4. ~~Phase 3b.~~ Done — persisted on the set, counts forward from the migration.

## Open questions for Dominick

- Tier-up vs PR banner when both fire: replace, or queue?
- `beatRestTimer` as a local counter or a persisted set field (backend change)?
- Should tiers be visible on *other people's* profiles, or self only? That's a
  social/comparison design call, not a technical one.
