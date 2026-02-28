import XCTest
@testable import XomFit

final class ChallengeTests: XCTestCase {
    
    var sut: BadgeSystem!
    
    override func setUp() {
        super.setUp()
        sut = BadgeSystem()
    }
    
    override func tearDown() {
        super.tearDown()
        sut = nil
    }
    
    // MARK: - Challenge Type Tests
    
    func testChallengeTypeDuration() {
        XCTAssertEqual(ChallengeType.mostVolume.durationDays, 7)
        XCTAssertEqual(ChallengeType.heaviestBench.durationDays, 7)
        XCTAssertEqual(ChallengeType.mostWorkouts.durationDays, 30)
        XCTAssertEqual(ChallengeType.fastestMile.durationDays, 30)
        XCTAssertEqual(ChallengeType.strengthGain.durationDays, 30)
    }
    
    func testChallengeTypeDisplayName() {
        XCTAssertEqual(ChallengeType.mostVolume.displayName, "Most Volume")
        XCTAssertEqual(ChallengeType.heaviestBench.displayName, "Heaviest Bench")
        XCTAssertEqual(ChallengeType.mostWorkouts.displayName, "Most Workouts")
    }
    
    // MARK: - Challenge Active Status Tests
    
    func testChallengeIsActive() {
        let startDate = Date()
        let endDate = Date().addingTimeInterval(86400 * 7)
        
        let challenge = Challenge(
            id: "test",
            type: .mostVolume,
            status: .active,
            createdBy: "user1",
            participants: ["user1", "user2"],
            startDate: startDate,
            endDate: endDate,
            results: [],
            createdAt: Date(),
            updatedAt: Date()
        )
        
        XCTAssertTrue(challenge.isActive)
    }
    
    func testChallengeNotActiveAfterEnd() {
        let startDate = Date().addingTimeInterval(-86400 * 10)
        let endDate = Date().addingTimeInterval(-86400)
        
        let challenge = Challenge(
            id: "test",
            type: .mostVolume,
            status: .completed,
            createdBy: "user1",
            participants: ["user1", "user2"],
            startDate: startDate,
            endDate: endDate,
            results: [],
            createdAt: Date(),
            updatedAt: Date()
        )
        
        XCTAssertFalse(challenge.isActive)
    }
    
    func testChallengeProgressPercentage() {
        let startDate = Date()
        let endDate = Date().addingTimeInterval(86400 * 7)
        
        let challenge = Challenge(
            id: "test",
            type: .mostVolume,
            status: .active,
            createdBy: "user1",
            participants: ["user1", "user2"],
            startDate: startDate,
            endDate: endDate,
            results: [],
            createdAt: Date(),
            updatedAt: Date()
        )
        
        XCTAssertGreater(challenge.progressPercentage, 0)
        XCTAssertLessThanOrEqual(challenge.progressPercentage, 1.0)
    }
    
    func testChallengeDaysRemaining() {
        let startDate = Date()
        let endDate = Date().addingTimeInterval(86400 * 7)
        
        let challenge = Challenge(
            id: "test",
            type: .mostVolume,
            status: .active,
            createdBy: "user1",
            participants: ["user1", "user2"],
            startDate: startDate,
            endDate: endDate,
            results: [],
            createdAt: Date(),
            updatedAt: Date()
        )
        
        XCTAssertGreater(challenge.daysRemaining, 0)
        XCTAssertLessThanOrEqual(challenge.daysRemaining, 7)
    }
    
    // MARK: - Badge System Tests
    
    func testBadgeAward() {
        let userId = "test_user"
        let badgeType = BadgeSystem.BadgeType.firstPlace
        
        let badge = sut.awardBadge(badgeType, to: userId)
        
        XCTAssertNotNil(badge)
        XCTAssertEqual(badge?.name, "First Place")
        XCTAssertTrue(sut.hasBadge(badgeType, for: userId))
    }
    
    func testBadgeDuplicateNotAwarded() {
        let userId = "test_user"
        let badgeType = BadgeSystem.BadgeType.firstPlace
        
        let badge1 = sut.awardBadge(badgeType, to: userId)
        let badge2 = sut.awardBadge(badgeType, to: userId)
        
        XCTAssertNotNil(badge1)
        XCTAssertNil(badge2)
    }
    
