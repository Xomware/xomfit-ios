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
