# Apple Watch v1 — One-Time Xcode Setup (#256)

This PR ships everything except the watchOS App **target** itself. Adding a target to a project that uses `objectVersion = 77` + `fileSystemSynchronizedGroups` is fragile to script — it's a 60-second click-through in Xcode. After that, the four pre-written Swift files in `XomfitWatch/` compile automatically.

## Steps (do this once, then commit the resulting `Xomfit.xcodeproj` change)

1. **Open the project**
   ```
   open Xomfit.xcodeproj
   ```

2. **Add the Watch target**
   - File → New → Target…
   - Choose **watchOS → App**
   - Click Next, then fill in:
     - **Product Name**: `XomfitWatch`
     - **Bundle Identifier**: `com.Xomware.Xomfit.watchkitapp`
     - **Interface**: SwiftUI
     - **Language**: Swift
     - **Include Tests**: unchecked (we'll add later)
   - When prompted **"Embed in Companion Application"**, choose the **Xomfit** iOS target.
   - Click Finish. (If Xcode asks to activate a new scheme, choose Activate.)

3. **Replace Xcode's stub source files with our pre-written ones**

   Xcode generates a stub `XomfitWatchApp.swift` and `ContentView.swift` inside a new group it just created. Delete those stubs (move to trash) — we already have the real implementations in the existing `XomfitWatch/` folder at the repo root.

4. **Point the new target at our `XomfitWatch/` source folder**
   - In the Project Navigator, right-click the new Watch target's group → **Add Files to "Xomfit"…**
   - Select the `XomfitWatch/` folder at the repo root
   - In the dialog: **"Create folder references"** → choose **"Create groups"** … actually:
   - The cleanest path is to drag `XomfitWatch/` from Finder into the Watch target group, choose **"Create folder reference"** with the **synced** option, and ensure the **target membership** checkbox for the Watch target is checked.
   - Confirm all four files are present in the target's "Compile Sources" build phase:
     - `XomfitWatchApp.swift`
     - `ContentView.swift`
     - `WatchSessionStore.swift`
     - `WatchWorkoutState.swift`

5. **Capabilities**
   - Select the `XomfitWatch` target → **Signing & Capabilities**
   - The watchOS app inherits the team from the parent. Add **Background Modes** if it isn't on by default (it usually is for watchOS App targets).

6. **Verify the build**
   ```bash
   xcodebuild -project Xomfit.xcodeproj \
     -scheme XomfitWatch \
     -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' \
     -configuration Debug build
   ```
   Should succeed. If you see "no such module 'WatchConnectivity'" the target somehow ended up as iOS — re-check step 2.

7. **Commit the project change**
   ```bash
   git add Xomfit.xcodeproj/project.pbxproj
   git commit -m "#256 add watchOS App target XomfitWatch"
   ```

## Smoke test (after target is added)

1. Run the iOS scheme on a paired iPhone simulator with a watchOS Simulator.
2. On the iPhone: start a workout, log a set, start rest, pause.
3. On the Watch: workout name + elapsed time should update; rest ring should appear; "Paused" pill should show when paired iPhone is paused.
4. Tap **Done Set** on the Watch — the iPhone should mark the focused set complete.

## How the wiring works

- **iOS → Watch**: `WatchSyncService` (in `Xomfit/Services/`) wraps `WCSession`. It runs every time `WorkoutLoggerViewModel.updateLiveActivity()` ticks. Uses `sendMessage` when reachable, `updateApplicationContext` as a cold-launch fallback.
- **Watch → iOS**: `WatchSessionStore` (in `XomfitWatch/`) decodes inbound `WatchWorkoutState` snapshots. Its "Done Set" button posts `["doneSet": true]` back. The iOS service's `onDoneSetReceived` closure is the hook to wire that into `WorkoutLoggerViewModel.completeSet(...)` in a follow-up.
- **Shared shape**: `WatchWorkoutState` is duplicated in `Xomfit/Models/` and `XomfitWatch/` — same trick as `XomfitWidgetAttributes.swift`. Keep both copies byte-identical or messages will silently drop on decode.
