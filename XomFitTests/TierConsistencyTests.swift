import XCTest
@testable import Xomfit

/// The tier shown and the tier awarded must be the same number.
///
/// `checkForTierUp` ranks a set with its `weightMode`; the badge in the zoomed
/// view and the workout review both omitted it and defaulted to `.total`. On a
/// per-side exercise the two therefore disagreed — the screen showing a target
/// the lifter had already beaten, or withholding a tier they had earned.
@MainActor
final class TierConsistencyTests: XCTestCase {

    private var service: StrengthLevelService { .shared }

    /// A per-side entry describes half the load, so ranking it as a total
    /// under-reports the lift.
    func testPerSideRanksHigherThanTheSameNumberAsTotal() throws {
        service.setManualBodyweight(180)

        let exerciseId = "ex-bench-flat"
        let asTotal = try XCTUnwrap(
            service.rank(exerciseId: exerciseId, weight: 100, reps: 5, weightMode: .total)
        )
        let asPerSide = try XCTUnwrap(
            service.rank(exerciseId: exerciseId, weight: 100, reps: 5, weightMode: .perSide)
        )

        XCTAssertGreaterThan(asPerSide.estimated1RM, asTotal.estimated1RM)
    }

    /// Omitting weightMode is the same as passing `.total`. Pinned so the
    /// default can't drift and silently change what a badge reports.
    func testDefaultWeightModeIsTotal() throws {
        service.setManualBodyweight(180)

        let implicit = try XCTUnwrap(
            service.rank(exerciseId: "ex-bench-flat", weight: 185, reps: 3)
        )
        let explicit = try XCTUnwrap(
            service.rank(exerciseId: "ex-bench-flat", weight: 185, reps: 3, weightMode: .total)
        )

        XCTAssertEqual(implicit.tier, explicit.tier)
        XCTAssertEqual(implicit.estimated1RM, explicit.estimated1RM, accuracy: 0.0001)
    }

    /// Ranking the same set twice through the same entry point is stable —
    /// the badge refreshes constantly and must not flicker between tiers.
    func testRankingIsDeterministic() throws {
        service.setManualBodyweight(180)

        let first = try XCTUnwrap(
            service.rank(exerciseId: "ex-squat", weight: 315, reps: 5, weightMode: .total)
        )
        let second = try XCTUnwrap(
            service.rank(exerciseId: "ex-squat", weight: 315, reps: 5, weightMode: .total)
        )

        XCTAssertEqual(first.tier, second.tier)
        XCTAssertEqual(first.nextTierTarget, second.nextTierTarget)
    }
}
