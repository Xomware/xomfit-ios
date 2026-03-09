import XCTest
@testable import XomFit

final class ProgressiveOverloadEngineTests: XCTestCase {
    
    let engine = ProgressiveOverloadEngine()
    
    // MARK: - Helpers
    
    private func makeSet(weight: Double, reps: Int, rpe: Double?) -> WorkoutSet {
        WorkoutSet(
            id: UUID().uuidString,
            exerciseId: "ex-1",
            weight: weight,
            reps: reps,
            rpe: rpe,
            isPersonalRecord: false,
            completedAt: Date()
        )
    }
    
    private func makeSession(
        daysAgo: Int,
        exercise: String = "Bench Press",
        sets: [WorkoutSet],
        targetReps: Int = 5
    ) -> ExerciseSession {
        ExerciseSession(
            date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!,
            exercise: exercise,
            sets: sets,
            targetReps: targetReps
        )
    }
    
    // MARK: - Test: No History
    
    func testNoHistory_returnsMaintain() {
        let result = engine.suggestion(for: "Squat", history: [], exerciseType: .compound)
        if case .maintain = result.type {} else {
            XCTFail("Expected maintain, got \(result.type)")
        }
    }
    
    // MARK: - Test: Single Session → Maintain
    
    func testSingleSession_returnsMaintain() {
        let session = makeSession(daysAgo: 1, sets: [
            makeSet(weight: 100, reps: 5, rpe: 7),
            makeSet(weight: 100, reps: 5, rpe: 7),
        ])
        let result = engine.suggestion(for: "Bench Press", history: [session], exerciseType: .compound)
        if case .maintain(let reason) = result.type {
            XCTAssertTrue(reason.contains("Need more data"))
        } else {
            XCTFail("Expected maintain, got \(result.type)")
        }
    }
    
    // MARK: - Test: Weight Increase (compound)
    
    func testWeightIncrease_compound_allRepsCompleted_lowRPE() {
        let sessions = [
            makeSession(daysAgo: 1, sets: [
                makeSet(weight: 60, reps: 5, rpe: 7),
                makeSet(weight: 60, reps: 5, rpe: 7),
                makeSet(weight: 60, reps: 5, rpe: 8),
            ]),
            makeSession(daysAgo: 4, sets: [
                makeSet(weight: 57.5, reps: 5, rpe: 8),
            ]),
        ]
        let result = engine.suggestion(for: "Bench Press", history: sessions, exerciseType: .compound)
        if case .increaseWeight(let by, let to) = result.type {
            XCTAssertEqual(by, 2.5)
            XCTAssertEqual(to, 62.5)
        } else {
            XCTFail("Expected increaseWeight, got \(result.type)")
        }
    }
    
    // MARK: - Test: Weight Increase (isolation)
    
    func testWeightIncrease_isolation_smallerIncrement() {
        let sessions = [
            makeSession(daysAgo: 1, sets: [
                makeSet(weight: 20, reps: 10, rpe: 7),
            ], targetReps: 10),
            makeSession(daysAgo: 4, sets: [
                makeSet(weight: 18.75, reps: 10, rpe: 7),
            ], targetReps: 10),
        ]
        let result = engine.suggestion(for: "Bicep Curl", history: sessions, exerciseType: .isolation)
        if case .increaseWeight(let by, _) = result.type {
            XCTAssertEqual(by, 1.25)
        } else {
            XCTFail("Expected increaseWeight, got \(result.type)")
        }
    }
    
    // MARK: - Test: Rep Increase (partial reps, low RPE)
    
    func testRepIncrease_partialReps_lowRPE() {
        let sessions = [
            makeSession(daysAgo: 1, sets: [
                makeSet(weight: 60, reps: 4, rpe: 7), // failed target of 5
                makeSet(weight: 60, reps: 4, rpe: 7),
            ], targetReps: 5),
            makeSession(daysAgo: 4, sets: [
                makeSet(weight: 60, reps: 4, rpe: 7),
            ], targetReps: 5),
        ]
        let result = engine.suggestion(for: "Bench Press", history: sessions, exerciseType: .compound)
        if case .increaseReps(let by) = result.type {
            XCTAssertEqual(by, 1)
        } else {
            XCTFail("Expected increaseReps, got \(result.type)")
        }
    }
    
    // MARK: - Test: Deload (2 sessions RPE ≥ 9)
    
    func testDeload_highRPETwoConsecutiveSessions() {
        let sessions = [
            makeSession(daysAgo: 1, sets: [
                makeSet(weight: 100, reps: 5, rpe: 9.5),
                makeSet(weight: 100, reps: 4, rpe: 9),
            ]),
            makeSession(daysAgo: 4, sets: [
                makeSet(weight: 100, reps: 5, rpe: 9),
                makeSet(weight: 100, reps: 3, rpe: 9.5),
            ]),
        ]
        let result = engine.suggestion(for: "Squat", history: sessions, exerciseType: .compound)
        if case .deload(let to, let reason) = result.type {
            XCTAssertTrue(reason.contains("fatigue"))
            XCTAssertTrue(to < 100) // should be ~95
        } else {
            XCTFail("Expected deload, got \(result.type)")
        }
    }
    
    // MARK: - Test: Deload percentage
    
