import XCTest
@testable import Xomfit

/// The plan the phone sends both watches.
///
/// `WatchWorkoutState` has a hand-written decoder because Swift's synthesized
/// one treats an absent key as a hard failure, not a fallback. The phone and
/// each watch ship independently, so their builds routinely disagree about
/// which fields exist — and without tolerance the watch drops every message and
/// just sits there looking broken.
final class WatchPlanWireTests: XCTestCase {

    private func encoded(_ state: WatchWorkoutState) throws -> Data {
        try JSONEncoder().encode(state)
    }

    private func base(plan: [WatchWorkoutState.PlanRow] = [], currentIndex: Int? = nil) -> WatchWorkoutState {
        WatchWorkoutState(
            workoutName: "Push Day",
            currentExercise: "Bench Press",
            setNumber: 2,
            totalSets: 4,
            isResting: false,
            isPaused: false,
            elapsedSeconds: 900,
            plan: plan,
            currentIndex: currentIndex
        )
    }

    func testPlanRoundTrips() throws {
        let plan = [
            WatchWorkoutState.PlanRow(name: "Bench Press", done: 2, total: 4),
            WatchWorkoutState.PlanRow(name: "Incline Press", done: 0, total: 3)
        ]
        let decoded = try JSONDecoder().decode(
            WatchWorkoutState.self, from: encoded(base(plan: plan, currentIndex: 0))
        )

        XCTAssertEqual(decoded.plan, plan)
        XCTAssertEqual(decoded.currentIndex, 0)
    }

    /// An older phone sends no plan at all. The watch must still decode the
    /// message and fall back, not drop it.
    func testMessageWithoutAPlanStillDecodes() throws {
        var json = try JSONSerialization.jsonObject(
            with: encoded(base())
        ) as! [String: Any]
        json.removeValue(forKey: "plan")
        json.removeValue(forKey: "currentIndex")

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(WatchWorkoutState.self, from: data)

        XCTAssertTrue(decoded.plan.isEmpty)
        XCTAssertNil(decoded.currentIndex)
        XCTAssertEqual(decoded.currentExercise, "Bench Press")
    }

    /// A newer phone sends fields this build has never heard of.
    func testUnknownFieldsAreIgnored() throws {
        var json = try JSONSerialization.jsonObject(
            with: encoded(base())
        ) as! [String: Any]
        json["somethingFromTheFuture"] = 42

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(WatchWorkoutState.self, from: data)

        XCTAssertEqual(decoded.workoutName, "Push Day")
    }

    func testFractionIsBoundedAndSafeOnAZeroTotal() {
        XCTAssertEqual(
            WatchWorkoutState.PlanRow(name: "x", done: 2, total: 4).fraction, 0.5
        )
        // Done can exceed total when an extra set is added mid-exercise; the
        // bar must fill, not overflow.
        XCTAssertEqual(
            WatchWorkoutState.PlanRow(name: "x", done: 5, total: 4).fraction, 1
        )
        // An exercise the phone has sent before its sets exist.
        XCTAssertEqual(
            WatchWorkoutState.PlanRow(name: "x", done: 0, total: 0).fraction, 0
        )
    }

    func testCompletionNeedsRealSets() {
        XCTAssertTrue(WatchWorkoutState.PlanRow(name: "x", done: 4, total: 4).isComplete)
        XCTAssertFalse(WatchWorkoutState.PlanRow(name: "x", done: 1, total: 4).isComplete)
        // Not "complete" just because it has no sets.
        XCTAssertFalse(WatchWorkoutState.PlanRow(name: "x", done: 0, total: 0).isComplete)
    }
}
