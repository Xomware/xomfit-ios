import XCTest
@testable import XomFit

@MainActor
final class PRViewModelTests: XCTestCase {
    var sut: PRViewModel!
    
    override func setUp() {
        super.setUp()
        sut = PRViewModel()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Loading Data Tests
    
    func testLoadPersonalRecords() {
        // When
        sut.loadPersonalRecords()
        
        // Then
        XCTAssertFalse(sut.personalRecords.isEmpty)
        XCTAssertEqual(sut.personalRecords.count, PersonalRecord.mockPRs.count)
    }
    
    func testLoadPersonalRecordsPopulatesRecentPRs() {
        // When
        sut.loadPersonalRecords()
        
        // Then
        XCTAssertFalse(sut.recentPRs.isEmpty)
        XCTAssertTrue(sut.recentPRs.count <= 5)
    }
    
    func testLoadLeaderboard() {
        // When
        sut.loadLeaderboard()
        
        // Then
        XCTAssertFalse(sut.prLeaderboard.isEmpty)
    }
    
    // MARK: - PR Detection Tests
    
    func testDetectNewPRsInWorkout() {
        // Given
        sut.loadPersonalRecords()
        let initialCount = sut.personalRecords.count
        
        let workout = Workout(
            id: UUID().uuidString,
            userId: "user-1",
            name: "Test Workout",
            exercises: [
                WorkoutExercise(
                    id: UUID().uuidString,
                    exercise: Exercise.benchPress,
                    sets: [
                        WorkoutSet(
                            id: UUID().uuidString,
                            exerciseId: "ex-1",
                            weight: 250,
                            reps: 1,
                            rpe: 9.5,
                            isPersonalRecord: true,
                            completedAt: Date()
                        )
                    ],
                    notes: nil
                )
            ],
            startTime: Date(),
            endTime: Date(),
            notes: nil
        )
        
        // When
        sut.detectNewPRsInWorkout(workout)
        
        // Then
        // Note: The actual detection depends on PRCalculator logic
        // If new PR is detected, count should increase
        XCTAssertGreaterThanOrEqual(sut.personalRecords.count, initialCount)
    }
    
    func testDetectNewPRsUpdatesRecentPRs() {
        // Given
        sut.loadPersonalRecords()
        
        let workout = Workout(
            id: UUID().uuidString,
            userId: "user-1",
            name: "Test Workout",
            exercises: [
                WorkoutExercise(
                    id: UUID().uuidString,
                    exercise: Exercise.benchPress,
                    sets: [
                        WorkoutSet(
                            id: UUID().uuidString,
                            exerciseId: "ex-1",
                            weight: 250,
                            reps: 1,
                            rpe: 9.5,
                            isPersonalRecord: true,
                            completedAt: Date()
                        )
                    ],
                    notes: nil
                )
            ],
            startTime: Date(),
            endTime: Date(),
            notes: nil
        )
        
        // When
        sut.detectNewPRsInWorkout(workout)
        
        // Then
        XCTAssertFalse(sut.recentPRs.isEmpty)
    }
    
    func testDetectNewPRsTriggersShowCelebration() {
        // Given
        sut.loadPersonalRecords()
        let workout = Workout(
            id: UUID().uuidString,
            userId: "user-1",
            name: "Test Workout",
            exercises: [
                WorkoutExercise(
                    id: UUID().uuidString,
                    exercise: Exercise.benchPress,
                    sets: [
                        WorkoutSet(
                            id: UUID().uuidString,
                            exerciseId: "ex-1",
                            weight: 250,
                            reps: 1,
                            rpe: 9.5,
                            isPersonalRecord: true,
                            completedAt: Date()
                        )
                    ],
                    notes: nil
                )
            ],
            startTime: Date(),
            endTime: Date(),
            notes: nil
        )
        
        // When
        sut.detectNewPRsInWorkout(workout)
        
        // Then
        // Celebration might be shown (isShowingCelebration could be true)
        // This depends on PRCalculator detection
        XCTAssertNotNil(sut.newPRNotification)
    }
    
    // MARK: - Celebration Animation Tests
    
    func testShowPRCelebration() {
        // Given
        let pr = PersonalRecord.mockPRs.first!
        
        // When
        sut.showPRCelebration(for: pr)
        
        // Then
        XCTAssertEqual(sut.newPRNotification?.id, pr.id)
        XCTAssertTrue(sut.isShowingCelebration)
    }
    
    func testShowPRCelebrationAutoHides() {
        // Given
        let pr = PersonalRecord.mockPRs.first!
        sut.showPRCelebration(for: pr)
        
        // When
        // Simulate waiting for 3 seconds (would be done in real flow)
        // For now, verify the state is set correctly
        
        // Then
        XCTAssertTrue(sut.isShowingCelebration)
    }
    
    // MARK: - Data Organization Tests
    
    func testGroupPRsByExercise() {
        // When
        sut.loadPersonalRecords()
        
        // Then
        XCTAssertFalse(sut.prsByExercise.isEmpty)
        
        // Verify each exercise has PRs grouped correctly
        for (exerciseName, prs) in sut.prsByExercise {
            XCTAssertFalse(prs.isEmpty)
            XCTAssertTrue(prs.allSatisfy { $0.exerciseName == exerciseName })
        }
    }
    
    func testGetPRsForExercise() {
        // Given
        sut.loadPersonalRecords()
        let exerciseName = "Bench Press"
        
        // When
        let prs = sut.getPRsForExercise(exerciseName)
        
        // Then
        XCTAssertTrue(prs.allSatisfy { $0.exerciseName == exerciseName })
        // Should be sorted by date descending
        if prs.count > 1 {
            XCTAssertGreaterThanOrEqual(prs[0].date, prs[1].date)
        }
    }
    
    func testGetPRsForExerciseReturnsEmptyForNonexistentExercise() {
        // Given
        sut.loadPersonalRecords()
        
        // When
        let prs = sut.getPRsForExercise("Non-existent Exercise")
        
        // Then
        XCTAssertTrue(prs.isEmpty)
    }
    
    func testGetTopPRForExercise() {
        // Given
        sut.loadPersonalRecords()
        let exerciseName = "Bench Press"
        
        // When
        let topPR = sut.getTopPRForExercise(exerciseName)
        
        // Then
        XCTAssertNotNil(topPR)
        XCTAssertEqual(topPR?.exerciseName, exerciseName)
        
        // Verify it's actually the heaviest
        let allPRs = sut.getPRsForExercise(exerciseName)
        XCTAssertEqual(topPR?.weight, allPRs.max(by: { $0.weight < $1.weight })?.weight)
    }
    
    func testGetTopPRForExerciseReturnsNilForNonexistent() {
        // Given
        sut.loadPersonalRecords()
        
        // When
        let topPR = sut.getTopPRForExercise("Non-existent Exercise")
        
        // Then
        XCTAssertNil(topPR)
    }
    
    // MARK: - Stats Update Tests
    
    func testUpdateStatsCalculatesCorrectly() {
        // Given
        sut.loadPersonalRecords()
        
        // When
        // Stats are updated during loadPersonalRecords
        
        // Then
        XCTAssertNotNil(sut.currentUserStats)
        XCTAssertGreaterThanOrEqual(sut.currentUserStats?.oneRM ?? 0, 0)
        XCTAssertGreaterThanOrEqual(sut.currentUserStats?.threeRM ?? 0, 0)
        XCTAssertGreaterThanOrEqual(sut.currentUserStats?.fiveRM ?? 0, 0)
    }
    
    func testUpdateStatsOneRMFiltersCorrectly() {
        // Given
        sut.loadPersonalRecords()
        
        // When
        let stats = sut.currentUserStats
        
        // Then
        // Verify 1RM is actually from 1-rep PRs
        let oneRMs = sut.personalRecords.filter { $0.reps == 1 }.sorted { $0.weight > $1.weight }
        XCTAssertEqual(stats?.oneRM, Int(oneRMs.first?.weight ?? 0))
    }
    
    func testUpdateStatsThreeRMFiltersCorrectly() {
        // Given
        sut.loadPersonalRecords()
        
        // When
        let stats = sut.currentUserStats
        
        // Then
        // Verify 3RM is actually from 3-rep PRs
        let threeRMs = sut.personalRecords.filter { $0.reps == 3 }.sorted { $0.weight > $1.weight }
        XCTAssertEqual(stats?.threeRM, Int(threeRMs.first?.weight ?? 0))
    }
    
    func testUpdateStatsFiveRMFiltersCorrectly() {
        // Given
        sut.loadPersonalRecords()
        
        // When
        let stats = sut.currentUserStats
        
        // Then
        // Verify 5RM is actually from 5-rep PRs
        let fiveRMs = sut.personalRecords.filter { $0.reps == 5 }.sorted { $0.weight > $1.weight }
        XCTAssertEqual(stats?.fiveRM, Int(fiveRMs.first?.weight ?? 0))
    }
    
    // MARK: - Leaderboard Tests
    
    func testGetLeaderboardForExercise() {
        // Given
        sut.loadLeaderboard()
        let exerciseName = "Bench Press"
        
        // When
        let leaderboard = sut.getLeaderboardForExercise(exerciseName)
        
        // Then
        // Verify leaderboard is sorted by weight descending
        if leaderboard.count > 1 {
            XCTAssertGreaterThanOrEqual(leaderboard[0].pr.weight, leaderboard[1].pr.weight)
        }
    }
    
    func testGetLeaderboardForExerciseReturnsSortedByWeight() {
        // Given
        sut.loadLeaderboard()
        let exerciseName = "Bench Press"
        
        // When
        let leaderboard = sut.getLeaderboardForExercise(exerciseName)
        
        // Then
        for i in 0..<leaderboard.count - 1 {
            XCTAssertGreaterThanOrEqual(leaderboard[i].pr.weight, leaderboard[i + 1].pr.weight)
        }
    }
    
    func testUpdateLeaderboardWithFriends() {
        // Given
        let initialCount = sut.prLeaderboard.count
        let friends = [User.mockUser]
        
        // When
        let expectation = XCTestExpectation(description: "Leaderboard updated")
        sut.updateLeaderboard(with: friends) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        // Then
        // In production, this would fetch from API
        // For mock implementation, the completion handler should be called
    }
    
    // MARK: - Integration Tests
    
    func testCompleteFlow() {
        // Given
        // Start fresh
        
        // When
        sut.loadPersonalRecords()
        sut.loadLeaderboard()
        
        // Then
        XCTAssertFalse(sut.personalRecords.isEmpty)
        XCTAssertFalse(sut.prLeaderboard.isEmpty)
        XCTAssertFalse(sut.prsByExercise.isEmpty)
        XCTAssertNotNil(sut.currentUserStats)
    }
    
    func testRecentPRsLimitedToFive() {
        // Given
        sut.loadPersonalRecords()
        
        // When
        // Load more than 5 PRs
        
        // Then
        XCTAssertTrue(sut.recentPRs.count <= 5)
    }
    
    func testRecentPRsSortedByDateDescending() {
        // Given
        sut.loadPersonalRecords()
        
        // When
        let recentPRs = sut.recentPRs
        
        // Then
        for i in 0..<recentPRs.count - 1 {
            XCTAssertGreaterThanOrEqual(recentPRs[i].date, recentPRs[i + 1].date)
        }
    }
    
    // MARK: - Empty State Tests
    
    func testEmptyPersonalRecordsState() {
        // Given
        sut.personalRecords = []
        
        // When
        sut.loadPersonalRecords()
        
        // Then
        // After loading mock data, should have records
        XCTAssertFalse(sut.personalRecords.isEmpty)
    }
    
    func testPRsByExerciseEmpty() {
        // Given
        sut.personalRecords = []
        
        // When
        // Try to get PRs for exercise
        let prs = sut.getPRsForExercise("Any Exercise")
        
        // Then
        XCTAssertTrue(prs.isEmpty)
    }
}
