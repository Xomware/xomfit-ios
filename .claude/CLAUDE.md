# xomfit-ios

> iOS app for social fitness & lifting tracker.

## What This Is
SwiftUI iOS app for workout logging, social fitness feed, personal record tracking, and friends system. Uses Supabase for auth and real-time data, with REST API calls to xomfit-backend.

## Stack
- SwiftUI, Swift language mode 5 (`SWIFT_VERSION = 5.0`)
- Ships at iOS 18.0: CI archives with `IPHONEOS_DEPLOYMENT_TARGET=18.0`, overriding the pbxproj's 26.2
- Supabase (auth & real-time DB)
- REST API (xomfit-backend)

## Key Commands
```bash
xcodebuild -project Xomfit.xcodeproj -scheme Xomfit -destination 'platform=iOS Simulator,name=iPhone 17' build

# What CI's archive compiles — run before merging anything that uses a new API
xcodebuild build -project Xomfit.xcodeproj -scheme Xomfit -configuration Release \
  -destination 'generic/platform=iOS' IPHONEOS_DEPLOYMENT_TARGET=18.0 CODE_SIGNING_ALLOWED=NO
```

`Xomfit/Config.swift` is gitignored. A fresh worktree won't build until it is
copied in from the main checkout.

## Important Paths
```
Xomfit/Xomfit/
  Models/         # data models
  Views/          # SwiftUI views
  ViewModels/     # MVVM view models
  Services/       # API + Supabase clients
  Utils/          # helpers
```

## Project Config
```yaml
pm_tool: github-projects
github_project_number: 2
github_project_owner: Xomware
base_branch: master
release_branch: master
test_commands:
  - xcodebuild test -project Xomfit.xcodeproj -scheme Xomfit -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Constraints
- MVVM architecture — views should not call services directly
- Supabase handles auth — no custom auth logic
- Shipping minimum is iOS 18.0 — gate newer APIs with `#available` (pattern: `Xomfit/Utils/Theme+Glass.swift`)

## Verification (Agent UI Screenshots)

For agents that need to launch the app and screenshot UI flows without real
Supabase credentials, the Debug build supports a sign-in bypass via the
`XOMFIT_AUTH_BYPASS=1` env var (added in #353).

When set, `AuthService` injects a mock signed-in user, skips all Supabase auth
calls, and hydrates `WorkoutService` + `TemplateService` caches with mock
fixtures so history / templates / detail views render.

Build + install + launch + screenshot:

```bash
# 1. Build a Debug .app for the simulator
xcodebuild \
  -project Xomfit.xcodeproj \
  -scheme Xomfit \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug \
  -derivedDataPath build \
  build

# 2. Boot the sim + install + launch with the bypass env var
xcrun simctl boot "iPhone 17" 2>/dev/null || true
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/Xomfit.app
SIMCTL_CHILD_XOMFIT_AUTH_BYPASS=1 xcrun simctl launch booted com.Xomware.Xomfit

# 3. Wait for first render, then screenshot
sleep 3
xcrun simctl io booted screenshot ~/check.png
```

Deep links (only fire after the app is already launched & bypassed in):

```bash
# Resume the active workout (xomfit://workout) — requires an in-progress session
xcrun simctl openurl booted "xomfit://workout"

# Open the Reports list and auto-push a specific report detail
xcrun simctl openurl booted "xomfit://report/<report-id>"
```

The bypass is `#if DEBUG`-gated and compiles out of Release builds.

## Lessons

- Every push to `master` fires a TestFlight deploy. Batch PRs on a `release/<version>` branch, tag `v<version>` on its tip, then merge it to `master` once with a merge commit.
- `origin/develop` is abandoned (stopped at #239). Don't branch from it.
- Wait for PR Checks before merging. A green local Debug build doesn't prove the iOS 18.0 Release archive compiles (v2.20.0 failed this way).
