# Plan: Audit and Modernize — Issue #100

**Status:** Ready
**Branch:** `cleanup/100-audit-modernize`
**Scope:** Small-Medium (6 files)

## Context
Post-audit cleanup of XomFit iOS app. Goal: get the app building cleanly on a real device.

## Changes

### P0 — Critical

1. **Fix force unwrap** (`Xomfit/Models/BodyComposition.swift:154`)
   - `Calendar.current.date(...)!` → guard let with continue
   - In mock data generator, low risk but bad pattern

### P1 — Modernize

3. **Migrate AnimationAssetManager to @Observable** (`Xomfit/Models/Animations/AnimationAssetManager.swift`)
   - Remove `ObservableObject`, `@Published`
   - Add `@Observable` macro
   - Replace completion handler with async/await
   - Remove manual DispatchQueue/NSLock — @MainActor + actor isolation handles this
   - Keep `static let shared` singleton pattern

4. **Migrate WatchConnectivityManager to @Observable** (`XomFitWatch/WatchConnectivityManager.swift`)
   - Remove `ObservableObject`, `@Published`, `import Combine`
   - Add `@Observable` macro
   - Already uses `@MainActor` — just needs the macro swap

5. **Replace deprecated `.navigationBarHidden(true)`** (2 files)
   - `Xomfit/Views/Auth/LoginView.swift:151` → `.toolbar(.hidden, for: .navigationBar)`
   - `Xomfit/Views/Workout/ActiveWorkoutView.swift:77` → `.toolbar(.hidden, for: .navigationBar)`

6. **Replace DispatchQueue with structured concurrency** (`Xomfit/Views/Common/ToastView.swift:78`)
   - `DispatchQueue.main.asyncAfter` → `Task { try? await Task.sleep(for: .seconds(...)) }`

### Config Fix

7. **Update CLAUDE.md project config** (`.claude/CLAUDE.md`)
   - Fix `base_branch: main` → `base_branch: master` (repo actually uses master)
   - Restore `github_project_number: 2` and `github_project_owner: Xomware`

## NOT changing
- View files (FriendsView, ProfileView, FeedItemCard, ActiveWorkoutView) — already well-organized
- XomProgressView stub — will create a separate issue for the Progress feature
- Dependencies — already current (Supabase 2.41.1)
- Swift version in pbxproj — staying at 5.0 (Swift 6 strict mode is a larger migration)

## Test Plan
- `xcodebuild -scheme Xomfit -destination 'platform=iOS Simulator,name=iPhone 16'` — must build clean
- Verify no deprecation warnings for changed APIs
- Manual: app launches, tabs work, auth flow renders

## Follow-up Issues to Create
- Progress tab implementation (XomProgressView is a stub)
- Swift 6 strict concurrency migration
- Accessibility audit (VoiceOver labels, Dynamic Type)
