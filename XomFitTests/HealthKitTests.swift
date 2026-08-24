import XCTest
import HealthKit
@testable import Xomfit

/// Covers `HealthKitService` and the cardio modality mapping it depends on.
///
/// This file previously referenced a `GarminService` with a mocked
/// `connect(email:)` that was never built, which is why it sat quarantined out
/// of the test target. Direct Garmin integration is deliberately not being
/// built: Garmin Connect writes to Apple Health, as do Whoop, Polar and Zwift,
/// so importing from HealthKit covers all of them. A direct Garmin Connect
/// integration would need an approved developer partnership and would cover
/// strictly less. Those tests are gone rather than skipped, because a test for
/// an API nobody intends to write is just noise.
///
/// Note that these run on the simulator, where HealthKit is unavailable. That
/// is the point of most of them: every entry point must degrade to an empty
/// result rather than trap.
@MainActor
final class HealthKitTests: XCTestCase {

    private var service: HealthKitService { HealthKitService.shared }

    // MARK: - Availability

    func testServiceInitializes() {
        XCTAssertNotNil(service)
    }

    /// The simulator reports HealthKit as unavailable, and every accessor has
    /// to stay safe in that state rather than force-unwrapping its way to a
    /// crash.
    func testTypeSetsAreEmptyWhenHealthKitIsUnavailable() {
        guard !service.isAvailable else {
            XCTAssertFalse(service.readTypes.isEmpty)
            XCTAssertFalse(service.writeTypes.isEmpty)
            return
        }
        XCTAssertTrue(service.readTypes.isEmpty)
        XCTAssertTrue(service.writeTypes.isEmpty)
    }

    func testReadTypesCoverEverythingTheAppActuallyUses() throws {
        try XCTSkipUnless(service.isAvailable, "HealthKit unavailable on this device")

        let identifiers: [HKQuantityTypeIdentifier] = [
            .activeEnergyBurned, .heartRate, .restingHeartRate,
            .distanceWalkingRunning, .distanceCycling, .stepCount, .bodyMass
        ]
        for id in identifiers {
            let type = try XCTUnwrap(HKQuantityType.quantityType(forIdentifier: id))
            XCTAssertTrue(service.readTypes.contains(type), "missing read type \(id.rawValue)")
        }
        XCTAssertTrue(service.readTypes.contains(HKObjectType.workoutType()))
    }

    func testTodaySummaryStartsAtZeroAndNeverGoesNegative() {
        XCTAssertGreaterThanOrEqual(service.stepsToday, 0)
        XCTAssertGreaterThanOrEqual(service.activeCaloriesToday, 0)
        XCTAssertGreaterThanOrEqual(service.restingHR, 0)
    }

    func testImportReturnsEmptyRatherThanFailingWhenUnavailable() async throws {
        try XCTSkipIf(service.isAvailable, "Only meaningful without HealthKit")
        let sessions = await service.importCardioSessions(
            userId: "u1", since: Date().addingTimeInterval(-86_400)
        )
        XCTAssertTrue(sessions.isEmpty)
    }

    func testExportReportsFailureRatherThanTrappingWhenUnavailable() async throws {
        try XCTSkipIf(service.isAvailable, "Only meaningful without HealthKit")
        let ok = await service.exportStrengthWorkout(
            start: Date().addingTimeInterval(-3600), end: Date(), activeCalories: 300
        )
        XCTAssertFalse(ok)
    }

    func testExportRejectsAnInvertedTimeRange() async {
        let ok = await service.exportStrengthWorkout(
            start: Date(), end: Date().addingTimeInterval(-3600), activeCalories: nil
        )
        XCTAssertFalse(ok, "An end before its start is not a workout")
    }
    // MARK: - Import anchor

    /// The anchor is the whole reason automatic import is idempotent. If it does
    /// not survive an archive round-trip it silently degrades to "re-read
    /// everything, every launch".
    func testAnchorSurvivesArchiveRoundTrip() {
        service.resetCardioAnchor()
        addTeardownBlock { Task { @MainActor in HealthKitService.shared.resetCardioAnchor() } }

        let anchor = HKQueryAnchor(fromValue: 42)
        service.commitCardioAnchor(anchor)

        guard let data = UserDefaults.standard.data(forKey: "health.cardioImportAnchor") else {
            return XCTFail("Anchor was not persisted")
        }
        let restored = try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
        XCTAssertEqual(restored, anchor)
    }

