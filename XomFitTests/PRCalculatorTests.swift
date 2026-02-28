import XCTest
@testable import XomFit

final class PRCalculatorTests: XCTestCase {
    
    // MARK: - Test Data
    
    let mockUser = User.mock
    
    // MARK: - detectNewPR Tests
    
    func testDetectNewPRWithNoExistingRecords() {
        let set = WorkoutSet(
            id: "set-1",
            exerciseId: "ex-1",
            weight: 225,
            reps: 1,
            rpe: 9,
            isPersonalRecord: true,
            completedAt: Date()
        )
        
        let result = PRCalculator.detectNewPR(set: set, existingPRs: [])
        
        XCTAssertTrue(result.isNewPR)
        XCTAssertEqual(result.prType, .oneRM)
        XCTAssertNil(result.previousBest)
        XCTAssertEqual(result.newWeight, 225)
        XCTAssertNil(result.improvement)
    }
    
    func testDetectNewPRExceedsExisting() {
        let existingPR = PersonalRecord(
            id: "pr-1",
            userId: "user-1",
            exerciseId: "ex-1",
            exerciseName: "Bench Press",
            weight: 225,
            reps: 5,
            date: Date().addingTimeInterval(-86400),
            previousBest: 215
        )
        
        let newSet = WorkoutSet(
            id: "set-2",
            exerciseId: "ex-1",
            weight: 235,
            reps: 5,
            rpe: 8.5,
            isPersonalRecord: true,
            completedAt: Date()
        )
        
        let result = PRCalculator.detectNewPR(set: newSet, existingPRs: [existingPR])
        
        XCTAssertTrue(result.isNewPR)
        XCTAssertEqual(result.prType, .fiveRM)
        XCTAssertEqual(result.previousBest, 225)
        XCTAssertEqual(result.newWeight, 235)
        XCTAssertEqual(result.improvement, 10)
    }
    
    func testDetectNoNewPRIfWeightLess() {
        let existingPR = PersonalRecord(
            id: "pr-1",
            userId: "user-1",
            exerciseId: "ex-1",
            exerciseName: "Bench Press",
            weight: 225,
            reps: 3,
            date: Date().addingTimeInterval(-86400),
            previousBest: 215
        )
        
        let newSet = WorkoutSet(
            id: "set-2",
            exerciseId: "ex-1",
            weight: 220,
            reps: 3,
            rpe: 8,
            isPersonalRecord: false,
            completedAt: Date()
        )
        
        let result = PRCalculator.detectNewPR(set: newSet, existingPRs: [existingPR])
        
        XCTAssertFalse(result.isNewPR)
        XCTAssertNil(result.prType)
    }
    
    func testDetectPRTypeForOne() {
        let set = WorkoutSet(
            id: "set-1",
            exerciseId: "ex-1",
            weight: 300,
            reps: 1,
            rpe: 10,
            isPersonalRecord: true,
            completedAt: Date()
        )
        
        let result = PRCalculator.detectNewPR(set: set, existingPRs: [])
        
        XCTAssertEqual(result.prType, .oneRM)
    }
    
    func testDetectPRTypeForThree() {
        let set = WorkoutSet(
            id: "set-1",
            exerciseId: "ex-1",
            weight: 280,
            reps: 3,
            rpe: 9.5,
            isPersonalRecord: true,
            completedAt: Date()
        )
        
        let result = PRCalculator.detectNewPR(set: set, existingPRs: [])
        
        XCTAssertEqual(result.prType, .threeRM)
    }
    
    func testDetectPRTypeForFive() {
        let set = WorkoutSet(
            id: "set-1",
            exerciseId: "ex-1",
            weight: 250,
            reps: 5,
            rpe: 9,
            isPersonalRecord: true,
            completedAt: Date()
        )
        
        let result = PRCalculator.detectNewPR(set: set, existingPRs: [])
        
        XCTAssertEqual(result.prType, .fiveRM)
    }
    
    func testIgnoreInvalidRepRanges() {
        let set = WorkoutSet(
            id: "set-1",
            exerciseId: "ex-1",
            weight: 200,
            reps: 4,
            rpe: 8,
            isPersonalRecord: false,
            completedAt: Date()
        )
        
        let result = PRCalculator.detectNewPR(set: set, existingPRs: [])
        
        XCTAssertFalse(result.isNewPR)
        XCTAssertNil(result.prType)
    }
    
    // MARK: - detectPRsInWorkout Tests
    
