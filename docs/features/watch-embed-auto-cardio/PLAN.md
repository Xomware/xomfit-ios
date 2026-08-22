# Plan: Ship the Watch App + Opt-In Auto Cardio Import

**Status**: Phase 2 partially shipped (foreground auto-import). Phase 1 not started.
**Created**: 2026-08-21
**Last updated**: 2026-08-21
**Issue**: TBD (two issues — one per phase)
**Branches**: `feature/N-watch-embed`, `feature/N-auto-cardio-import`

## Summary

Two independent, shippable slices that were scoped out of a "Garmin integration"
question. Neither needs Garmin.

1. **Ship the watch app.** `XomfitWatch/` is fully written — elapsed timer, rest
   countdown ring, "Set N/M", Done Set round-trip — and the iOS side
   (`WatchSyncService`) is wired into `XomfitApp` and `WorkoutLoggerViewModel`.
   The target exists and compiles, but is **not embedded** in the iOS app, so it
   has never shipped to a device.
2. **Opt-in auto cardio import.** `HealthKitService.importCardioSessions` +
   `CardioService.importFromHealth` already work, but only behind a manual button
   in `CardioListView`. Make it automatic, in the background, behind a setting
   that defaults to off.

Garmin (and Whoop, Polar, Zwift) ride along for free on #2: Garmin Connect writes
activities, calories and HR into Apple Health, so reading HealthKit covers every
vendor. This is already the documented strategy — see the comment in
`Xomfit/Xomfit.entitlements`. **No direct Garmin API work is in scope.**

Success:
- A paired Apple Watch shows the live lifting session with a running timer, and
  the app stays awake through a full workout with the wrist down.
- A run recorded on a Garmin (or Apple Watch, or Strava) appears in XomFit's
  cardio list without the user opening the app or tapping import — but only if
  they turned the setting on.

## Approach

Two phases, two PRs, in this order. Phase 1 carries build-system and deploy risk;
Phase 2 is ordinary app code. Don't bundle them — if the archive breaks, the
blast radius should be one PR.

Phase 1 is *mostly* not code. The one real code gap: `WatchWorkoutSessionManager`
is in the target's Compile Sources but is never instantiated by
`XomfitWatchApp` — nothing calls `start()`. Without a running `HKWorkoutSession`
watchOS suspends the app on wrist-down and the timer stops advancing, which is
the entire point of the file. That gets wired before the target ships.

Phase 2 layers three things onto the existing import path: an `HKObserverQuery`
with background delivery, an `HKAnchoredObjectQuery` with a persisted anchor so
each sample is seen exactly once, and an `@AppStorage` opt-in toggle. The
existing manual import button stays as-is.

### Known blockers, current state (verified 2026-08-21)

| Thing | State |
|---|---|
| Disk free | **11 GB** — the 2.5 GB that blocked this in May is resolved (`.claude/worktrees` still holds 13 GB if more is needed) |
| watchOS SDK | Installed (26.2) |
| watchOS **simulator runtime** | **Not installed** — `xcrun simctl list runtimes` shows iOS 26.2 only. This is the actual blocker. |
| `XomfitWatch` target | Exists, `productType` application, all 5 sources in Compile Sources, `WKApplication` + `WKCompanionAppBundleIdentifier` + Health usage strings already set |
| Embed phase | **Missing** — no `Embed Watch Content` copy phase on the `Xomfit` target, no `Xomfit → XomfitWatch` dependency |
| Watch entitlements | **Missing** — no `CODE_SIGN_ENTITLEMENTS`, so no HealthKit entitlement on watchOS |
| Watch background modes | **Missing** — no `WKBackgroundModes = workout-processing` |

## Affected Files / Components

### Phase 1 — Watch embed

