import XCTest
@testable import XomFit

final class ChallengeTests: XCTestCase {

    var badgeSystem: BadgeSystem!

    override func setUp() {
        super.setUp()
        badgeSystem = BadgeSystem()
    }

    override func tearDown() {
        badgeSystem = nil
        super.tearDown()
    }

    // MARK: - ChallengeType Tests

    func testAllChallengeTypesHaveDuration() {
        for type in ChallengeType.allCases {
            XCTAssertGreater(type.durationDays, 0, "\(type) should have positive duration")
        }
    }

    func testChallengeTypeDuration() {
        XCTAssertEqual(ChallengeType.mostVolume.durationDays, 7)
        XCTAssertEqual(ChallengeType.heaviestBench.durationDays, 7)
        XCTAssertEqual(ChallengeType.weeklyStreak.durationDays, 7)
        XCTAssertEqual(ChallengeType.mostWorkouts.durationDays, 30)
        XCTAssertEqual(ChallengeType.fastestMile.durationDays, 30)
        XCTAssertEqual(ChallengeType.strengthGain.durationDays, 30)
        XCTAssertEqual(ChallengeType.longestStreak.durationDays, 30)
    }

    func testChallengeTypeDisplayName() {
        XCTAssertEqual(ChallengeType.mostVolume.displayName, "Most Volume")
        XCTAssertEqual(ChallengeType.heaviestBench.displayName, "Heaviest Bench")
        XCTAssertEqual(ChallengeType.mostWorkouts.displayName, "Most Workouts")
        XCTAssertEqual(ChallengeType.fastestMile.displayName, "Fastest Mile")
        XCTAssertEqual(ChallengeType.strengthGain.displayName, "Strength Gain")
        XCTAssertEqual(ChallengeType.longestStreak.displayName, "Longest Streak")
        XCTAssertEqual(ChallengeType.weeklyStreak.displayName, "Weekly Streak")
    }

    func testChallengeTypeDescription() {
        for type in ChallengeType.allCases {
            XCTAssertFalse(type.description.isEmpty, "\(type) should have a description")
        }
    }

    func testChallengeTypeIcon() {
        for type in ChallengeType.allCases {
            XCTAssertFalse(type.icon.isEmpty, "\(type) should have an icon")
        }
    }

    func testChallengeTypeUnit() {
        XCTAssertEqual(ChallengeType.mostVolume.unit, "lbs")
        XCTAssertEqual(ChallengeType.mostWorkouts.unit, "workouts")
        XCTAssertEqual(ChallengeType.fastestMile.unit, "min")
        XCTAssertEqual(ChallengeType.longestStreak.unit, "days")
        XCTAssertEqual(ChallengeType.weeklyStreak.unit, "days")
    }

    func testChallengeTypeCodable() throws {
        let type = ChallengeType.longestStreak
        let data = try JSONEncoder().encode(type)
        let decoded = try JSONDecoder().decode(ChallengeType.self, from: data)
        XCTAssertEqual(decoded, type)
    }

    // MARK: - Challenge Status Tests

    func testChallengeStatusCodable() throws {
        for status in ChallengeStatus.allCases {
            let data = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(ChallengeStatus.self, from: data)
            XCTAssertEqual(decoded, status)
        }
    }

    // MARK: - Challenge Model Tests

    func testChallengeIsActive() {
        let challenge = makeChallenge(
            status: .active,
            startDate: Date().addingTimeInterval(-3_600),
            endDate: Date().addingTimeInterval(86_400 * 7)
        )
        XCTAssertTrue(challenge.isActive)
    }

    func testChallengeNotActiveWhenCompleted() {
        let challenge = makeChallenge(
            status: .completed,
            startDate: Date().addingTimeInterval(-86_400 * 10),
            endDate: Date().addingTimeInterval(-86_400)
        )
        XCTAssertFalse(challenge.isActive)
    }

    func testChallengeNotActiveWhenUpcoming() {
        let challenge = makeChallenge(
            status: .upcoming,
            startDate: Date().addingTimeInterval(86_400),
            endDate: Date().addingTimeInterval(86_400 * 8)
        )
        XCTAssertFalse(challenge.isActive)
    }

    func testChallengeNotActiveWhenCancelled() {
        let challenge = makeChallenge(
            status: .cancelled,
            startDate: Date().addingTimeInterval(-3_600),
            endDate: Date().addingTimeInterval(86_400 * 7)
        )
        XCTAssertFalse(challenge.isActive)
    }

    func testChallengeDaysRemaining() {
        let challenge = makeChallenge(
            status: .active,
            startDate: Date(),
            endDate: Date().addingTimeInterval(86_400 * 7)
        )
        XCTAssertGreaterThanOrEqual(challenge.daysRemaining, 6)
        XCTAssertLessThanOrEqual(challenge.daysRemaining, 7)
    }

