# Test Target Wiring — XomfitTests

**Date:** 2026-06-14
**Context:** While executing the workout-generator epic, discovered the project had
**no working unit-test target**. A `XomfitTests/` folder with ~28 test files existed
on disk but was attached to no target, so the suite had never compiled or run.
`xcodebuild test` failed with "scheme not configured for the test action."

## What was done

1. **Created the `XomfitTests` unit-test target** via the `xcodeproj` Ruby gem
   (project is objectVersion 77 / Xcode 16, hand-editing was too risky).
   - `TEST_HOST` / `BUNDLE_LOADER` wired to the `Xomfit.app` host.
   - `PRODUCT_NAME = $(TARGET_NAME)`, `IPHONEOS_DEPLOYMENT_TARGET = 26.2`
     (matches the app — the project min is 26.2, not the 17 in CLAUDE.md),
     `PRODUCT_BUNDLE_IDENTIFIER = com.Xomware.XomfitTests`, team A3HMLDS2AL.
2. **Added a `TestableReference`** to `Xomfit.xcscheme`'s `<TestAction>`.
3. **Fixed module name typo** in all test files: `@testable import XomFit` → `Xomfit`.
4. **Fixed `AnimationTests`** — added `@MainActor` to both test classes (Swift 6
   actor isolation; the tested types are `@MainActor`).
5. **Fixed a genuine broken test** — `AuthServiceTests.testMockAuthService_sessionExpiry_afterForeground`
   left `shouldSucceed = false` so the mock sign-out threw and never cleared
   `isAuthenticated`. Set `shouldSucceed = true` before the sign-out (matches intent).
6. **Shipping-code change** — `Xomfit/Services/SupabaseClient.swift`: the hosted
   test app fatal-errored at launch because `Config.isConfigured` is false in the
   test environment (Config.swift ships placeholder creds). Added an XCTest guard:
   under tests, skip the config fatal-error and build the client with a valid
   placeholder URL. Production/Debug app launches are unchanged (still fatal-error
   on real misconfig). Tests never make network calls.

## Result
`xcodebuild test -scheme Xomfit` → **140 tests, 0 failures.**
Active test files (7): AnimationTests, AuthServiceTests, AuthValidationTests,
ProgressiveOverloadEngineTests, SessionManagerTests, WorkoutGeneratorTests (new),
WorkoutInsightsSeamTests (new).

## Quarantined tests (TECH DEBT — removed from target, files kept on disk)

These pre-existing test files were written against an app API that no longer
exists (or never did) — they reference types/members not present in the current
app. They were never compiled, so the drift went unnoticed. Removed from the
target so the suite is green; left on disk as candidates for repair or deletion.

**Reference non-existent types (dead — likely aspirational features never built):**
- AdvancedStatsTests (`AdvancedStatsService`)
- ChallengeViewModelTests (`ChallengeViewModel`)
- ExportTests (`ExportService`)
- HealthKitTests (`HealthKitService`, `GarminService`)
- PRCalculatorTests (`User`)
- PRViewModelTests (`PRViewModel`)
- ProgramTests (`ProgramService`)
- RecoveryTests (`RecoveryService`)
- SmartRestTimerTests (`SmartRestTimerViewModel`)
- UserProfileServiceTests (`UserProfileService`)
- VideoAnalysisTests (`VideoAnalysisService`)
- WorkoutCardViewModelTests (`WorkoutCardViewModel`, `WorkoutSummaryCardView`)
- BodyCompositionTests (`ProgressPhoto`, `BodyCompositionViewModel`)

**API drift against real types (salvageable with effort):**
- LeaderboardTests (`LeaderboardService` API changed)
- ProfileViewModelStatsTests (`Double?` vs `Double`)
- ProfileViewModelTests (`ProfileViewModel` API + `User`)
- WorkoutLoggerViewModelTests (whole VM API: `activeWorkout`, `inputWeight`, `validateInputs`…)
- FeedViewModelTests (`FeedViewModel` API + `User`)
- AICoachViewModelTests (`AICoachViewModel` now chat-based, not recommendations)
- AICoachTests (`AICoachService` API changed)
- ChallengeTests (`Streak`/`LeaderboardEntry` API + `XCTAssertGreater` typo)

**Recommendation:** triage these separately — delete the dead ones, repair the
drifted ones that cover live features. Not in scope for the workout-generator epic.
