import Foundation

struct FriendSuggestion: Codable, Identifiable {
    let id: String
    let user: User
    let reason: SuggestionReason
    let matchPercentage: Int // 0-100
    
    enum SuggestionReason: String, Codable {
        case sameGym
        case mutualFriends
        case similarInterests
        case recentlyActive
    }
}

// MARK: - Mock Data
extension FriendSuggestion {
    static let mockSameGym = FriendSuggestion(
        id: "fs-1",
        user: User(
            id: "user-5",
            username: "alexm",
            displayName: "Alex M",
            avatarURL: nil,
            bio: "Training for strength 🏋️",
            stats: User.UserStats(
                totalWorkouts: 156,
                totalVolume: 876_320,
                totalPRs: 28,
                currentStreak: 4,
                longestStreak: 18,
                favoriteExercise: "Squat"
            ),
            isPrivate: false,
            createdAt: Date().addingTimeInterval(-86400 * 150)
        ),
        reason: .sameGym,
        matchPercentage: 85
    )
    
    static let mockMutualFriends = FriendSuggestion(
        id: "fs-2",
        user: User(
            id: "user-6",
            username: "jessi",
            displayName: "Jessi L",
            avatarURL: nil,
            bio: "Running & lifting 🏃",
            stats: User.UserStats(
                totalWorkouts: 203,
                totalVolume: 654_890,
                totalPRs: 35,
                currentStreak: 6,
                longestStreak: 25,
                favoriteExercise: "Leg Press"
            ),
            isPrivate: false,
            createdAt: Date().addingTimeInterval(-86400 * 180)
        ),
        reason: .mutualFriends,
        matchPercentage: 72
    )
}
