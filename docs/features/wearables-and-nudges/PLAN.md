# Plan: Wearable Haptics, Garmin Data, and Push Nudges

**Status**: Draft
**Created**: 2026-08-22
**Branch**: TBD (three separate branches — see phases)

## Context

Four asks came out of one session. Two were bugs and are already fixed on
`polish/transition-card-next-emphasis`; the other three are features that share
one hard dependency (the watch app), so they're planned together here.

### Already fixed (this branch, not in this plan)

| Bug | Root cause | Fix |
|---|---|---|
| Rest timer invisible in focus ("zoomed in") mode | `RestTimerBar` was a `.safeAreaInset` on the *list screen inside* the `NavigationStack`. Focus mode became a real push in `dc8422c`, so the pushed screen covered it. Timer kept ticking; the bar just wasn't on screen. | Moved the inset onto the `NavigationStack` itself. |
| Exercise-complete card skipped in focus mode, then ambushed the lifter back in list mode | Same shape: the transition overlay lived inside the list's `ZStack`. `completeSet` set `showExerciseTransition = true` with nothing on screen to render it, so focus silently auto-advanced. Popping back revealed the stale card. | Overlay hoisted to the `NavigationStack`, plus `completeSet` now clears `showExerciseTransition` on entry so a stale card can never resurface. |

The general lesson: **anything that must span list + focus mode belongs on the
`NavigationStack`, not inside it.** Worth checking the same for any future
overlay (PR celebration banner and the first-run tutorial are still inside).

---

## Phase 1 — Ship the watch app (blocking dependency)

Nothing wearable-haptic works until `XomfitWatch` actually ships. The target is
written and compiles but is **not embedded** in the iOS app, so it has never
reached a device.

This is already planned in detail at
`docs/features/watch-embed-auto-cardio/PLAN.md` (Phase 1). Not re-specced here.
Known blockers as of 2026-08-21: no watchOS simulator runtime installed, no
`Embed Watch Content` copy phase, no watch entitlements file, and
`WatchWorkoutSessionManager` is compiled but never instantiated.

**Do this first.** Phases 2 and 4 below depend on it.

---

## Phase 2 — Rest-timer haptics on the wrist

**Goal**: the watch buzzes for the last 5 seconds of rest, then gives one longer
"go lift" buzz at zero. User-disableable. Apple Watch only (see Garmin below).

Today the phone already fires a single `UINotificationFeedbackGenerator`
`.success` at zero (`ActiveWorkoutView.onReceive(timer)`, guarded by
`restTimerHapticFired`). Nothing reaches the wrist.

| File | Change |
|---|---|
| `Xomfit/Services/WatchSyncService.swift` | New `sendRestHaptic(_ kind:)` message. Fire-and-forget `sendMessage` — do **not** fall back to `transferUserInfo`, a haptic delivered 40s late is worse than none. |
| `Xomfit/ViewModels/WorkoutLoggerViewModel.swift` | In `tickRestTimer`, fire on the 5→1 countdown edge and once at `<= 0`. Needs a `lastHapticSecond: Int?` so a tick that skips a second (background/foreground) doesn't double-fire or silently skip. |
| `XomfitWatch/WatchSessionStore.swift` | Receive the message, call `WKInterfaceDevice.current().play(.notification)` for the countdown ticks and `.success` (or `.stop`, needs a feel test) for the zero buzz. |
| `Xomfit/Views/Profile/SettingsView.swift` | `@AppStorage("wristRestHaptics")`, default **on**. Gate it in the VM, not the watch, so we don't send messages nobody wants. |

### The "3 seconds of buzzing" ask — pushback

watchOS gives you discrete `WKHapticType` pulses, not a duration you control.
There is no supported way to vibrate continuously for 3 seconds. The closest
honest options:

- **Repeat `.notification` ~3× at 400ms** — approximates a long buzz. Recommended.
- **`.success` once** — one distinct double-tap pattern, clearly different from
  the countdown ticks.

Anything longer means a timed loop of `play()` calls, which drains battery and
reads as broken if the watch is already buzzing for something else. Recommend
starting with the 3× repeat and tuning by feel.

**Open question for Dominick**: should overtime (past zero) keep nudging, or is
one buzz at zero the end of it? Current phone behavior is one-and-done.

---

## Phase 3 — Garmin data (the real answer)

**There is no Garmin integration and there is deliberately not going to be one.**
The strategy is documented in `Xomfit/Xomfit.entitlements` and
`Xomfit/Services/HealthKitService.swift`: Garmin Connect (and Whoop, Polar,
Zwift) write into Apple Health, so reading HealthKit covers every vendor at once.
A direct Garmin Connect API integration needs an approved partnership and would
cover strictly less.