| File / Component | Change | Why |
|---|---|---|
| `Xomfit.xcodeproj/project.pbxproj` | Add `PBXTargetDependency` `Xomfit → XomfitWatch`; add an `Embed Watch Content` `PBXCopyFilesBuildPhase` (`dstSubfolderSpec = 16`, `dstPath = "$(CONTENTS_FOLDER_PATH)/Watch"`) containing `XomfitWatch.app` | Without both, the watch app never lands in the .ipa |
| `XomfitWatch/XomfitWatch.entitlements` (new) | `com.apple.developer.healthkit` + empty `healthkit.access` array. Wire via `CODE_SIGN_ENTITLEMENTS` on both watch build configs | `HKWorkoutSession` fails to construct without the entitlement on watchOS |
| `Xomfit.xcodeproj` watch build settings | Add `WKBackgroundModes` = `workout-processing`. Target uses `GENERATE_INFOPLIST_FILE = YES`, so try `INFOPLIST_KEY_WKBackgroundModes` first; if Xcode doesn't expose that key, check in `XomfitWatch/Info.plist` and set `INFOPLIST_FILE` instead | Without it watchOS kills the session on wrist-down |
| `XomfitWatch/XomfitWatchApp.swift` | Own a `WatchWorkoutSessionManager`, request HK auth on launch, `start()` when `sessionStore.state` first becomes non-nil, `end()` when it goes nil | **The dead-code gap.** File is compiled but nothing constructs it. |
| `XomfitWatch/ContentView.swift` | Optional: render `sessionManager.heartRate` under the elapsed timer | Free once the session runs; the manager already publishes it |
| `docs/features/apple-watch-256/SETUP.md` | Rewrite — it claims the target doesn't exist, which is stale | It's the first doc anyone reads on this |

### Phase 2 — Auto cardio import

| File / Component | Change | Why |
|---|---|---|
| `Xomfit/Xomfit.entitlements` | Add `com.apple.developer.healthkit.background-delivery` | Required for `enableBackgroundDelivery`; without it the call throws |
| `Xomfit/Services/HealthKitService.swift` | Add `startCardioObserver()` / `stopCardioObserver()`, an `HKObserverQuery` on `workoutType()`, `enableBackgroundDelivery(for:frequency:.immediate)`, and an anchored-query fetch `newCardioSessions(userId:)` returning only samples newer than the persisted anchor | Anchor is what makes "auto" idempotent — a date window is not |
| `Xomfit/Services/HealthKitService.swift` | Persist `HKQueryAnchor` to `UserDefaults` under `health.cardioImportAnchor` via `NSKeyedArchiver` (secure coding). **Only advance the anchor after a successful save** | A crash or a missing session mid-import must not silently swallow samples |
| `Xomfit/Services/CardioService.swift` | Change `save` to `.upsert(..., onConflict: "user_id,healthkit_uuid")` (or ignore-duplicates) | Background cold launch has an empty in-memory `sessions` array, so the current `knownUUIDs` pre-filter can't dedupe and every insert hits the unique index as an error |
| `Xomfit/AppDelegate.swift` | On `didFinishLaunchingWithOptions`, call `HealthKitService.shared.startCardioObserverIfEnabled()` | HealthKit **relaunches the app in the background** when data arrives; the root view's `.task` doesn't run in that path, so registration must be in the app delegate |
| `Xomfit/Views/Profile/SettingsView.swift` | New `healthSection` after `notificationsSection`: a toggle bound to `@AppStorage("health.autoImportCardio")` (default `false`) plus footer text | The opt-in |
| `XomFitTests/HealthKitTests.swift` | Extend: anchor archive/unarchive round-trip, opt-in gating, "no user id → anchor not advanced" | Guards the two ways this silently loses data |

## Implementation Steps

### Phase 1 — Ship the watch app

- [ ] **Step 0 — Install the watchOS platform runtime.** This is the blocker, not
      the project file.
      ```bash
      xcodebuild -downloadPlatform watchOS      # ~3.9 GB, 11 GB free as of today
      xcrun simctl list runtimes | grep -i watch
      ```
      If it fails on space, reclaim from `.claude/worktrees` (13 GB of agent
      scratch — **check for uncommitted work first**) or `build/` + `build-rel/`
      (1.6 GB combined, pure output).

- [ ] **Step 1 — Wire the workout session.** In `XomfitWatchApp.swift`, add
      `@State private var sessionManager = WatchWorkoutSessionManager()`, pass it
      into the environment, `await sessionManager.requestAuthorization()` in the
      existing `.task`, and drive `start()`/`end()` off `sessionStore.state`
      transitioning non-nil → nil. `start()` already guards against double-start.
      Keep failures non-fatal per the file's own doc comment.

- [ ] **Step 2 — Watch entitlements + background mode.** Create
      `XomfitWatch/XomfitWatch.entitlements` with `com.apple.developer.healthkit`,
      set `CODE_SIGN_ENTITLEMENTS` on both watch configs, and add
      `WKBackgroundModes = workout-processing`. Verify the generated Info.plist in
      the built product actually contains both keys:
      ```bash
      plutil -p build/Build/Products/Debug-watchos/XomfitWatch.app/Info.plist
      ```

