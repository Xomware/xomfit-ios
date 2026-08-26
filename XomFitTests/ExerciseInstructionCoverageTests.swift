import XCTest
@testable import Xomfit

/// Coverage rules for `ExerciseInstructionLibrary`.
///
/// The library is deliberately partial — a generic three-step template stamped
/// across 211 exercises would read as filler. But "partial" has to mean
/// "chosen", not "whatever got written first", so the one hard rule is that
/// anything the app's own programmes prescribe must be explainable.
final class ExerciseInstructionCoverageTests: XCTestCase {

    func testEveryExerciseInABuiltInTemplateHasInstructions() {
        var missing: Set<String> = []

        for template in WorkoutTemplate.builtIn {
            for entry in template.exercises where
                ExerciseInstructionLibrary.instructions(for: entry.exercise.id) == nil {
                missing.insert(entry.exercise.id)
            }
        }

        XCTAssertTrue(
            missing.isEmpty,
            "Built-in templates prescribe exercise(s) with no instructions: "
                + missing.sorted().joined(separator: ", ")
        )
    }

    /// A key that no longer matches an exercise is dead weight the fallback
    /// silently hides — `instructions(for:)` would simply never be asked for it.
    func testEveryInstructionKeyMatchesARealExercise() {
        let known = Set(ExerciseDatabase.all.map(\.id))
        let stale = ExerciseInstructionLibrary.library.keys
            .filter { !known.contains($0) }
            .sorted()

        XCTAssertTrue(
            stale.isEmpty,
            "Instructions for exercises that no longer exist: \(stale.joined(separator: ", "))"
        )
    }

    /// Each of the three sections earns its place — an entry with an empty
    /// section is worse than no entry, because the fallback to description and
    /// tips never fires.
    func testNoInstructionEntryHasAnEmptySection() {
        for (id, instructions) in ExerciseInstructionLibrary.library {
            XCTAssertFalse(instructions.setup.isEmpty, "\(id) has no setup steps")
            XCTAssertFalse(instructions.execution.isEmpty, "\(id) has no execution steps")
            XCTAssertFalse(instructions.mistakes.isEmpty, "\(id) lists no common mistakes")
            XCTAssertFalse(instructions.isEmpty, "\(id) is entirely empty")
        }
    }

    /// Guards against a step being left as an empty string by a bad edit.
    func testNoInstructionStepIsBlank() {
        for (id, instructions) in ExerciseInstructionLibrary.library {
            let all = instructions.setup + instructions.execution + instructions.mistakes
            for step in all {
                XCTAssertFalse(
                    step.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    "\(id) has a blank step"
                )
            }
        }
    }

    /// An uncovered exercise must degrade to the fallback, not to nothing.
    func testUncoveredExerciseStillHasDescriptionAndTips() throws {
        let uncovered = try XCTUnwrap(
            ExerciseDatabase.all.first {
                ExerciseInstructionLibrary.instructions(for: $0.id) == nil
            },
            "Library is now total; this test's premise no longer holds"
        )

        XCTAssertFalse(uncovered.description.isEmpty)
        XCTAssertFalse(uncovered.tips.isEmpty)
    }
}