So "Garmin doesn't show my stuff" is one of four things, in likelihood order:

1. **Nothing auto-imports.** The only path is a manual "Import from Health"
   button in `CardioListView`. If you never tapped it, nothing is there.
   → **Fix: Phase 2 of `watch-embed-auto-cardio/PLAN.md`** (`HKObserverQuery` +
   background delivery + persisted anchor + opt-in toggle).
2. **The 30-day window.** `CardioService.importFromHealth` defaults to
   `since: -30 days`. Older Garmin activities are invisible even after a manual
   import. → Offer an "import everything" first-run path.
3. **Read permission was never granted.** HealthKit never reports read-permission
   status, so a denied grant is indistinguishable from "no data" — the app shows
   "Nothing new to import" either way. → Detect "authorized but zero workouts
   ever" and surface a "check Health → Sources → XomFit" hint.
4. **Strength training is filtered out on purpose.** `HealthKitService.session(from:)`
   returns nil for anything `CardioModality.from(healthKitType:)` doesn't map —
   which is every non-cardio type. If your Garmin lifting sessions are the
   missing "stuff", that's by design and is a separate feature, not a bug.

**Also**: Garmin cannot receive our rest-timer haptics. There is no path to a
Garmin wrist without a Connect IQ companion app (a separate Monkey C codebase and
store listing). Out of scope; say so plainly in any UI copy.

---

## Phase 4 — Push notifications: in-workout and come-back nudges

### 4a. The nudge logic already exists and is half-wired

`TrainingNudgeService.nudgeForLaunch` already computes "you're under-training
legs" via `GoalBaseline` / `AdaptiveBaseline`, with once-per-day gating,
cold-start suppression (< 8 workouts), and logged-today suppression. It's real,
tested logic.

**But it only fires as an in-app toast on launch, from `MainTabView`.** If you
don't open the app, you never get nudged — which is exactly the case a come-back
nudge exists for.

Separately, `NotificationPreferences` has `workoutReminders`, `reminderHour`,
`reminderMinute`, `reminderDays`, and `SettingsView` has a
`workoutRemindersEnabled` toggle — **and nothing anywhere schedules a
notification from any of them.** The toggle is dead UI today.

| File | Change |
|---|---|
| `Xomfit/Services/NotificationService.swift` | `scheduleTrainingNudge(_ muscle: UnderTrainedMuscle, at:)` and `scheduleWorkoutReminder(prefs:)` using `UNCalendarNotificationTrigger`. Local notifications — **no server, no `send-push` work needed.** |
| `Xomfit/Services/TrainingNudgeService.swift` | Extract the decision from the launch-gated wrapper so it can be evaluated on a background refresh, not just on launch. Keep `nudgeForLaunch` as-is so `MainTabView` is untouched. |
| `Xomfit/XomfitApp.swift` | On `scenePhase == .background`, re-evaluate and (re)schedule the next 7 days of nudges. Cancel and rebuild rather than diffing. |
| `Xomfit/Views/Profile/SettingsView.swift` | Wire `workoutRemindersEnabled` to actually schedule/cancel. |

**Recommendation: local notifications, not push.** Everything here is computable
on-device from data the app already has. Routing it through APNs means a Supabase
cron, a device-token round trip, and a whole class of delivery failures — for
zero added capability. The existing `send-push` function stays for social
notifications, where the trigger genuinely is server-side.

### 4b. "Push notifications while working out" — needs scoping

This one is ambiguous and I'm not guessing. Candidates:

- **Rest-timer-done notification** — already exists
  (`scheduleRestTimerNotification`). If this isn't firing for you, that's a bug
  to chase, not a feature to build.
- **A Live Activity / Dynamic Island** — also already exists
  (`updateLiveActivity`, `XomfitWidget`).
- **"You've been resting 4 minutes, get back to it"** — a real gap. Nothing
  fires on rest overtime beyond the one haptic.
- **Friend activity while you lift** — exists, but arguably should be
  *suppressed* mid-workout rather than added to.

**Blocking question for Dominick**: which of these did you mean?

---

## Sequencing

1. Ship the two view-sync bug fixes (**done**, needs your device test).
2. Phase 4a — pure app code, no dependencies, highest value per hour. Makes a
   dead settings toggle real.
3. Phase 3 — auto cardio import. Makes Garmin data actually appear.
4. Phase 1 — embed the watch app. Carries build/deploy risk; keep it its own PR.
5. Phase 2 — wrist haptics. Only meaningful after 4.

## Out of Scope

- Direct Garmin Connect / Garmin Health API integration (needs partnership approval).
- Garmin Connect IQ companion app for haptics (separate Monkey C codebase).
- Pushing XomFit workouts *to* a watch.
- Importing strength training from Health (deliberately filtered today).