- [ ] **Step 3 — Add the embed phase.** Do this **in Xcode**, not by hand:
      select the `Xomfit` target → General → Frameworks, Libraries, and Embedded
      Content (or the "Embed Watch Content" phase) → add `XomfitWatch.app`. The
      project is `objectVersion = 77` with `fileSystemSynchronizedGroups`; hand-
      editing that pbxproj is how this broke last time. Confirm `SKIP_INSTALL`
      stays `YES` on the watch target (correct for embedded content).

- [ ] **Step 4 — Verify all three build shapes locally before pushing.** The
      Debug simulator build is *not* sufficient evidence — that's exactly the gap
      `pr-checks.yml` was created to close.
      ```bash
      # a) iOS Debug simulator
      xcodebuild -project Xomfit.xcodeproj -scheme Xomfit \
        -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build

      # b) watch target alone
      xcodebuild -project Xomfit.xcodeproj -scheme XomfitWatch \
        -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' \
        -configuration Debug build

      # c) EXACTLY what pr-checks.yml runs
      xcodebuild build -project Xomfit.xcodeproj -scheme Xomfit \
        -configuration Release -destination 'generic/platform=iOS' \
        IPHONEOS_DEPLOYMENT_TARGET=$(tr -d '[:space:]' < .github/deployment-target) \
        CODE_SIGNING_ALLOWED=NO
      ```

- [ ] **Step 5 — Dry-run the archive locally, signed.** Merging to `master` fires
      `testflight-deploy.yml` immediately; there is no staging archive. Run one
      signed archive locally first so a provisioning failure doesn't surface as a
      failed deploy on master:
      ```bash
      xcodebuild archive -project Xomfit.xcodeproj -scheme Xomfit \
        -configuration Release -destination 'generic/platform=iOS' \
        -archivePath /tmp/Xomfit.xcarchive -allowProvisioningUpdates
      ```
      Then confirm the watch app is actually inside:
      ```bash
      ls /tmp/Xomfit.xcarchive/Products/Applications/Xomfit.app/Watch/
      ```
      `com.Xomware.Xomfit.watchkitapp` needs an App ID; `-allowProvisioningUpdates`
      (already passed by the deploy workflow) should register it.

- [ ] **Step 6 — Smoke test.** Follow the existing checklist in
      `docs/features/apple-watch-256/SETUP.md` (timer, rest ring, Paused pill,
      Done Set, double-tap idempotency, cold-launch queueing). Add one case the
      old doc couldn't cover: **start a workout, lower the wrist for 60s, raise
      it — the elapsed timer must have kept advancing.** That's the assertion that
      proves Step 1 worked.

- [ ] **Step 7 — Rewrite `SETUP.md`** to describe the shipped state and the
      embed/entitlement gotchas, and bump the version tag per the deploy rule.

### Phase 2 — Opt-in auto cardio import

- [ ] **Step 1 — Entitlement.** Add `com.apple.developer.healthkit.background-delivery`
      to `Xomfit/Xomfit.entitlements`. Re-run the Release build check (Step 4c
      above) — an entitlement the App ID doesn't have yet fails at signing, not
      at compile, so also re-run the local signed archive.

- [ ] **Step 2 — Anchor storage.** In `HealthKitService`, add private
      `loadAnchor()` / `saveAnchor(_:)` using
      `NSKeyedArchiver.archivedData(withRootObject:requiringSecureCoding: true)`
      against `UserDefaults.standard` key `health.cardioImportAnchor`. A nil/
      corrupt anchor means "first run" — fall back to the existing 30-day window
      so the first import isn't empty.

- [ ] **Step 3 — Anchored fetch.** Add
      `func newCardioSessions(userId: String) async -> (sessions: [CardioSession], anchor: HKQueryAnchor?)`
      using `HKAnchoredObjectQuery` on `HKObjectType.workoutType()`. Reuse the
      existing `session(from:userId:)` mapper verbatim — including its own-bundle
      filter, which keeps XomFit's own strength exports from round-tripping back
      in. **Return the anchor, don't persist it here** — the caller persists only
      after a successful save.

