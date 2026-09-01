import XCTest
@testable import Xomfit

/// Turning a tier threshold back into a weight to load.
///
/// Tier thresholds are estimated 1RMs. Shown raw they read as bar weights, so
/// "370 for Diamond" looked wrong to anyone who hit Diamond at 360 — at eight
/// reps that set estimates to 456, ninety pounds past the threshold.
final class EstimatedMaxInverseTests: XCTestCase {

    func testInverseRoundTripsEstimateMax() {
        for reps in 1...15 {
            let weight = 225.0
            let e1rm = Exercise.estimateMax(weight: weight, reps: reps)
            let back = Exercise.weightForEstimatedMax(e1rm, reps: reps)
            XCTAssertEqual(back, weight, accuracy: 0.0001, "reps: \(reps)")
        }
    }

    func testASingleRepNeedsTheFullWeight() {
        XCTAssertEqual(Exercise.weightForEstimatedMax(370, reps: 1), 370, accuracy: 0.0001)
    }

    /// Zero and negative reps must not divide by anything strange.
    func testNonPositiveRepsFallBackToTheTarget() {
        XCTAssertEqual(Exercise.weightForEstimatedMax(370, reps: 0), 370, accuracy: 0.0001)
        XCTAssertEqual(Exercise.weightForEstimatedMax(370, reps: -3), 370, accuracy: 0.0001)
    }

    /// More reps means less bar weight for the same estimated max.
    func testMoreRepsLowersTheRequiredWeight() {
        let atThree = Exercise.weightForEstimatedMax(370, reps: 3)
        let atTen = Exercise.weightForEstimatedMax(370, reps: 10)
        XCTAssertLessThan(atTen, atThree)
        XCTAssertLessThan(atThree, 370)
    }

    /// The reported case: 360 for 8 clears a 370 threshold, and the inverse
    /// says so — the weight needed at 8 reps is well under 360.
    func testTheReportedDiamondCase() {
        let e1rm = Exercise.estimateMax(weight: 360, reps: 8)
        XCTAssertGreaterThan(e1rm, 370)

        let needed = Exercise.weightForEstimatedMax(370, reps: 8)
        XCTAssertLessThan(needed, 360)
    }
}