    func testDeloadPercentage_is95Percent() {
        let sessions = [
            makeSession(daysAgo: 1, sets: [makeSet(weight: 200, reps: 3, rpe: 9.5)]),
            makeSession(daysAgo: 4, sets: [makeSet(weight: 200, reps: 3, rpe: 9)]),
        ]
        let result = engine.suggestion(for: "Deadlift", history: sessions, exerciseType: .compound)
        if case .deload(let to, _) = result.type {
            // 200 * 0.95 = 190, rounded to nearest 2.5 = 190.0
            XCTAssertEqual(to, 190.0, accuracy: 2.5)
        } else {
            XCTFail("Expected deload, got \(result.type)")
        }
    }
    
    // MARK: - Test: Volume Stagnation
    
    func testVolumeStagnation_threeSessionsNoIncrease() {
        let sessions = [
            makeSession(daysAgo: 1, sets: [makeSet(weight: 60, reps: 5, rpe: 8.5)]), // vol=300
            makeSession(daysAgo: 7, sets: [makeSet(weight: 60, reps: 5, rpe: 8.5)]), // vol=300
            makeSession(daysAgo: 14, sets: [makeSet(weight: 60, reps: 5, rpe: 8.5)]), // vol=300
        ]
        let result = engine.suggestion(for: "OHP", history: sessions, exerciseType: .compound)
        if case .volumeStagnant = result.type {} else {
            XCTFail("Expected volumeStagnant, got \(result.type)")
        }
    }
    
    // MARK: - Test: Volume Stagnation Detection Helper
    
    func testDetectVolumeStagnation_increasing_returnsFalse() {
        let sessions = [
            makeSession(daysAgo: 1, sets: [makeSet(weight: 65, reps: 5, rpe: 8)]),
            makeSession(daysAgo: 7, sets: [makeSet(weight: 60, reps: 5, rpe: 8)]),
            makeSession(daysAgo: 14, sets: [makeSet(weight: 55, reps: 5, rpe: 8)]),
        ]
        XCTAssertFalse(engine.detectVolumeStagnation(sessions.sorted { $0.date > $1.date }))
    }
    
    // MARK: - Test: Deload Detection Helper
    
    func testDetectDeload_onlyOneHighRPE_returnsFalse() {
        let sessions = [
            makeSession(daysAgo: 1, sets: [makeSet(weight: 100, reps: 5, rpe: 9.5)]),
            makeSession(daysAgo: 4, sets: [makeSet(weight: 100, reps: 5, rpe: 7)]),
        ]
        XCTAssertFalse(engine.detectDeload(sessions.sorted { $0.date > $1.date }))
    }
    
    // MARK: - Test: Maintain when RPE high but only 1 session
    
    func testHighRPE_singleSession_maintain() {
        let session = makeSession(daysAgo: 1, sets: [makeSet(weight: 100, reps: 3, rpe: 9.5)])
        let result = engine.suggestion(for: "Squat", history: [session], exerciseType: .compound)
        if case .maintain = result.type {} else {
            XCTFail("Expected maintain, got \(result.type)")
        }
    }
    
    // MARK: - Test: Maintain when RPE too high for increase (but not deload)
    
    func testHighRPE_notDeload_maintain() {
        let sessions = [
            makeSession(daysAgo: 1, sets: [
                makeSet(weight: 100, reps: 5, rpe: 8.5), // RPE > 8, all reps done
            ]),
            makeSession(daysAgo: 4, sets: [
                makeSet(weight: 100, reps: 5, rpe: 7),
            ]),
        ]
        let result = engine.suggestion(for: "Bench", history: sessions, exerciseType: .compound)
        if case .maintain = result.type {} else {
            XCTFail("Expected maintain, got \(result.type)")
        }
    }
    
    // MARK: - Test: ExerciseSession computed properties
    
    func testExerciseSession_avgRPE() {
        let session = makeSession(daysAgo: 0, sets: [
            makeSet(weight: 60, reps: 5, rpe: 7),
            makeSet(weight: 60, reps: 5, rpe: 9),
        ])
        XCTAssertEqual(session.avgRPE, 8.0, accuracy: 0.01)
    }
    
    func testExerciseSession_totalVolume() {
        let session = makeSession(daysAgo: 0, sets: [
            makeSet(weight: 60, reps: 5, rpe: 7),
            makeSet(weight: 60, reps: 5, rpe: 7),
        ])
        XCTAssertEqual(session.totalVolume, 600.0, accuracy: 0.01)
    }
    
    func testExerciseSession_completedAllTargetReps_true() {
        let session = makeSession(daysAgo: 0, sets: [
            makeSet(weight: 60, reps: 5, rpe: 7),
            makeSet(weight: 60, reps: 6, rpe: 7),
        ], targetReps: 5)
        XCTAssertTrue(session.completedAllTargetReps)
    }
    
    func testExerciseSession_completedAllTargetReps_false() {
        let session = makeSession(daysAgo: 0, sets: [
            makeSet(weight: 60, reps: 4, rpe: 7),
            makeSet(weight: 60, reps: 5, rpe: 7),
        ], targetReps: 5)
        XCTAssertFalse(session.completedAllTargetReps)
    }
}