- [ ] **Step 4 — Observer + background delivery.** Add:
      - `startCardioObserverIfEnabled()` — no-ops unless
        `UserDefaults.standard.bool(forKey: "health.autoImportCardio")` and
        `isAvailable`.
      - An `HKObserverQuery` on `workoutType()`. In its handler: resolve the user
        id from `AuthService.shared.currentUser`; if nil, **call the completion
        handler and return without touching the anchor** (the next foreground
        launch catches up). Otherwise run the anchored fetch, upsert via
        `CardioService`, then save the anchor.
      - `store.enableBackgroundDelivery(for: .workoutType(), frequency: .immediate)`.
      - **Always call the observer's completion handler**, on every path including
        errors — iOS throttles and eventually disables delivery for an app that
        doesn't.
      - `stopCardioObserver()` — `store.stop(query)` + `disableBackgroundDelivery(for:)`.

- [ ] **Step 5 — Register at launch.** Call `startCardioObserverIfEnabled()` from
      `AppDelegate.application(_:didFinishLaunchingWithOptions:)`, not from a
      view's `.task`. HealthKit background relaunch never renders the root view.

- [ ] **Step 6 — Make the write idempotent.** Change `CardioService.save` to
      upsert on the `(user_id, healthkit_uuid)` conflict target rather than
      relying on the in-memory `knownUUIDs` pre-filter, which is always empty on a
      background cold launch.

- [ ] **Step 7 — The toggle.** Add `healthSection` to `SettingsView` after
      `notificationsSection`:
      - `@AppStorage("health.autoImportCardio") private var autoImportCardio = false`
      - Label: "Auto-import cardio". Footer: "Pulls runs, rides and rows recorded
        by your watch — Apple Watch, Garmin, Whoop — into XomFit automatically.
        iOS batches this, so a session can take up to an hour to appear."
      - On → `requestAuthorization()`, then `startCardioObserverIfEnabled()`, then
        a one-shot catch-up import. If authorization is declined, flip the toggle
        back off rather than leaving it on and silently dead.
      - Off → `stopCardioObserver()`.

- [ ] **Step 8 — Tests.** Extend `XomFitTests/HealthKitTests.swift`: anchor
      round-trip, toggle-off means observer never starts, and nil-user-id leaves
      the stored anchor unchanged. Register any new test file with the xcodeproj
      gem — the test target uses explicit file references, not a synced group.

## Risks

| Risk | Mitigation |
|---|---|
| watchOS runtime download fails on space | 11 GB free now vs 3.9 GB needed. Fallback: clear `build/` + `build-rel/`, then `.claude/worktrees` after checking for uncommitted work |
| Embedding breaks the iOS Release archive — this is the failure that deferred it in May | Steps 4 and 5 reproduce both CI invocations locally *before* the PR opens |
| `macos-26` runner lacks the watchOS SDK, breaking `pr-checks.yml` | The PR check runs on the PR, before merge. Fix forward there; `master` is never reached with a red check |
| Merging to `master` auto-deploys to TestFlight with no staging | Step 5's local signed archive is the staging step |
| `com.Xomware.Xomfit.watchkitapp` App ID doesn't exist | `-allowProvisioningUpdates` is already in the deploy workflow; Step 5 proves it works before merge |
| Watch and iOS bundle versions must match or upload is rejected | Deploy workflow passes `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` globally to `xcodebuild`, so both targets get the same values. Verify in the Step 5 archive |
| "Auto" import lags by up to an hour | iOS coalesces background delivery. Say so in the toggle footer rather than pretending it's instant |
| Health data written while the app is fully terminated | Background relaunch handles it — provided registration lives in `AppDelegate` (Step 5) |

## Out of Scope

- Any direct Garmin Connect / Garmin Health API integration. Requires an approved
  partnership, is server-to-server, and delivers strictly less than HealthKit.
- Live in-progress workouts from a Garmin device. Only reachable via a Connect IQ
  (Monkey C) on-device app — separate language, separate store, weeks of work.
- Pushing XomFit workouts *to* a Garmin watch (Training API). Needs the same
  partnership and gives no control over the on-watch timers.
- Daily calorie *history*. `refreshTodaySummary()` reads today's active calories
  for display only; nothing persists them. Separate slice if wanted.
- Standalone (unpaired) watch app. This ships as companion-only.

## Verification

Phase 1 is done when a signed local archive contains
`Xomfit.app/Watch/XomfitWatch.app`, `pr-checks.yml` is green, and the wrist-down
timer test from Step 6 passes on hardware.

Phase 2 is done when, with the toggle on, a workout recorded in the Health app by
another source appears in XomFit's cardio list without opening XomFit — and with
the toggle off, it does not.
