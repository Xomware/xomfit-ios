import XCTest
@testable import XomFit

final class LeaderboardTests: XCTestCase {
    var service: LeaderboardService!
    
    override func setUp() {
        super.setUp()
        service = LeaderboardService.shared
    }
    
    func testLeaderboardReturnsEntries() {
        let entries = service.leaderboard(scope: .friends, metric: .weeklyVolume, timeframe: .weekly)
        XCTAssertGreaterThan(entries.count, 0)
    }
    
    func testLeaderboardRanksAreOrdered() {
        let entries = service.leaderboard(scope: .friends, metric: .weeklyVolume, timeframe: .weekly)
        for (i, entry) in entries.enumerated() {
            XCTAssertEqual(entry.rank, i + 1)
        }
    }
    
    func testTopThreeHaveBadges() {
        let entries = service.leaderboard(scope: .friends, metric: .weeklyVolume, timeframe: .weekly)
        XCTAssertEqual(entries[0].badge, "🥇")
        XCTAssertEqual(entries[1].badge, "🥈")
        XCTAssertEqual(entries[2].badge, "🥉")
    }
    
    func testCurrentUserIsInLeaderboard() {
        let entries = service.leaderboard(scope: .friends, metric: .weeklyVolume, timeframe: .weekly)
        let user = entries.first(where: { $0.userId == "current_user" })
        XCTAssertNotNil(user)
    }
    
    func testLeaderboardScoreFormatted() {
        let entry = LeaderboardEntry(userId: "test", displayName: "Test", rank: 1, score: 5000, metric: .weeklyVolume)
        XCTAssertTrue(entry.scoreFormatted.contains("lbs"))
    }
    
    func testStreakLeaderboardScoreFormatted() {
        let entry = LeaderboardEntry(userId: "test", displayName: "Test", rank: 1, score: 7, metric: .workoutStreak)
        XCTAssertTrue(entry.scoreFormatted.contains("days"))
    }
    
    func testRankChangeSymbolUp() {
        let entry = LeaderboardEntry(userId: "test", displayName: "Test", rank: 2, previousRank: 4, score: 100, metric: .totalWorkouts)
        XCTAssertTrue(entry.rankChangeSymbol.hasPrefix("↑"))
    }
    
    func testRankChangeSymbolDown() {
        let entry = LeaderboardEntry(userId: "test", displayName: "Test", rank: 5, previousRank: 3, score: 100, metric: .totalWorkouts)
        XCTAssertTrue(entry.rankChangeSymbol.hasPrefix("↓"))
    }
    
    func testTrophiesReturnsData() {
        let trophies = service.trophies()
        XCTAssertGreaterThan(trophies.count, 0)
    }
    
    func testAllMetricTimeframeCombinations() {
        for scope in LeaderboardScope.allCases {
            for metric in LeaderboardMetric.allCases {
                for timeframe in LeaderboardTimeframe.allCases {
                    let entries = service.leaderboard(scope: scope, metric: metric, timeframe: timeframe)
                    XCTAssertGreaterThan(entries.count, 0, "Should have entries for \(scope)/\(metric)/\(timeframe)")
                }
            }
        }
    }
}
