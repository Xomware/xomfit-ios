# Garmin Watch Rework

**Status:** Draft
**Repos:** `xomfit-ios`, `xomfit-garmin`

## The asks

1. Phone→watch feels disjointed; watch doesn't update right away
2. Hard to navigate; no distinct buttons
3. Number entry should work like a phone keypad
4. Scrolling is bad
5. Got out of the workout with no way to reopen the watch app
6. Use Garmin's physical stop/pause buttons
7. Main view = weight/reps entry → enter → rest timer on the same screen → "Lift" → back to entry
8. A view of all the workouts
9. A way to move to next and choose what's next

---

## Phase 1 — Sync (root cause, do first)

The watch push is inside `updateLiveActivity()`, behind
`guard let activity = liveActivity else { return }`. When no Live Activity
exists — disabled in Settings, `Activity.request` threw, or the workout ended
and set it nil — **neither watch receives anything**. That is the disjointedness.

- **1a.** Extract the watch broadcast into its own `pushToWatches()`, called
  independently of the Live Activity. The two have nothing to do with each other.
- **1b.** Drive it from a 1s timer while a workout is active, so the rest
  countdown and elapsed time advance on their own rather than riding whatever
  incidental state change happens next.
- **1c.** Coalesce: skip a send when the payload is unchanged apart from
  elapsed seconds and nothing is resting. The device mailbox is small.

**Test:** a fake clock advancing 1s at a time produces one push per second while
resting, and no pushes when idle and unchanged.

## Phase 2 — Re-entry and physical buttons

- **2a.** Phone-side "Open on watch" action, plus auto re-open when the lifter
  logs a set from the phone. `requestOpenOnWatch()` already exists and is unused
  outside workout start.
- **2b.** Add a Garmin **glance** so the app is reachable from the watch face
  without hunting through the app list.
- **2c.** Map the physical keys: Start/Stop confirms the set and starts rest;
  a long press pauses. Back steps pages rather than exiting.
- **2d.** Guard the exit path: `onBack` at the top level asks before leaving a
  running workout instead of dropping straight out.

## Phase 3 — Main screen state machine

One page that changes shape, not several pages to swipe between:

```
ENTER            RESTING
┌──────────┐     ┌──────────┐
│  185 lb  │     │   1:30   │
│  8 reps  │ --> │ ▓▓▓▓░░░░ │
│ [DONE ]  │     │ [ LIFT ] │
└──────────┘     └──────────┘
      ^                │
      └────────────────┘
```

- **3a.** `WorkoutView` becomes a two-state machine (ENTER / RESTING) driven by
  `state.restRemaining`.
- **3b.** Weight and reps are tappable fields with visible borders — the current
  screen has no drawn affordance, which is why buttons are not findable.
- **3c.** One primary action button at the bottom, large, labelled for the state.

## Phase 4 — Keypad number entry

Replace the up/down stepper in `SetEditView` with a 10-key pad.

- **4a.** 3×4 grid, digits + delete + confirm. Sized so each key clears the
  minimum touch target on a 45mm round screen; corner keys inset for the bezel.
- **4b.** Typed digits accumulate left-to-right like a phone.
- **4c.** Keep long-press-to-clear.

**Test:** every key rect stays inside the circular screen and no two overlap —
the same geometry test used for the trend plot.

## Phase 5 — Plan navigation

- **5a.** `PlanView` becomes a scrollable list of every exercise with its set
  progress, using the native list scroll rather than fixed rows.
- **5b.** Select an exercise to jump to it; the phone owns the change and echoes
  it back, so the two cannot disagree.
- **5c.** "Next exercise" as a first-class action on the main screen.

---

## Open question

"A view of all the workouts" is ambiguous — see the question asked alongside
this plan. Phase 5 assumes *every exercise in the current session*.

## Sequencing

Phase 1 alone will make the watch feel connected, and is independent of the UI
work. Phases 2-5 are ordered by how often they bite: re-entry (stranded, no way
back), then the main screen, then entry, then navigation.