    func testGetUserBadges() {
        let userId = "test_user"
        
        _ = sut.awardBadge(.firstPlace, to: userId)
        _ = sut.awardBadge(.streakMaster, to: userId)
        
        let badges = sut.getBadges(for: userId)
        
        XCTAssertEqual(badges.count, 2)
    }
    
    func testStreakBadges() {
        let userId = "test_user"
        
        let badges7 = sut.checkStreakBadges(userId: userId, streakCount: 7)
        XCTAssertGreater(badges7.count, 0)
        
        let badges14 = sut.checkStreakBadges(userId: userId, streakCount: 14)
        XCTAssertGreater(badges14.count, 0)
        
        let badges0 = sut.checkStreakBadges(userId: userId, streakCount: 0)
        XCTAssertEqual(badges0.count, 0)
    }
    
    func testPRBadge() {
        let userId = "test_user"
        
        let badge = sut.checkPRBadges(userId: userId, prCount: 5)
        XCTAssertNotNil(badge)
        XCTAssertGreater(badge?.count ?? 0, 0)
    }
    
    func testAllStarBadge() {
        let userId = "test_user"
        
        let badge = sut.checkAllStarBadge(userId: userId, completedChallenges: 5)
        XCTAssertNotNil(badge)
        XCTAssertEqual(badge?.name, "All-Star")
    }
    
    // MARK: - Leaderboard Calculation Tests
    
    func testLeaderboardRankCalculation() {
        let entries = [
            LeaderboardEntry(id: "1", userId: "user1", userName: "User 1", userAvatar: nil, rank: 1, value: 5000, unit: "lbs", streak: 0, badges: []),
            LeaderboardEntry(id: "2", userId: "user2", userName: "User 2", userAvatar: nil, rank: 2, value: 4000, unit: "lbs", streak: 0, badges: []),
            LeaderboardEntry(id: "3", userId: "user3", userName: "User 3", userAvatar: nil, rank: 3, value: 3000, unit: "lbs", streak: 0, badges: [])
        ]
        
        XCTAssertEqual(entries[0].rank, 1)
        XCTAssertEqual(entries[1].rank, 2)
        XCTAssertEqual(entries[2].rank, 3)
    }
    
    func testLeaderboardValueFormatting() {
        let entry = LeaderboardEntry(
            id: "1",
            userId: "user1",
            userName: "User 1",
            userAvatar: nil,
            rank: 1,
            value: 5000.5,
            unit: "lbs",
            streak: 0,
            badges: []
        )
        
        XCTAssertEqual(entry.formattedValue, "5001 lbs")
    }
    
    func testLeaderboardWorkoutFormatting() {
        let entry = LeaderboardEntry(
            id: "1",
            userId: "user1",
            userName: "User 1",
            userAvatar: nil,
            rank: 1,
            value: 25,
            unit: "workouts",
            streak: 0,
            badges: []
        )
        
        XCTAssertEqual(entry.formattedValue, "25 workouts")
    }
    
    // MARK: - Challenge Result Tests
    
    func testChallengeResultCreation() {
        let result = ChallengeResult(
            id: "result1",
            challengeId: "challenge1",
            userId: "user1",
            rank: 1,
            value: 5000,
            unit: "lbs",
            lastUpdated: Date()
        )
        
        XCTAssertEqual(result.challengeId, "challenge1")
        XCTAssertEqual(result.value, 5000)
        XCTAssertEqual(result.formattedValue, "5000 lbs")
    }
    
    // MARK: - Streak Tests
    
    func testStreakActiveToday() {
        let streak = Streak(
            id: "streak1",
            userId: "user1",
            challengeId: "challenge1",
            count: 7,
            lastWorkoutDate: Date()
        )
        
        XCTAssertTrue(streak.isActive)
    }
    
    func testStreakInactive() {
        let lastWorkoutDate = Date().addingTimeInterval(-86400 * 3)
        let streak = Streak(
            id: "streak1",
            userId: "user1",
            challengeId: "challenge1",
            count: 7,
            lastWorkoutDate: lastWorkoutDate
        )
        
        XCTAssertFalse(streak.isActive)
    }
    
