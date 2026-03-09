import XCTest
@testable import XomFit

@MainActor
final class ChallengeViewModelTests: XCTestCase {

    var viewModel: ChallengeViewModel!

    override func setUp() {
        super.setUp()
        viewModel = ChallengeViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialState() {
        XCTAssertTrue(viewModel.challenges.isEmpty)
        XCTAssertTrue(viewModel.activeChallenges.isEmpty)
        XCTAssertNil(viewModel.selectedChallenge)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.userChallenges.isEmpty)
    }

    // MARK: - Fetch Challenges

    func testFetchChallengesUpdatesState() async {
        await viewModel.fetchChallenges()
        // With mock service, result is empty but state should be valid
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertTrue(viewModel.challenges.isEmpty)
    }

    func testFetchUserChallenges() async {
        await viewModel.fetchUserChallenges(userId: "user_123")
        XCTAssertFalse(viewModel.isLoading)
    }

    func testFetchChallengeDetail() async {
        await viewModel.fetchChallengeDetail(challengeId: "nonexistent")
        XCTAssertFalse(viewModel.isLoading)
        // Should produce error since mock returns empty
        XCTAssertNotNil(viewModel.errorMessage)
    }

    // MARK: - Create Challenge

    func testCreateChallenge() async {
        let challenge = await viewModel.createChallenge(
            type: .mostVolume,
            participantIds: ["user1", "user2"]
        )
        XCTAssertNotNil(challenge)
        XCTAssertEqual(challenge?.type, .mostVolume)
        XCTAssertEqual(challenge?.participants.count, 2)
        XCTAssertEqual(challenge?.status, .upcoming)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testCreateStreakChallenge() async {
        let challenge = await viewModel.createChallenge(
            type: .longestStreak,
            participantIds: ["user1", "user2"]
        )
        XCTAssertNotNil(challenge)
        XCTAssertEqual(challenge?.type, .longestStreak)
    }

    func testCreateWeeklyStreakChallenge() async {
        let challenge = await viewModel.createChallenge(
            type: .weeklyStreak,
            participantIds: ["user1"]
        )
        XCTAssertNotNil(challenge)
        XCTAssertEqual(challenge?.type, .weeklyStreak)
    }

    func testCreateChallengeEndDate() async {
        let startDate = Date()
        let challenge = await viewModel.createChallenge(
            type: .mostVolume,
            participantIds: ["user1"],
            startDate: startDate
        )
        XCTAssertNotNil(challenge)
        let expectedEnd = Calendar.current.date(byAdding: .day, value: 7, to: startDate)!
        let diff = abs(challenge!.endDate.timeIntervalSince(expectedEnd))
        XCTAssertLessThan(diff, 1.0) // Within 1 second
    }

    // MARK: - Join / Decline Challenge

    func testJoinChallenge() async {
        let success = await viewModel.joinChallenge(challengeId: "ch1")
        XCTAssertTrue(success)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testDeclineChallenge() async {
        await viewModel.declineChallenge(challengeId: "ch1")
        // Should complete without error for mock
        XCTAssertNil(viewModel.errorMessage)
    }

    // MARK: - Update Results

    func testUpdateChallengeResults() async {
        await viewModel.updateChallengeResults(
            challengeId: "ch1",
            userId: "user1",
            value: 5000
        )
        // Should not crash; error message may be set due to mock
        XCTAssertFalse(viewModel.isLoading)
    }

    // MARK: - Friends

    func testFetchFriendsForChallenge() async {
        let friends = await viewModel.fetchFriendsForChallenge()
        // Mock returns empty
        XCTAssertTrue(friends.isEmpty)
    }

    // MARK: - Error Handling

    func testErrorMessageClearable() {
        viewModel.errorMessage = "Test error"
        XCTAssertNotNil(viewModel.errorMessage)
        viewModel.errorMessage = nil
        XCTAssertNil(viewModel.errorMessage)
    }
}