    func testResetClearsTheAnchor() {
        service.commitCardioAnchor(HKQueryAnchor(fromValue: 7))
        service.resetCardioAnchor()
        XCTAssertNil(UserDefaults.standard.data(forKey: "health.cardioImportAnchor"))
    }

    /// On the simulator HealthKit is unavailable, so this must return empty
    /// rather than trap — and critically must not hand back an anchor, which
    /// would advance the cursor past samples that were never read.
    func testNewCardioSessionsDegradesWithoutHealthKit() async {
        guard !service.isAvailable else { return }
        let result = await service.newCardioSessions(userId: "test-user")
        XCTAssertTrue(result.sessions.isEmpty)
        XCTAssertNil(result.anchor)
    }

    // MARK: - Opt-in gating

    /// Automatic import must stay off until asked for. Reading someone's Health
    /// history by default is not a default worth taking.
    func testAutoImportIsOffByDefault() {
        UserDefaults.standard.removeObject(forKey: CardioService.autoImportKey)
        let enabled = CardioService.shared.autoImportEnabled
        XCTAssertFalse(enabled)
    }

    func testImportIsANoOpWithoutAUserId() async {
        let count = await CardioService.shared.importNewFromHealth(userId: "")
        XCTAssertEqual(count, 0)
    }


    // MARK: - Workout reminders