    // MARK: - Challenge Creation Tests
    
    func testChallengeCreation() {
        let challengeId = UUID().uuidString
        let participantIds = ["user1", "user2", "user3"]
        let challengeType = ChallengeType.mostVolume
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 7, to: startDate)!
        
        let challenge = Challenge(
            id: challengeId,
            type: challengeType,
            status: .upcoming,
            createdBy: "creator",
            participants: participantIds,
            startDate: startDate,
            endDate: endDate,
            results: [],
            createdAt: Date(),
            updatedAt: Date()
        )
        
        XCTAssertEqual(challenge.id, challengeId)
        XCTAssertEqual(challenge.participants.count, 3)
        XCTAssertEqual(challenge.status, .upcoming)
    }
    
    func testChallengeInitializesResults() {
        let participantIds = ["user1", "user2", "user3"]
        let results = participantIds.map { userId in
            ChallengeResult(
                id: UUID().uuidString,
                challengeId: "challenge1",
                userId: userId,
                rank: participantIds.count,
                value: 0,
                unit: "lbs",
                lastUpdated: Date()
            )
        }
        
        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results.allSatisfy { $0.value == 0 })
    }
}

// MARK: - Leaderboard Calculation Tests
final class LeaderboardCalculationTests: XCTestCase {
    
    func testLeaderboardSortedByValue() {
        let results = [
            ChallengeResult(id: "1", challengeId: "ch1", userId: "u1", rank: 1, value: 3000, unit: "lbs", lastUpdated: Date()),
            ChallengeResult(id: "2", challengeId: "ch1", userId: "u2", rank: 2, value: 5000, unit: "lbs", lastUpdated: Date()),
            ChallengeResult(id: "3", challengeId: "ch1", userId: "u3", rank: 3, value: 4000, unit: "lbs", lastUpdated: Date())
        ]
        
        let sorted = results.sorted { $0.value > $1.value }
        
        XCTAssertEqual(sorted[0].value, 5000)
        XCTAssertEqual(sorted[1].value, 4000)
        XCTAssertEqual(sorted[2].value, 3000)
    }
    
    func testTopPerformerIdentification() {
        let leaderboard = [
            LeaderboardEntry(id: "1", userId: "u1", userName: "User 1", userAvatar: nil, rank: 1, value: 5000, unit: "lbs", streak: 5, badges: []),
            LeaderboardEntry(id: "2", userId: "u2", userName: "User 2", userAvatar: nil, rank: 2, value: 4000, unit: "lbs", streak: 3, badges: []),
            LeaderboardEntry(id: "3", userId: "u3", userName: "User 3", userAvatar: nil, rank: 3, value: 3000, unit: "lbs", streak: 0, badges: [])
        ]
        
        let topPerformer = leaderboard.first(where: { $0.rank == 1 })
        
        XCTAssertNotNil(topPerformer)
        XCTAssertEqual(topPerformer?.userId, "u1")
        XCTAssertEqual(topPerformer?.value, 5000)
    }
}

// MARK: - Badge System Integration Tests
final class BadgeSystemIntegrationTests: XCTestCase {
    
    var badgeSystem: BadgeSystem!
    
    override func setUp() {
        super.setUp()
        badgeSystem = BadgeSystem()
    }
    
    func testCheckAndAwardBadgesForResults() {
        let leaderboard = [
            LeaderboardEntry(id: "1", userId: "u1", userName: "User 1", userAvatar: nil, rank: 1, value: 5000, unit: "lbs", streak: 7, badges: []),
            LeaderboardEntry(id: "2", userId: "u2", userName: "User 2", userAvatar: nil, rank: 2, value: 4000, unit: "lbs", streak: 3, badges: []),
            LeaderboardEntry(id: "3", userId: "u3", userName: "User 3", userAvatar: nil, rank: 3, value: 3000, unit: "lbs", streak: 0, badges: [])
        ]
        
        let awardedBadges = badgeSystem.checkAndAwardBadges(
            for: leaderboard,
            challengeType: .mostVolume
        )
        
        XCTAssertGreater(awardedBadges.count, 0)
        XCTAssertNotNil(awardedBadges["u1"])
    }
}