    func testDetectMultiplePRsInWorkout() {
        let workout = Workout(
            id: "w-1",
            userId: "user-1",
            name: "Push Day",
            exercises: [
                WorkoutExercise(
                    id: "we-1",
                    exercise: .benchPress,
                    sets: [
                        WorkoutSet(id: "s-1", exerciseId: "ex-1", weight: 225, reps: 3, rpe: 8, isPersonalRecord: false, completedAt: Date()),
                        WorkoutSet(id: "s-2", exerciseId: "ex-1", weight: 235, reps: 3, rpe: 9, isPersonalRecord: true, completedAt: Date()),
                    ],
                    notes: nil
                ),
                WorkoutExercise(
                    id: "we-2",
                    exercise: .squat,
                    sets: [
                        WorkoutSet(id: "s-3", exerciseId: "ex-2", weight: 315, reps: 5, rpe: 9, isPersonalRecord: true, completedAt: Date()),
                    ],
                    notes: nil
                )
            ],
            startTime: Date().addingTimeInterval(-3600),
            endTime: Date(),
            notes: nil
        )
        
        let detections = PRCalculator.detectPRsInWorkout(workout: workout, existingPRs: [])
        
        XCTAssertEqual(detections.count, 2)
    }
    
    func testDetectNoPRsInWorkout() {
        let workout = Workout(
            id: "w-1",
            userId: "user-1",
            name: "Push Day",
            exercises: [
                WorkoutExercise(
                    id: "we-1",
                    exercise: .benchPress,
                    sets: [
                        WorkoutSet(id: "s-1", exerciseId: "ex-1", weight: 200, reps: 2, rpe: 7, isPersonalRecord: false, completedAt: Date()),
                    ],
                    notes: nil
                )
            ],
            startTime: Date().addingTimeInterval(-3600),
            endTime: Date(),
            notes: nil
        )
        
        let detections = PRCalculator.detectPRsInWorkout(workout: workout, existingPRs: [])
        
        XCTAssertEqual(detections.count, 0)
    }
    
    // MARK: - createPersonalRecords Tests
    
    func testCreatePersonalRecordsFromDetections() {
        let workout = Workout(
            id: "w-1",
            userId: "user-1",
            name: "Push Day",
            exercises: [
                WorkoutExercise(
                    id: "we-1",
                    exercise: .benchPress,
                    sets: [
                        WorkoutSet(id: "s-1", exerciseId: "ex-1", weight: 235, reps: 3, rpe: 9, isPersonalRecord: true, completedAt: Date()),
                    ],
                    notes: nil
                )
            ],
            startTime: Date().addingTimeInterval(-3600),
            endTime: Date(),
            notes: nil
        )
        
        let set = workout.exercises[0].sets[0]
        let detection = PRDetectionResult(
            isNewPR: true,
            prType: .threeRM,
            previousBest: 225,
            newWeight: 235,
            improvement: 10
        )
        
        let records = PRCalculator.createPersonalRecords(
            from: workout,
            detections: [set: detection]
        )
        
        XCTAssertEqual(records.count, 1)
        let record = records[0]
        XCTAssertEqual(record.userId, "user-1")
        XCTAssertEqual(record.exerciseId, "ex-1")
        XCTAssertEqual(record.weight, 235)
        XCTAssertEqual(record.reps, 3)
        XCTAssertEqual(record.previousBest, 225)
    }
    
    // MARK: - estimatedOneRM Tests
    
    func testEstimatedOneRMForSingleRep() {
        let oneRM = PRCalculator.estimatedOneRM(weight: 300, reps: 1)
        XCTAssertEqual(oneRM, 300)
    }
    
    func testEstimatedOneRMForMultipleReps() {
        let estimated = PRCalculator.estimatedOneRM(weight: 225, reps: 5)
        // Formula: 225 * (1 + 5/30) = 225 * 1.167 ≈ 262.5
        let expected = 225 * (1 + 5.0 / 30.0)
        XCTAssertEqual(estimated, expected, accuracy: 0.01)
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceDetectPRWithLargeDataset() {
        var existingPRs: [PersonalRecord] = []
        for i in 0..<1000 {
            existingPRs.append(PersonalRecord(
                id: "pr-\(i)",
                userId: "user-1",
                exerciseId: "ex-\(i % 10)",
                exerciseName: "Exercise \(i % 10)",
                weight: Double(200 + (i % 100)),
                reps: [1, 3, 5][i % 3],
                date: Date().addingTimeInterval(-Double(i * 86400)),
                previousBest: nil
            ))
        }
        
        let set = WorkoutSet(
            id: "set-1",
            exerciseId: "ex-5",
            weight: 350,
            reps: 1,
            rpe: 9,
            isPersonalRecord: true,
            completedAt: Date()
        )
        
        measure {
            _ = PRCalculator.detectNewPR(set: set, existingPRs: existingPRs)
        }
    }
}
