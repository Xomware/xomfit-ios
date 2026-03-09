import Foundation

class LeaderboardService {
    static let shared = LeaderboardService()
    private let workoutStore = WorkoutStore.shared
    
    // MARK: - Mock leaderboard data with current user embedded
    func leaderboard(scope: LeaderboardScope, metric: LeaderboardMetric, timeframe: LeaderboardTimeframe) -> [LeaderboardEntry] {
        let currentUserScore = calculateCurrentUserScore(metric: metric, timeframe: timeframe)
        let currentUserName = "You"
        
        // Generate realistic mock data around the user's score
        let mockNames = ["Alex R.", "Jordan M.", "Sam T.", "Chris K.", "Taylor W.",
                         "Morgan B.", "Casey L.", "Drew P.", "Quinn A.", "Riley F."]
        
        var scores: [(String, Int)] = [(currentUserName, currentUserScore)]
        
        // Generate competitors
        for (i, name) in mockNames.prefix(9).enumerated() {
            let variance = Int.random(in: -50...150)
            let baseScore = max(1, currentUserScore + variance - (i * 10))
            scores.append((name, baseScore))
        }
        
        // Sort descending
        scores.sort { $0.1 > $1.1 }
        
        return scores.enumerated().map { (index, item) in
            let prevRank = Int.random(in: max(1, index)...(index + 3))
            return LeaderboardEntry(
                userId: item.0 == currentUserName ? "current_user" : "user_\(index)",
                displayName: item.0,
                rank: index + 1,
                previousRank: prevRank,
                score: item.1,
                metric: metric
            )
        }
    }
    
    // MARK: - Calculate current user score
    func calculateCurrentUserScore(metric: LeaderboardMetric, timeframe: LeaderboardTimeframe) -> Int {
        let workouts = workoutStore.workouts
        let cutoff: Date
        let now = Date()
        
        switch timeframe {
        case .weekly:
            cutoff = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        case .monthly:
            cutoff = Calendar.current.date(byAdding: .month, value: -1, to: now)!
        case .allTime:
            cutoff = Date.distantPast
        }
        
        let filtered = workouts.filter { $0.startTime >= cutoff }
        
        switch metric {
        case .weeklyVolume:
            return filtered.flatMap { $0.sets }.reduce(0) { acc, set in
                acc + Int(set.weight * Double(set.reps))
            }
        case .personalRecords:
            return Int.random(in: 2...8) // Mock for now
        case .workoutStreak:
            return calculateStreak(workouts: workouts.sorted { $0.startTime > $1.startTime })
        case .totalWorkouts:
            return filtered.count
        }
    }
    
    func calculateStreak(workouts: [Workout]) -> Int {
        var streak = 0
        var currentDate = Calendar.current.startOfDay(for: Date())
        
        for workout in workouts {
            let workoutDay = Calendar.current.startOfDay(for: workout.startTime)
            if workoutDay == currentDate {
                streak += 1
                currentDate = Calendar.current.date(byAdding: .day, value: -1, to: currentDate)!
            } else if workoutDay < currentDate {
                break
            }
        }
        return streak
    }
    
    // MARK: - Trophies
    func trophies(for userId: String = "current_user") -> [Trophy] {
        // Demo trophies earned from past leaderboard positions
        [
            Trophy(title: "Friends Champion", description: "🥇 #1 in Weekly Volume (Feb 2026)", emoji: "🥇", scope: .friends, rank: 1),
            Trophy(title: "Gym Leader", description: "🥈 #2 in Total Workouts (Jan 2026)", emoji: "🥈", scope: .gym, rank: 2),
            Trophy(title: "Top Performer", description: "🥉 #3 in Streak (Dec 2025)", emoji: "🥉", scope: .global, rank: 3)
        ]
    }
}
