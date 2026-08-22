# Plan: All-Exercises-Done Prompt + Post-Workout Summary

**Status**: Both items shipped
**Created**: 2026-08-22

## 1. Prompt when every exercise is complete ✅ DONE

Today the transition card is **deliberately suppressed** on the final exercise:

```swift
// WorkoutLoggerViewModel.completeSet
let isFinalExercise = nextExerciseIndex == nil
if !midSupersetRotation && kind != .timedCircuit && !isFinalExercise {
    showExerciseTransition = true
}
```

The comment cites #387: "the user is done and we want them to head straight to
the Finish flow without an extra modal. The existing 'all complete' cue in the
persistent pill / footer is enough."

**This is a direct reversal of that call.** Worth naming so it doesn't get
flip-flopped again: the #387 reasoning assumed the lifter would notice the
footer cue. In practice the session just goes quiet with nothing prompting the
obvious next action.

Change: drop the `isFinalExercise` suppression and give the card a
**workout-complete variant** — Finish Workout (primary) / Add Exercise
(secondary). The "next exercise" row has nothing to point at, so the card can't
be reused verbatim; it needs a distinct state, not a hidden row.

Keep the `midSupersetRotation` and `timedCircuit` suppressions — both still hold.

## 2. Post-finish summary modal ✅ DONE

After the finish sheet saves, the workout currently just ends. Add a summary
modal: duration, total volume, sets, PRs hit, and any milestones earned during
the session.

Depends on `awards-and-strength-levels/PLAN.md`:

- **PRs** — available today (`checkForPR` / `newPR`).
- **Milestones and tier-ups** — do not exist yet as session-scoped events.
  `BadgeEvaluator` computes unlocked badges from full history, with no notion of
  "earned during this workout". Needs a session-scoped diff: snapshot unlocked
  badge ids at workout start, diff at finish.

So build Phase 1 + 2 of the awards plan first, or the summary has nothing to
show beyond volume and time — which the existing history detail view already
covers.

## Outcome

Item 1 was a one-line unsuppression — the card's all-complete state (Add
Exercise / Finish Workout) already existed and was simply unreachable.

Item 2 shipped after the awards work, so it has real achievements to show:
`WorkoutSummary` carries duration, volume, sets, exercises, beat-the-clock
count, this session's PRs and tier promotions, and the badges this workout
pushed over the line.

Badge diffing passes `firstPRDate` and `rankedTiers` identically to both sides,
so the "First PR" and strength-tier badges can never appear in the badge list.
That is deliberate — both already have their own section, and listing a tier
promotion twice reads as a bug.
