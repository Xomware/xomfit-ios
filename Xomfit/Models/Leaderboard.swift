import Foundation

enum LeaderboardMetric: String, Codable, CaseIterable {
    case weeklyVolume = "Weekly Volume"
    case personalRecords = "Personal Records"
    case workoutStreak = "Workout Streak"
    case totalWorkouts = "Total Workouts"
}

enum LeaderboardTimeframe: String, Codable, CaseIterable {
    case weekly = "This Week"
    case monthly = "This Month"
    case allTime = "All Time"
}

enum LeaderboardScope: String, Codable, CaseIterable {
    case friends = "Friends"
    case global = "Global"
    case gym = "My Gym"
}

struct LeaderboardEntry: Identifiable, Codable {
    var id: UUID
    var userId: String
    var displayName: String
    var avatarInitials: String
    var rank: Int
    var previousRank: Int
    var score: Int
    var metric: LeaderboardMetric
    var badge: String? // emoji badge for top 3
    
    init(id: UUID = UUID(), userId: String, displayName: String, rank: Int,
         previousRank: Int = 0, score: Int, metric: LeaderboardMetric) {
        self.id = id
        self.userId = userId
        self.displayName = displayName
        self.avatarInitials = String(displayName.prefix(2)).uppercased()
        self.rank = rank
        self.previousRank = previousRank
        self.score = score
        self.metric = metric
        self.badge = rank == 1 ? "🥇" : rank == 2 ? "🥈" : rank == 3 ? "🥉" : nil
    }
    
    var rankChange: Int { previousRank - rank } // Positive = moved up
    var rankChangeSymbol: String {
        if rankChange > 0 { return "↑\(rankChange)" }
        if rankChange < 0 { return "↓\(abs(rankChange))" }
        return "—"
    }
    var rankChangeColor: String {
        if rankChange > 0 { return "green" }
        if rankChange < 0 { return "red" }
        return "gray"
    }
    
    var scoreFormatted: String {
        switch metric {
        case .weeklyVolume: return "\(score) lbs"
        case .personalRecords: return "\(score) PRs"
        case .workoutStreak: return "\(score) days"
        case .totalWorkouts: return "\(score) workouts"
        }
    }
}

struct Trophy: Identifiable, Codable {
    var id: UUID
    var title: String
    var description: String
    var emoji: String
    var earnedAt: Date
    var leaderboardScope: LeaderboardScope
    var rank: Int
    
    init(id: UUID = UUID(), title: String, description: String, emoji: String,
         scope: LeaderboardScope, rank: Int) {
        self.id = id
        self.title = title
        self.description = description
        self.emoji = emoji
        self.earnedAt = Date()
        self.leaderboardScope = scope
        self.rank = rank
    }
}
