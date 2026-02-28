import XCTest
@testable import XomFit

@MainActor
final class WorkoutLoggerViewModelTests: XCTestCase {
    var sut: WorkoutLoggerViewModel!
    
    override func setUp() {
        super.setUp()
        sut = WorkoutLoggerViewModel()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Workout Lifecycle Tests
    
    func testStartWorkout() {
        // Given
        let workoutName = "Chest Day"
        
        // When
        sut.startWorkout(name: workoutName)
        
        // Then
        XCTAssertNotNil(sut.activeWorkout)
        XCTAssertEqual(sut.activeWorkout?.name, workoutName)
        XCTAssertTrue(sut.isWorkoutActive)
        XCTAssertEqual(sut.elapsedTime, 0)
    }
    
    func testFinishWorkout() {
        // Given
        sut.startWorkout(name: "Test")
        
        // When
        sut.finishWorkout()
        
        // Then
        XCTAssertFalse(sut.isWorkoutActive)
        XCTAssertNotNil(sut.activeWorkout?.endTime)
    }
    
    func testCancelWorkout() {
        // Given
        sut.startWorkout(name: "Test")
        
        // When
        sut.cancelWorkout()
        
        // Then
        XCTAssertFalse(sut.isWorkoutActive)
        XCTAssertNil(sut.activeWorkout)
    }
    
    // MARK: - Exercise Management Tests
    
    func testAddExercise() {
        // Given
        sut.startWorkout(name: "Test")
        let exercise = Exercise.benchPress
        
        // When
        sut.addExercise(exercise)
        
        // Then
        XCTAssertEqual(sut.activeWorkout?.exercises.count, 1)
        XCTAssertEqual(sut.activeWorkout?.exercises.first?.exercise.id, exercise.id)
    }
    
    func testAddMultipleExercises() {
        // Given
        sut.startWorkout(name: "Test")
        let exercise1 = Exercise.benchPress
        let exercise2 = Exercise.squat
        
        // When
        sut.addExercise(exercise1)
        sut.addExercise(exercise2)
        
        // Then
        XCTAssertEqual(sut.activeWorkout?.exercises.count, 2)
    }
    
    func testQuickAddExerciseFromPrevious() {
        // Given
        sut.startWorkout(name: "Test")
        let exercise = Exercise.deadlift
        
        // When
        sut.quickAddExerciseFromPrevious(exercise)
        
        // Then
        XCTAssertEqual(sut.activeWorkout?.exercises.count, 1)
        XCTAssertEqual(sut.recentExercises.first?.id, exercise.id)
    }
    
    func testRemoveExercise() {
        // Given
        sut.startWorkout(name: "Test")
        sut.addExercise(Exercise.benchPress)
        sut.addExercise(Exercise.squat)
        
        // When
        sut.removeExercise(at: 0)
        
        // Then
        XCTAssertEqual(sut.activeWorkout?.exercises.count, 1)
    }
    
    // MARK: - Set Logging Tests
    
    func testAddSet() {
        // Given
        sut.startWorkout(name: "Test")
        sut.addExercise(Exercise.benchPress)
        
        // When
        sut.addSet(to: 0, weight: 225, reps: 5, rpe: 8)
        
        // Then
        XCTAssertEqual(sut.activeWorkout?.exercises[0].sets.count, 1)
        let set = sut.activeWorkout?.exercises[0].sets.first
        XCTAssertEqual(set?.weight, 225)
        XCTAssertEqual(set?.reps, 5)
        XCTAssertEqual(set?.rpe, 8)
    }
    
    func testAddMultipleSets() {
        // Given
        sut.startWorkout(name: "Test")
        sut.addExercise(Exercise.benchPress)
        
        // When
        sut.addSet(to: 0, weight: 225, reps: 5, rpe: 8)
        sut.addSet(to: 0, weight: 235, reps: 3, rpe: 9)
        sut.addSet(to: 0, weight: 245, reps: 1, rpe: 9.5)
        
        // Then
        XCTAssertEqual(sut.activeWorkout?.exercises[0].sets.count, 3)
    }
    
    func testAddSetClearsInputs() {
        // Given
        sut.startWorkout(name: "Test")
        sut.addExercise(Exercise.benchPress)
        sut.inputWeight = "225"
        sut.inputReps = "5"
        sut.inputRPE = "8"
        
        // When
        sut.addSet(to: 0, weight: 225, reps: 5, rpe: 8)
        
        // Then
        XCTAssertEqual(sut.inputWeight, "")
        XCTAssertEqual(sut.inputReps, "")
        XCTAssertEqual(sut.inputRPE, "")
    }
    
    func testDeleteSet() {
        // Given
        sut.startWorkout(name: "Test")
        sut.addExercise(Exercise.benchPress)
        sut.addSet(to: 0, weight: 225, reps: 5)
        sut.addSet(to: 0, weight: 235, reps: 3)
        
        // When
        sut.deleteSet(from: 0, setIndex: 0)
        
        // Then
        XCTAssertEqual(sut.activeWorkout?.exercises[0].sets.count, 1)
        XCTAssertEqual(sut.activeWorkout?.exercises[0].sets.first?.weight, 235)
    }
    
    func testEditSet() {
        // Given
        sut.startWorkout(name: "Test")
        sut.addExercise(Exercise.benchPress)
        sut.addSet(to: 0, weight: 225, reps: 5, rpe: 8)
        
        // When
        sut.editSet(at: 0, setIndex: 0, weight: 245, reps: 3, rpe: 9)
        
        // Then
        let set = sut.activeWorkout?.exercises[0].sets.first
        XCTAssertEqual(set?.weight, 245)
        XCTAssertEqual(set?.reps, 3)
        XCTAssertEqual(set?.rpe, 9)
    }
    
    // MARK: - Input Validation Tests
    
    func testValidateInputsWithValidData() {
        // Given
        sut.inputWeight = "225"
        sut.inputReps = "5"
        
        // When
        let (valid, weight, reps) = sut.validateInputs()
        
        // Then
        XCTAssertTrue(valid)
        XCTAssertEqual(weight, 225)
        XCTAssertEqual(reps, 5)
    }
    
    func testValidateInputsWithMissingWeight() {
        // Given
        sut.inputWeight = ""
        sut.inputReps = "5"
        
        // When
        let (valid, _, _) = sut.validateInputs()
        
        // Then
        XCTAssertFalse(valid)
    }
    
    func testValidateInputsWithMissingReps() {
        // Given
        sut.inputWeight = "225"
        sut.inputReps = ""
        
        // When
        let (valid, _, _) = sut.validateInputs()
        
        // Then
        XCTAssertFalse(valid)
    }
    
    func testValidateInputsWithZeroWeight() {
        // Given
        sut.inputWeight = "0"
        sut.inputReps = "5"
        
        // When
        let (valid, _, _) = sut.validateInputs()
        
        // Then
        XCTAssertFalse(valid)
    }
    
    func testValidateInputsWithZeroReps() {
        // Given
        sut.inputWeight = "225"
        sut.inputReps = "0"
        
        // When
        let (valid, _, _) = sut.validateInputs()
        
        // Then
        XCTAssertFalse(valid)
    }
    
    func testValidateInputsWithNegativeValues() {
        // Given
        sut.inputWeight = "-225"
        sut.inputReps = "-5"
        
        // When
        let (valid, _, _) = sut.validateInputs()
        
        // Then
        XCTAssertFalse(valid)
    }
    
    func testValidateInputsWithDecimalReps() {
        // Given
        sut.inputWeight = "225"
        sut.inputReps = "5.5"
        
        // When
        let (valid, _, _) = sut.validateInputs()
        
        // Then
        XCTAssertFalse(valid)
    }
    
    // MARK: - Rest Timer Tests
    
    func testStartRestTimer() {
        // Given
        let duration = 60.0
        
        // When
        sut.startRestTimer(duration: duration)
        
        // Then
        XCTAssertTrue(sut.isRestTimerRunning)
        XCTAssertTrue(sut.showingRestTimer)
        XCTAssertEqual(sut.restTimeRemaining, duration)
    }
    
    func testStopRestTimer() {
        // Given
        sut.startRestTimer(duration: 60)
        
        // When
        sut.stopRestTimer()
        
        // Then
        XCTAssertFalse(sut.isRestTimerRunning)
        XCTAssertEqual(sut.restTimeRemaining, 0)
    }
    
    func testSkipRestTimer() {
        // Given
        sut.startRestTimer(duration: 60)
        
        // When
        sut.skipRestTimer()
        
        // Then
        XCTAssertFalse(sut.showingRestTimer)
        XCTAssertFalse(sut.isRestTimerRunning)
    }
    
    func testPauseRestTimer() {
        // Given
        sut.startRestTimer(duration: 60)
        
        // When
        sut.pauseRestTimer()
        
        // Then
        XCTAssertFalse(sut.isRestTimerRunning)
    }
    
    func testUseDefaultRestDuration() {
        // When
        sut.startRestTimer()
        
        // Then
        XCTAssertEqual(sut.restTimeRemaining, sut.selectedRestDuration)
    }
    
    // MARK: - Statistics Tests
    
    func testGetWorkoutStats() {
        // Given
        sut.startWorkout(name: "Test")
        sut.addExercise(Exercise.benchPress)
        sut.addSet(to: 0, weight: 225, reps: 5)
        sut.addSet(to: 0, weight: 235, reps: 3)
        
        // When
        let (totalSets, totalVolume) = sut.getWorkoutStats()
        
        // Then
        XCTAssertEqual(totalSets, 2)
        XCTAssertEqual(totalVolume, 225 * 5 + 235 * 3)
    }
    
    func testGetWorkoutStatsEmpty() {
        // Given
        sut.startWorkout(name: "Test")
        
        // When
        let (totalSets, totalVolume) = sut.getWorkoutStats()
        
        // Then
        XCTAssertEqual(totalSets, 0)
        XCTAssertEqual(totalVolume, 0)
    }
    
    // MARK: - Time Formatting Tests
    
    func testFormatTimeSeconds() {
        // When
        let formatted = sut.formatTime(30)
        
        // Then
        XCTAssertEqual(formatted, "00:30")
    }
    
    func testFormatTimeMinutes() {
        // When
        let formatted = sut.formatTime(90)
        
        // Then
        XCTAssertEqual(formatted, "01:30")
    }
    
    func testFormatTimeHours() {
        // When
        let formatted = sut.formatTime(3661)
        
        // Then
        XCTAssertEqual(formatted, "1:01:01")
    }
    
    func testFormatTimeZero() {
        // When
        let formatted = sut.formatTime(0)
        
        // Then
        XCTAssertEqual(formatted, "00:00")
    }
    
    // MARK: - Integration Tests
    
    func testCompleteWorkoutFlow() {
        // Given
        let workoutName = "Full Body"
        
        // Start workout
        sut.startWorkout(name: workoutName)
        XCTAssertTrue(sut.isWorkoutActive)
        
        // Add exercises
        sut.addExercise(Exercise.benchPress)
        sut.addExercise(Exercise.squat)
        XCTAssertEqual(sut.activeWorkout?.exercises.count, 2)
        
        // Log sets for first exercise
        sut.inputWeight = "225"
        sut.inputReps = "5"
        let (valid1, weight1, reps1) = sut.validateInputs()
        XCTAssertTrue(valid1)
        sut.addSet(to: 0, weight: weight1!, reps: reps1!)
        
        // Log another set
        sut.inputWeight = "235"
        sut.inputReps = "3"
        let (valid2, weight2, reps2) = sut.validateInputs()
        XCTAssertTrue(valid2)
        sut.addSet(to: 0, weight: weight2!, reps: reps2!)
        
        // Verify stats
        let (totalSets, totalVolume) = sut.getWorkoutStats()
        XCTAssertEqual(totalSets, 2)
        XCTAssertEqual(totalVolume, 225 * 5 + 235 * 3)
        
        // Finish workout
        sut.finishWorkout()
        XCTAssertFalse(sut.isWorkoutActive)
        XCTAssertNotNil(sut.activeWorkout?.endTime)
    }
}
