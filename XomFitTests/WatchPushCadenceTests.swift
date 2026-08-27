import XCTest
@testable import Xomfit

/// What the watches are told, and when.
///
/// The Garmin renders exactly the snapshot it was last handed. Three separate
/// things used to stop that snapshot arriving: the broadcast sat behind
/// `guard let activity = liveActivity`, so it never fired when Live Activities
/// were off; the tick that drove it lived on a view; and the tick throttled
/// pushes to one every five seconds while resting.
final class WatchPushCadenceTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testRestEndIsRemainingSecondsFromNow() throws {
        let end = try XCTUnwrap(
            WorkoutLoggerViewModel.restEnd(
                isResting: true, remaining: 90, isPaused: false, now: now
            )
        )
        XCTAssertEqual(end.timeIntervalSince(now), 90, accuracy: 0.001)
    }

    func testNotRestingHasNoEndDate() {
        XCTAssertNil(
            WorkoutLoggerViewModel.restEnd(
                isResting: false, remaining: 90, isPaused: false, now: now
            )
        )
    }

    /// Paused is nil on purpose: the widget draws a static "Paused" pill rather
    /// than a countdown that has silently stopped moving.
    func testPausedHasNoEndDate() {
        XCTAssertNil(
            WorkoutLoggerViewModel.restEnd(
                isResting: true, remaining: 90, isPaused: true, now: now
            )
        )
    }

    /// Overtime. The countdown has passed zero and the phone models that as
    /// "no end date" rather than one in the past.
    func testExpiredRestHasNoEndDate() {
        XCTAssertNil(
            WorkoutLoggerViewModel.restEnd(
                isResting: true, remaining: 0, isPaused: false, now: now
            )
        )
        XCTAssertNil(
            WorkoutLoggerViewModel.restEnd(
                isResting: true, remaining: -5, isPaused: false, now: now
            )
        )
    }

    /// An absolute end date is what lets a watch stay correct between pushes:
    /// two calls a second apart describe the same finishing moment, so a
    /// dropped message does not shift the countdown.
    func testEndDateIsStableAcrossTicksAsRemainingCountsDown() throws {
        let first = try XCTUnwrap(
            WorkoutLoggerViewModel.restEnd(
                isResting: true, remaining: 60, isPaused: false, now: now
            )
        )
        let second = try XCTUnwrap(
            WorkoutLoggerViewModel.restEnd(
                isResting: true, remaining: 59, isPaused: false,
                now: now.addingTimeInterval(1)
            )
        )
        XCTAssertEqual(first.timeIntervalSince1970, second.timeIntervalSince1970, accuracy: 0.001)
    }
}