    func testChallengeDaysRemainingWhenPast() {
        let challenge = makeChallenge(
            status: .completed,
            startDate: Date().addingTimeInterval(-86_400 * 10),
            endDate: Date().addingTimeInterval(-86_400)
        )
        XCTAssertEqual(challenge.daysRemaining, 0)
    }

    func testChallengeProgressPercentage() {
        let challenge = makeChallenge(
            status: .active,
            startDate: Date(),
            endDate: Date().addingTimeInterval(86_400 * 7)
        )
        XCTAssertGreaterThanOrEqual(challenge.progressPercentage, 0)
        XCTAssertLessThanOrEqual(challenge.progressPercentage, 1.0)
    }

    func testChallengeProgressClamped() {
        // Past end date
        let challenge = makeChallenge(
            status: .completed,
            startDate: Date().addingTimeInterval(-86_400 * 14),
            endDate: Date().addingTimeInterval(-86_400 * 7)
        )
        XCTAssertEqual(challenge.progressPercentage, 1.0)
    }

    // MARK: - ChallengeResult Tests

    func testChallengeResultFormattedValueLbs() {
        let result = ChallengeResult(
            id: "r1", challengeId: "c1", userId: "u1",
            rank: 1, value: 5000, unit: "lbs", lastUpdated: Date()
        )
        XCTAssertEqual(result.formattedValue, "5000 lbs")
    }

    func testChallengeResultFormattedValueWorkouts() {
        let result = ChallengeResult(
            id: "r1", challengeId: "c1", userId: "u1",
            rank: 1, value: 25, unit: "workouts", lastUpdated: Date()
        )
        XCTAssertEqual(result.formattedValue, "25 workouts")
    }

    func testChallengeResultFormattedValueOther() {
        let result = ChallengeResult(
            id: "r1", challengeId: "c1", userId: "u1",
            rank: 1, value: 6.35, unit: "min", lastUpdated: Date()
        )
        XCTAssertEqual(result.formattedValue, "6.35 min")
    }

    // MARK: - Streak Tests

    func testStreakActiveToday() {
        let streak = Streak(
            id: "s1", userId: "u1", challengeId: "c1",
            count: 7, lastWorkoutDate: Date()
        )
        XCTAssertTrue(streak.isActive)
    }

    func testStreakInactiveAfterMultipleDays() {
        let streak = Streak(
            id: "s1", userId: "u1", challengeId: "c1",
            count: 7, lastWorkoutDate: Date().addingTimeInterval(-86_400 * 3)
        )
        XCTAssertFalse(streak.isActive)
    }

    func testStreakStatusActive() {
        let streak = Streak(
            id: "s1", userId: "u1", challengeId: "c1",
            count: 5, lastWorkoutDate: Date()
        )
        XCTAssertEqual(streak.streakStatus, .active)
    }

