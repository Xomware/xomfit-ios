import Foundation
import SwiftUI

/// Challenge types supported by the app
enum ChallengeType: String, Codable, CaseIterable {
    case mostVolume = "most_volume"           // Most total weight lifted in a week
    case heaviestBench = "heaviest_bench"     // Heaviest bench press lift
    case mostWorkouts = "most_workouts"       // Most workouts completed in a month
    case fastestMile = "fastest_mile"         // Fastest mile or 5K time
    case strengthGain = "strength_gain"       // Greatest strength improvement
    case longestStreak = "longest_streak"     // Longest consecutive workout streak
    case weeklyStreak = "weekly_streak"       // Maintain a 7-day workout streak

    var displayName: String {
        switch self {
        case .mostVolume:
            return "Most Volume"
        case .heaviestBench:
            return "Heaviest Bench"
        case .mostWorkouts:
            return "Most Workouts"
        case .fastestMile:
            return "Fastest Mile"
        case .strengthGain:
            return "Strength Gain"
        case .longestStreak:
            return "Longest Streak"
        case .weeklyStreak:
            return "Weekly Streak"
        }
    }

    var description: String {
        switch self {
        case .mostVolume:
            return "Lift the most total weight in a week"
        case .heaviestBench:
            return "Achieve the heaviest bench press"
        case .mostWorkouts:
            return "Complete the most workouts in a month"
        case .fastestMile:
            return "Record the fastest mile time"
        case .strengthGain:
            return "Gain the most strength on a lift"
        case .longestStreak:
            return "Build the longest consecutive workout streak"
        case .weeklyStreak:
            return "Maintain a 7-day workout streak"
        }
    }

    var icon: String {
        switch self {
        case .mostVolume: return "scalemass.fill"
        case .heaviestBench: return "dumbbell.fill"
        case .mostWorkouts: return "figure.run"
        case .fastestMile: return "stopwatch.fill"
        case .strengthGain: return "arrow.up.right"
        case .longestStreak: return "flame.fill"
        case .weeklyStreak: return "calendar.badge.checkmark"
        }
    }

    var unit: String {
        switch self {
        case .mostVolume, .heaviestBench, .strengthGain:
            return "lbs"
        case .mostWorkouts:
            return "workouts"
        case .fastestMile:
            return "min"
        case .longestStreak, .weeklyStreak:
            return "days"
        }
    }

    var durationDays: Int {
        switch self {
        case .mostVolume, .heaviestBench, .weeklyStreak:
            return 7  // 1 week
        case .mostWorkouts, .fastestMile, .strengthGain, .longestStreak:
            return 30 // 1 month
        }
    }
}

/// Join status for a challenge invitation
enum ChallengeJoinStatus: String, Codable {
    case pending
    case accepted
    case declined
}

/// Represents a participant's membership in a challenge
struct ChallengeParticipant: Identifiable, Codable, Equatable {
    let id: String
    let challengeId: String
    let userId: String
    let joinStatus: ChallengeJoinStatus
    let joinedAt: Date
}

/// Status of a challenge
enum ChallengeStatus: String, Codable, CaseIterable {
    case upcoming = "upcoming"
    case active = "active"
    case completed = "completed"
    case cancelled = "cancelled"
}

/// Represents a single workout challenge
struct Challenge: Identifiable, Codable {
    let id: String
    let type: ChallengeType
    let status: ChallengeStatus
    let createdBy: String
    let participants: [String]
    let startDate: Date
    let endDate: Date
    let results: [ChallengeResult]
    let createdAt: Date
    let updatedAt: Date
    
    var isActive: Bool {
        let now = Date()
        return now >= startDate && now < endDate && status == .active
    }
    
    var daysRemaining: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: endDate)
        return max(0, components.day ?? 0)
    }
    
    var progressPercentage: Double {
        let total = endDate.timeIntervalSince(startDate)
        let elapsed = Date().timeIntervalSince(startDate)
        let progress = elapsed / total
        return min(1.0, max(0.0, progress))
    }
}

/// Individual result for a participant in a challenge
struct ChallengeResult: Identifiable, Codable {
    let id: String
    let challengeId: String
    let userId: String
    let rank: Int
    let value: Double
    let unit: String
    let lastUpdated: Date
    
    var formattedValue: String {
        // Format based on unit type
        if unit == "lbs" {
            return String(format: "%.0f %@", value, unit)
        } else if unit == "workouts" {
            return String(format: "%.0f %@", value, unit)
        } else {
            return String(format: "%.2f %@", value, unit)
        }
    }
}

/// Streak tracking for challenges
struct Streak: Identifiable, Codable {
    let id: String
    let userId: String
    let challengeId: String
    var count: Int
    let lastWorkoutDate: Date
    
    var isActive: Bool {
        let daysSinceLastWorkout = Calendar.current.dateComponents([.day], from: lastWorkoutDate, to: Date()).day ?? 0
        return daysSinceLastWorkout <= 1
    }
}

/// Extended challenge info with leaderboard data
struct ChallengeDetail: Identifiable, Codable {
    let id: String
    let challenge: Challenge
    let leaderboard: [ChallengeLeaderboardEntry]
    let currentUserRank: Int?
    let currentUserValue: Double?
    let streaks: [Streak]
    
    var topPerformer: ChallengeLeaderboardEntry? {
        leaderboard.first(where: { $0.rank == 1 })
    }
}

/// Single leaderboard entry for display
struct ChallengeLeaderboardEntry: Identifiable, Codable, Equatable {
    let id: String
    let userId: String
    let userName: String
    let userAvatar: String?
    let rank: Int
    let value: Double
    let unit: String
    let streak: Int
    let badges: [Badge]
    
    var formattedValue: String {
        if unit == "lbs" {
            return String(format: "%.0f %@", value, unit)
        } else if unit == "workouts" {
            return String(format: "%.0f %@", value, unit)
        } else {
            return String(format: "%.2f %@", value, unit)
        }
    }
}

/// Badge achievement
struct Badge: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let earnedDate: Date
    
    var systemImage: String {
        switch name {
        case "First Place":
            return "crown.fill"
        case "Podium":
            return "medal.fill"
        case "Streak Master":
            return "flame.fill"
        case "Most Improved":
            return "arrow.up.right"
        case "Consistency":
            return "checkmark.circle.fill"
        case "PR Breaker":
            return "bolt.fill"
        default:
            return "star.fill"
        }
    }
}
