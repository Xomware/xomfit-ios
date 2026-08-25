import XCTest
import SwiftUI
@testable import Xomfit

/// The "Muscles Worked" diagram in `ExerciseDetailSheet`.
///
/// The diagram used to paint every muscle group at one opacity, which told the
/// lifter a bench press works chest, triceps and shoulders in equal measure —
/// the one question the diagram exists to answer.
final class ExerciseMuscleDiagramTests: XCTestCase {

    func testPrimeMoverIsHighlightedMoreStronglyThanSupportingMuscles() {
        let fill = ExerciseDetailSheet.highlightFill(for: [.chest, .triceps, .shoulders])

        XCTAssertEqual(fill[.chest], Theme.accent.opacity(ExerciseDetailSheet.primaryMuscleOpacity))
        XCTAssertEqual(fill[.triceps], Theme.accent.opacity(ExerciseDetailSheet.supportingMuscleOpacity))
        XCTAssertEqual(fill[.shoulders], Theme.accent.opacity(ExerciseDetailSheet.supportingMuscleOpacity))
    }

    func testPrimaryIsMoreOpaqueThanSupporting() {
        XCTAssertGreaterThan(
            ExerciseDetailSheet.primaryMuscleOpacity,
            ExerciseDetailSheet.supportingMuscleOpacity,
            "The prime mover has to read as the strongest mark on the diagram"
        )
    }

    func testOnlyTheExercisesOwnMusclesAreFilled() {
        let fill = ExerciseDetailSheet.highlightFill(for: [.lats, .back, .biceps])

        XCTAssertEqual(Set(fill.keys), [.lats, .back, .biceps])
        XCTAssertNil(fill[.quads], "Unworked muscles must fall through to the silhouette's default")
    }

    func testSingleMuscleExerciseHighlightsItAsPrimary() {
        let fill = ExerciseDetailSheet.highlightFill(for: [.calves])

        XCTAssertEqual(fill[.calves], Theme.accent.opacity(ExerciseDetailSheet.primaryMuscleOpacity))
    }

    func testNoMusclesProducesAnEmptyFillRatherThanCrashing() {
        XCTAssertTrue(ExerciseDetailSheet.highlightFill(for: []).isEmpty)
    }

    /// A repeated muscle group would trap `Dictionary(uniqueKeysWithValues:)`,
    /// which is how this file used to build the map. Keyed assignment cannot.
    func testRepeatedMuscleGroupDoesNotTrap() {
        let fill = ExerciseDetailSheet.highlightFill(for: [.chest, .chest])

        XCTAssertEqual(fill.count, 1)
        XCTAssertEqual(
            fill[.chest],
            Theme.accent.opacity(ExerciseDetailSheet.supportingMuscleOpacity),
            "Last write wins; the point of the test is that it returns at all"
        )
    }

    /// Every exercise in the library must produce a usable diagram.
    func testEveryExerciseProducesAHighlightForItsPrimaryMuscle() {
        for exercise in ExerciseDatabase.all {
            guard let primary = exercise.muscleGroups.first else {
                XCTFail("\(exercise.id) lists no muscle groups, so its diagram would be blank")
                continue
            }
            let fill = ExerciseDetailSheet.highlightFill(for: exercise.muscleGroups)
            XCTAssertEqual(
                fill[primary],
                Theme.accent.opacity(ExerciseDetailSheet.primaryMuscleOpacity),
                "\(exercise.id) does not highlight \(primary.displayName) as its prime mover"
            )
        }
    }
}