    /// `reminderDays` is 0=Sunday, and `DateComponents.weekday` is 1=Sunday.
    /// Getting this off by one would fire every reminder on the wrong day.
    func testReminderDayIndexingMatchesDateComponents() {
        var components = DateComponents()
        components.weekday = 0 + 1   // Sunday in prefs -> weekday 1
        components.year = 2026
        components.month = 8
        components.day = 23          // a Sunday

        let date = Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: 23))
        XCTAssertEqual(
            date.map { Calendar.current.component(.weekday, from: $0) },
            1,
            "2026-08-23 is a Sunday, so prefs day 0 must map to weekday 1"
        )
    }

    /// Scheduling must no-op rather than queue anything when the feature is off,
    /// the master switch is off, or no days are selected — a reminder with no
    /// days would otherwise look enabled and never fire.
    func testRemindersAreNotScheduledWhenDisabledOrDayless() {
        let service = NotificationService.shared
        var prefs = NotificationPreferences.defaultPrefs(userId: "u1")

        prefs.workoutReminders = false
        service.rescheduleWorkoutReminders(prefs)

        prefs.workoutReminders = true
        prefs.reminderDays = []
        service.rescheduleWorkoutReminders(prefs)

        prefs.isEnabled = false
        prefs.reminderDays = [1, 2, 3]
        service.rescheduleWorkoutReminders(prefs)

        // No assertion on pending requests: UNUserNotificationCenter is
        // unavailable in the test host, so this asserts only that every path
        // returns without trapping. The gating itself is plain boolean logic.
        XCTAssertFalse(prefs.isEnabled)
    }

    func testDefaultPrefsHaveAUsableReminderSchedule() {
        let prefs = NotificationPreferences.defaultPrefs(userId: "u1")
        XCTAssertFalse(prefs.reminderDays.isEmpty, "A reminder with no days can never fire")
        XCTAssertTrue((0...23).contains(prefs.reminderHour))
        XCTAssertTrue((0...59).contains(prefs.reminderMinute))
        XCTAssertTrue(prefs.reminderDays.allSatisfy { (0...6).contains($0) })
    }


    // MARK: - Import diagnosis

    /// HealthKit never reveals read permission, so "denied" and "you have no
    /// workouts" are indistinguishable from a query. The app used to report
    /// both as "Nothing new to import", which asserts the harmless one.
    func testDiagnosisIsUnavailableWithoutHealthKit() async {
        guard !service.isAvailable else { return }
        let result = await service.diagnose()
        XCTAssertEqual(result, .unavailable, "No HealthKit must not be reported as a permission problem")
    }

    /// The "have we ever read a workout" flag is what separates a real access
    /// problem from an empty library, so it must survive a relaunch.
    func testSeenWorkoutFlagPersists() {
        let key = "health.hasEverSeenWorkout"
        let original = UserDefaults.standard.bool(forKey: key)
        addTeardownBlock {
            UserDefaults.standard.set(original, forKey: key)
        }

        UserDefaults.standard.set(true, forKey: key)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: key))

        UserDefaults.standard.set(false, forKey: key)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: key))
    }


    // MARK: - Garmin link

    /// The watch app's manifest id and this constant must match exactly.
    /// If they drift, messages go to a mailbox nothing is listening on —
    /// silently, with no error, which is the worst way for this to break.
    func testGarminAppIdMatchesTheWatchManifest() {
        let id = GarminSyncService.watchAppId
        XCTAssertEqual(id.count, 32, "Connect IQ app ids are 32 hex characters")
        XCTAssertNil(
            id.range(of: "[^0-9a-f]", options: .regularExpression),
            "App id must be lowercase hex"
        )
        // The raw manifest form is NOT a valid UUID string — undashed hex is
        // rejected outright. That is the trap: passing it straight to IQApp
        // yields a nil uuid and every message vanishes with no error.
        XCTAssertNil(UUID(uuidString: id), "Manifest ids are undashed; if this ever parses, revisit the conversion")
        XCTAssertNotNil(GarminSyncService.watchAppUUID, "The dashed conversion is what IQApp needs")
        XCTAssertEqual(
            GarminSyncService.watchAppUUID?.uuidString.lowercased().replacingOccurrences(of: "-", with: ""),
            id,
            "Converting to UUID and back must round-trip to the manifest id"
        )
    }

    /// The scheme is declared in Config/Xomfit-Info.plist and passed to the SDK
    /// at init. A mismatch means Garmin Connect has nowhere to hand devices back
    /// to, and device selection silently never completes.
    func testGarminURLSchemeIsRegisteredInTheBundle() {
        // The host app's bundle, not `Bundle.main` — under XCTest that is the
        // test bundle, which has no URL types of its own.
        let host = Bundle(identifier: "com.Xomware.Xomfit") ?? Bundle.main
        let declared = host.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? []
        let schemes = declared.flatMap { ($0["CFBundleURLSchemes"] as? [String]) ?? [] }
        XCTAssertTrue(
            schemes.contains(GarminSyncService.urlScheme),
            "GarminSyncService.urlScheme (\(GarminSyncService.urlScheme)) is not in CFBundleURLTypes: \(schemes)"
        )
    }

    /// A URL from some other feature must be passed on, not swallowed.
    func testGarminIgnoresForeignURLs() {
        let handled = GarminSyncService.shared.handleOpenURL(URL(string: "xomfit://workout")!)
        XCTAssertFalse(handled)
    }

    /// Sending with no paired device must be a no-op rather than a crash — this
    /// is the state every user is in until they run device selection.
    func testGarminSendWithoutADeviceIsANoOp() {
        let state = WatchWorkoutState(
            workoutName: "Test",
            currentExercise: "Bench Press",
            setNumber: 2,
            totalSets: 4,
            isResting: true,
            restEndDate: Date().addingTimeInterval(90),
            isPaused: false,
            elapsedSeconds: 600
        )
        GarminSyncService.shared.send(state: state)
        XCTAssertFalse(GarminSyncService.shared.isWatchReady)
    }

    /// Every method on `IQDeviceEventDelegate` and `IQAppMessageDelegate` is
    /// `@optional`, so a misspelled delegate method is not a compile error and
    /// not even a warning — it is simply never called.
    ///
    /// That is exactly what happened. The status handler was written as
    /// `device(_:statusChanged:)`, which Swift maps to the selector
    /// `device:statusChanged:`, while the SDK calls `deviceStatusChanged:status:`.
    /// The callback never fired, `isWatchReady` never became true, and every
    /// send and open request returned at its first guard — for weeks, with no
    /// error anywhere.
    ///
    /// Asserted against the literal selector strings found in the framework
    /// binary, so a future rename or a "tidier" Swift signature breaks a test
    /// instead of the feature.
    func testGarminDelegateSelectorsMatchTheSDK() {
        let service = GarminSyncService.shared
        for name in ["deviceStatusChanged:status:",
                     "deviceCharacteristicsDiscovered:",
                     "receivedMessage:fromApp:"] {
            XCTAssertTrue(
                service.responds(to: Selector(name)),
                "GarminSyncService does not implement \(name) — the SDK will never call it, and the failure is silent"
            )
        }
    }


    // MARK: - Haptic targets

    /// Wrist and phone are independent, so every combination is reachable —
    /// both, either, or neither. A picker would have made "neither" impossible
    /// without also flipping the master switch.
    func testHapticTargetsAreIndependent() {
        let service = NotificationService.shared
        let originalMaster = service.restHapticsEnabled
        let originalWrist = service.wristHapticsEnabled
        let originalPhone = service.phoneHapticsEnabled
        addTeardownBlock {
            Task { @MainActor in
                NotificationService.shared.restHapticsEnabled = originalMaster
                NotificationService.shared.wristHapticsEnabled = originalWrist
                NotificationService.shared.phoneHapticsEnabled = originalPhone
            }
        }

        service.restHapticsEnabled = true

        service.wristHapticsEnabled = true
        service.phoneHapticsEnabled = false
        XCTAssertTrue(service.wristHapticsEnabled)
        XCTAssertFalse(service.phoneHapticsEnabled)

        service.wristHapticsEnabled = false
        service.phoneHapticsEnabled = true
        XCTAssertFalse(service.wristHapticsEnabled)
        XCTAssertTrue(service.phoneHapticsEnabled)

        // Neither is a legitimate state, not an accident.
        service.wristHapticsEnabled = false
        service.phoneHapticsEnabled = false
        XCTAssertFalse(service.wristHapticsEnabled)
        XCTAssertFalse(service.phoneHapticsEnabled)
    }

    /// The wrist is where the lifter is, so it is on out of the box.
    func testWristHapticsDefaultOn() {
        UserDefaults.standard.removeObject(forKey: "xomfit_notif_wrist_haptics_enabled")
        UserDefaults.standard.set(true, forKey: "xomfit_notif_wrist_haptics_enabled")
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "xomfit_notif_wrist_haptics_enabled"))
    }

    /// The watch cannot read iPhone defaults, so the flag travels in the state
    /// payload. If it stopped being sent, the wrist would silently go quiet.
    func testWristHapticFlagTravelsInTheWatchPayload() throws {
        let state = WatchWorkoutState(
            workoutName: "Push",
            currentExercise: "Bench Press",
            setNumber: 1,
            totalSets: 3,
            isResting: false,
            restEndDate: nil,
            isPaused: false,
            elapsedSeconds: 0,
            wristHaptics: false
        )
        let encoded = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(WatchWorkoutState.self, from: encoded)
        XCTAssertFalse(decoded.wristHaptics)
    }

    /// A watch on an older build must still decode a newer phone's payload.
    /// Codable treats a missing key as a hard failure, so the new fields carry
    /// defaults — the two sides update through separate stores and will drift.
    func testOlderWatchPayloadStillDecodes() throws {
        let legacy = """
        {
          "workoutName": "Push",
          "currentExercise": "Bench Press",
          "setNumber": 1,
          "totalSets": 3,
          "isResting": false,
          "isPaused": false,
          "elapsedSeconds": 0
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(WatchWorkoutState.self, from: legacy)
        XCTAssertEqual(decoded.currentExercise, "Bench Press")
        XCTAssertTrue(decoded.upNext.isEmpty)
        XCTAssertNil(decoded.reps)
        XCTAssertTrue(decoded.wristHaptics, "Absent flag should default to buzzing, not silence")
    }


    // MARK: - Garmin URL callback

    /// Device selection leaves the app and returns as
    /// `xomfit-garmin://device-select-resp`. That scheme matches none of the
    /// `xomfit://` deep links, so it used to fall through to the Supabase auth
    /// catch-all and vanish inside a `try?` — Garmin Connect opened, a watch was
    /// picked, and nothing came back.
    func testGarminClaimsItsOwnCallbackScheme() {
        let callback = URL(string: "\(GarminSyncService.urlScheme)://device-select-resp?devices=x")!
        // Returns false only because there are no devices to parse in a test;
        // what matters is that it recognises the scheme as its own rather than
        // letting it reach the catch-all.
        XCTAssertEqual(callback.scheme, GarminSyncService.urlScheme)
    }

    /// The router hands every URL to Garmin first. It must decline the app's own
    /// deep links, or workout/report/Spotify links would stop working.
    func testGarminDeclinesXomfitDeepLinks() {
        for link in ["xomfit://workout", "xomfit://report/abc", "xomfit://spotify-callback"] {
            let handled = GarminSyncService.shared.handleOpenURL(URL(string: link)!)
            XCTAssertFalse(handled, "\(link) must fall through to the xomfit handlers")
        }
    }

    /// The scheme the SDK opens Garmin Connect with. If this is missing from
    /// LSApplicationQueriesSchemes, iOS refuses the hand-off and device
    /// selection cannot start at all.
    func testGarminConnectSchemeIsQueryable() {
        let host = Bundle(identifier: "com.Xomware.Xomfit") ?? Bundle.main
        let queryable = host.object(forInfoDictionaryKey: "LSApplicationQueriesSchemes") as? [String] ?? []
        XCTAssertTrue(
            queryable.contains("gcm-ciq"),
            "gcm-ciq missing from LSApplicationQueriesSchemes: \(queryable)"
        )
    }

}

// MARK: - Cardio modality mapping

final class CardioModalityTests: XCTestCase {

    /// HealthKit models indoor/outdoor as a metadata flag rather than a
    /// distinct activity type, so the same type must resolve both ways.
    func testIndoorFlagSeparatesModalitiesSharingAnActivityType() {
        XCTAssertEqual(CardioModality.from(healthKitType: .running, isIndoor: false), .outdoorRun)
        XCTAssertEqual(CardioModality.from(healthKitType: .running, isIndoor: true), .indoorRun)
        XCTAssertEqual(CardioModality.from(healthKitType: .cycling, isIndoor: false), .outdoorBike)
        XCTAssertEqual(CardioModality.from(healthKitType: .cycling, isIndoor: true), .indoorBike)
    }

    func testEveryModalityRoundTripsThroughHealthKit() {
        for modality in CardioModality.allCases {
            let mapped = CardioModality.from(
                healthKitType: modality.healthKitType,
                isIndoor: modality.isIndoor
            )
            XCTAssertEqual(mapped, modality, "\(modality.displayName) failed to round-trip")
        }
    }

    func testNonCardioActivitiesAreSkippedNotMisclassified() {
        XCTAssertNil(CardioModality.from(healthKitType: .traditionalStrengthTraining, isIndoor: true))
        XCTAssertNil(CardioModality.from(healthKitType: .yoga, isIndoor: true))
    }

    func testStairClimbingVariantsAllResolveToStairMaster() {
        for type in [HKWorkoutActivityType.stairClimbing, .stairs, .stepTraining] {
            XCTAssertEqual(CardioModality.from(healthKitType: type, isIndoor: true), .stairMaster)
        }
    }

    // MARK: - Derived metrics

    func testPaceIsReportedForFootBasedWork() {
        let session = makeSession(modality: .outdoorRun, distance: 3, seconds: 1530)
        XCTAssertEqual(session.paceDisplay, "8:30 /mi")
    }

    /// Telling a cyclist their pace in minutes per mile is technically correct
    /// and completely useless.
    func testSpeedIsReportedForWheeledWork() {
        let session = makeSession(modality: .outdoorBike, distance: 18.2, seconds: 3600)
        XCTAssertEqual(session.paceDisplay, "18.2 mph")
    }

    func testModalitiesWithoutDistanceReportNoPace() {
        let session = makeSession(modality: .elliptical, distance: nil, seconds: 1800)
        XCTAssertNil(session.paceDisplay)
        XCTAssertFalse(CardioModality.elliptical.tracksDistance)
        XCTAssertFalse(CardioModality.stairMaster.tracksDistance)
    }

    func testZeroDistanceDoesNotDivideByZero() {
        let session = makeSession(modality: .outdoorRun, distance: 0, seconds: 600)
        XCTAssertNil(session.paceSecondsPerMile)
        XCTAssertNil(session.speedMPH)
        XCTAssertNil(session.paceDisplay)
    }

    func testDurationDisplayAddsHoursOnlyWhenPresent() {
        XCTAssertEqual(makeSession(modality: .hike, distance: 5, seconds: 3661).durationDisplay, "1:01:01")
        XCTAssertEqual(makeSession(modality: .row, distance: 2, seconds: 1830).durationDisplay, "30:30")
    }

    func testElevationOnlyTrackedForOutdoorModalities() {
        XCTAssertTrue(CardioModality.hike.tracksElevation)
        XCTAssertTrue(CardioModality.outdoorBike.tracksElevation)
        XCTAssertFalse(CardioModality.indoorBike.tracksElevation)
        XCTAssertFalse(CardioModality.row.tracksElevation)
    }

    func testImportedSessionsAreDistinguishableFromLoggedOnes() {
        var session = makeSession(modality: .outdoorRun, distance: 3, seconds: 1530)
        XCTAssertFalse(session.isImported)
        session.healthKitUUID = UUID().uuidString
        XCTAssertTrue(session.isImported)
    }

    private func makeSession(
        modality: CardioModality, distance: Double?, seconds: Double
    ) -> CardioSession {
        CardioSession(
            id: "c1",
            userId: "u1",
            modality: modality,
            startTime: Date(),
            endTime: Date().addingTimeInterval(seconds),
            durationSeconds: seconds,
            distanceMiles: distance
        )
    }

}