    func testStreakStatusAtRisk() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date()))!
        let streak = Streak(
            id: "s1", userId: "u1", challengeId: "c1",
            count: 5, lastWorkoutDate: yesterday
        )
        XCTAssertEqual(streak.streakStatus, .atRisk)
    }

    func testStreakStatusBroken() {
        let streak = Streak(
            id: "s1", userId: "u1", challengeId: "c1",
            count: 5, lastWorkoutDate: Date().addingTimeInterval(-86_400 * 3)
        )
        XCTAssertEqual(streak.streakStatus, .broken)
    }

    func testStreakMutableCount() {
        var streak = Streak(
            id: "s1", userId: "u1", challengeId: "c1",
            count: 5, lastWorkoutDate: Date()
        )
        streak.count += 1
        XCTAssertEqual(streak.count, 6)
    }

    // MARK: - ChallengeParticipant Tests

    func testChallengeParticipantCreation() {
        let participant = ChallengeParticipant(
            id: "p1", challengeId: "c1", userId: "u1",
            joinStatus: .accepted, joinedAt: Date()
        )
        XCTAssertEqual(participant.joinStatus, .accepted)
        XCTAssertEqual(participant.challengeId, "c1")
    }

    func testChallengeParticipantEquatable() {
        let date = Date()
        let participant1 = ChallengeParticipant(
            id: "p1", challengeId: "c1", userId: "u1",
            joinStatus: .accepted, joinedAt: date
        )
        let participant2 = ChallengeParticipant(
            id: "p1", challengeId: "c1", userId: "u1",
            joinStatus: .accepted, joinedAt: date
        )
        XCTAssertEqual(participant1, participant2)
    }

    func testChallengeJoinStatusCodable() throws {
        for status in [ChallengeJoinStatus.pending, .accepted, .declined] {
            let data = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(ChallengeJoinStatus.self, from: data)
            XCTAssertEqual(decoded, status)
        }
    }

    // MARK: - ChallengeDetail Tests

    func testChallengeDetailTopPerformer() {
        let leaderboard = [
            makeLeaderboardEntry(rank: 1, userId: "u1", value: 5000),
            makeLeaderboardEntry(rank: 2, userId: "u2", value: 4000)
        ]
        let detail = ChallengeDetail(
            id: "d1",
            challenge: makeChallenge(status: .active),
            leaderboard: leaderboard,
            currentUserRank: 2,
            currentUserValue: 4000,
            streaks: []
        )
        XCTAssertEqual(detail.topPerformer?.userId, "u1")
    }

    func testChallengeDetailTopPerformerEmpty() {
        let detail = ChallengeDetail(
            id: "d1",
            challenge: makeChallenge(status: .active),
            leaderboard: [],
            currentUserRank: nil,
            currentUserValue: nil,
            streaks: []
        )
        XCTAssertNil(detail.topPerformer)
    }

    // MARK: - LeaderboardEntry Tests

    func testLeaderboardEntryFormattedValueLbs() {
        let entry = makeLeaderboardEntry(rank: 1, userId: "u1", value: 5000.5)
        XCTAssertEqual(entry.formattedValue, "5001 lbs")
    }

    func testLeaderboardEntryFormattedValueWorkouts() {
        let entry = LeaderboardEntry(
            id: "e1", userId: "u1", userName: "User",
            userAvatar: nil, rank: 1, value: 25,
            unit: "workouts", streak: 0, badges: []
        )
        XCTAssertEqual(entry.formattedValue, "25 workouts")
    }

    func testLeaderboardEntryEquatable() {
        let entry1 = makeLeaderboardEntry(rank: 1, userId: "u1", value: 5000)
        let entry2 = makeLeaderboardEntry(rank: 1, userId: "u1", value: 5000)
        XCTAssertEqual(entry1, entry2)
    }

    func testLeaderboardSortedByValue() {
        let results = [
            ChallengeResult(id: "1", challengeId: "c1", userId: "u1", rank: 0, value: 3000, unit: "lbs", lastUpdated: Date()),
            ChallengeResult(id: "2", challengeId: "c1", userId: "u2", rank: 0, value: 5000, unit: "lbs", lastUpdated: Date()),
            ChallengeResult(id: "3", challengeId: "c1", userId: "u3", rank: 0, value: 4000, unit: "lbs", lastUpdated: Date())
        ]
        let sorted = results.sorted { $0.value > $1.value }
        XCTAssertEqual(sorted[0].value, 5000)
        XCTAssertEqual(sorted[1].value, 4000)
        XCTAssertEqual(sorted[2].value, 3000)
    }

    // MARK: - Badge Tests

    func testBadgeSystemImage() {
        let badges: [(String, String)] = [
            ("First Place", "crown.fill"),
            ("Podium", "medal.fill"),
            ("Streak Master", "flame.fill"),
            ("Most Improved", "arrow.up.right"),
            ("Consistency", "checkmark.circle.fill"),
            ("PR Breaker", "bolt.fill"),
            ("Unknown", "star.fill")
        ]
        for (name, expected) in badges {
            let badge = Badge(id: "b1", name: name, description: "", icon: "", earnedDate: Date())
            XCTAssertEqual(badge.systemImage, expected, "Badge '\(name)' should use '\(expected)'")
        }
    }

    func testBadgeEquatable() {
        let date = Date()
        let badge1 = Badge(id: "b1", name: "First Place", description: "Won", icon: "crown.fill", earnedDate: date)
        let badge2 = Badge(id: "b1", name: "First Place", description: "Won", icon: "crown.fill", earnedDate: date)
        XCTAssertEqual(badge1, badge2)
    }

    // MARK: - BadgeSystem Tests

    func testBadgeAward() {
        let badge = badgeSystem.awardBadge(.firstPlace, to: "u1")
        XCTAssertNotNil(badge)
        XCTAssertEqual(badge?.name, "First Place")
        XCTAssertTrue(badgeSystem.hasBadge(.firstPlace, for: "u1"))
    }

    func testBadgeDuplicateNotAwarded() {
        let badge1 = badgeSystem.awardBadge(.firstPlace, to: "u1")
        let badge2 = badgeSystem.awardBadge(.firstPlace, to: "u1")
        XCTAssertNotNil(badge1)
        XCTAssertNil(badge2)
    }

    func testGetUserBadges() {
        _ = badgeSystem.awardBadge(.firstPlace, to: "u1")
        _ = badgeSystem.awardBadge(.streakMaster, to: "u1")
        let badges = badgeSystem.getBadges(for: "u1")
        XCTAssertEqual(badges.count, 2)
    }

    func testGetBadgesEmptyUser() {
        let badges = badgeSystem.getBadges(for: "nonexistent")
        XCTAssertTrue(badges.isEmpty)
    }

    func testHasBadgeReturnsFalse() {
        XCTAssertFalse(badgeSystem.hasBadge(.firstPlace, for: "u1"))
    }

    func testStreakBadgesAt7() {
        let badges = badgeSystem.checkStreakBadges(userId: "u1", streakCount: 7)
        XCTAssertGreater(badges.count, 0)
    }

    func testStreakBadgesAt14() {
        let badges = badgeSystem.checkStreakBadges(userId: "u1", streakCount: 14)
        XCTAssertGreater(badges.count, 0)
    }

    func testStreakBadgesAt0() {
        let badges = badgeSystem.checkStreakBadges(userId: "u1", streakCount: 0)
        XCTAssertEqual(badges.count, 0)
    }

    func testPRBadge() {
        let badges = badgeSystem.checkPRBadges(userId: "u1", prCount: 5)
        XCTAssertNotNil(badges)
        XCTAssertGreater(badges?.count ?? 0, 0)
    }

    func testAllStarBadge() {
        let badge = badgeSystem.checkAllStarBadge(userId: "u1", completedChallenges: 5)
        XCTAssertNotNil(badge)
        XCTAssertEqual(badge?.name, "All-Star")
    }

    func testCheckAndAwardBadgesForLeaderboard() {
        let leaderboard = [
            makeLeaderboardEntry(rank: 1, userId: "u1", value: 5000, streak: 7),
            makeLeaderboardEntry(rank: 2, userId: "u2", value: 4000, streak: 3),
            makeLeaderboardEntry(rank: 3, userId: "u3", value: 3000, streak: 0)
        ]
        let awarded = badgeSystem.checkAndAwardBadges(for: leaderboard, challengeType: .mostVolume)
        XCTAssertGreater(awarded.count, 0)
        XCTAssertNotNil(awarded["u1"])
    }

    // MARK: - Challenge Creation Tests

    func testChallengeCreation() {
        let challenge = makeChallenge(status: .upcoming, participants: ["u1", "u2", "u3"])
        XCTAssertEqual(challenge.participants.count, 3)
        XCTAssertEqual(challenge.status, .upcoming)
    }

    func testChallengeInitializesResults() {
        let participants = ["u1", "u2", "u3"]
        let results = participants.map { userId in
            ChallengeResult(
                id: UUID().uuidString, challengeId: "c1", userId: userId,
                rank: participants.count, value: 0, unit: "lbs", lastUpdated: Date()
            )
        }
        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results.allSatisfy { $0.value == 0 })
    }

    // MARK: - StreakStatus Enum Tests

    func testStreakStatusValues() {
        // Verify all three cases exist
        let active: StreakStatus = .active
        let atRisk: StreakStatus = .atRisk
        let broken: StreakStatus = .broken
        XCTAssertNotEqual("\(active)", "\(atRisk)")
        XCTAssertNotEqual("\(atRisk)", "\(broken)")
    }

    // MARK: - Helpers

    private func makeChallenge(
        status: ChallengeStatus,
        startDate: Date = Date(),
        endDate: Date = Date().addingTimeInterval(86_400 * 7),
        participants: [String] = ["u1", "u2"]
    ) -> Challenge {
        Challenge(
            id: UUID().uuidString,
            type: .mostVolume,
            status: status,
            createdBy: "creator",
            participants: participants,
            startDate: startDate,
            endDate: endDate,
            results: [],
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    private func makeLeaderboardEntry(
        rank: Int,
        userId: String,
        value: Double,
        streak: Int = 0
    ) -> LeaderboardEntry {
        LeaderboardEntry(
            id: "e-\(userId)",
            userId: userId,
            userName: "User \(userId)",
            userAvatar: nil,
            rank: rank,
            value: value,
            unit: "lbs",
            streak: streak,
            badges: []
        )
    }
}

// MARK: - Leaderboard Calculation Tests
final class LeaderboardCalculationTests: XCTestCase {

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

// MARK: - BadgeSystem Integration Tests
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
        let awardedBadges = badgeSystem.checkAndAwardBadges(for: leaderboard, challengeType: .mostVolume)
        XCTAssertGreater(awardedBadges.count, 0)
        XCTAssertNotNil(awardedBadges["u1"])
    }

    func testMultipleChallengeTypeBadges() {
        for type in ChallengeType.allCases {
            let leaderboard = [
                LeaderboardEntry(id: "1", userId: "u1", userName: "User 1", userAvatar: nil, rank: 1, value: 100, unit: type.unit, streak: 7, badges: [])
            ]
            let badges = badgeSystem.checkAndAwardBadges(for: leaderboard, challengeType: type)
            // First place badge should be awarded for the first type tested
            XCTAssertNotNil(badges)
        }
    }
}
