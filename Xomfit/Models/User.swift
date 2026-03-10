import Foundation

struct AppUser: Codable, Identifiable, Hashable {
    static func == (lhs: AppUser, rhs: AppUser) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    let id: String
    var username: String
    var displayName: String
    var avatarURL: String?
    var bio: String
    var stats: UserStats
    var isPrivate: Bool
    var createdAt: Date
    
    struct UserStats: Codable {
        var totalWorkouts: Int
        var totalVolume: Double // in lbs
        var totalPRs: Int
        var currentStreak: Int // days
        var longestStreak: Int
        var favoriteExercise: String?
    }
}

// MARK: - Mock Data
extension AppUser {
    static let mock = AppUser(
        id: "user-1",
        username: "domg",
        displayName: "Dom G",
        avatarURL: nil,
        bio: "Building XomFit 💪",
        stats: UserStats(
            totalWorkouts: 247,
            totalVolume: 1_245_680,
            totalPRs: 42,
            currentStreak: 5,
            longestStreak: 30,
            favoriteExercise: "Bench Press"
        ),
        isPrivate: false,
        createdAt: Date().addingTimeInterval(-86400 * 365)
    )
    
    static let mockUser = AppUser(
        id: "user-1",
        username: "domg",
        displayName: "Dom G",
        avatarURL: nil,
        bio: "Building XomFit 💪",
        stats: UserStats(
            totalWorkouts: 247,
            totalVolume: 1_245_680,
            totalPRs: 42,
            currentStreak: 5,
            longestStreak: 30,
            favoriteExercise: "Bench Press"
        ),
        isPrivate: false,
        createdAt: Date().addingTimeInterval(-86400 * 365)
    )
    
    static let mockFriend = AppUser(
        id: "user-2",
        username: "mikej",
        displayName: "Mike J",
        avatarURL: nil,
        bio: "Chasing that 405 deadlift",
        stats: UserStats(
            totalWorkouts: 189,
            totalVolume: 987_450,
            totalPRs: 31,
            currentStreak: 3,
            longestStreak: 21,
            favoriteExercise: "Deadlift"
        ),
        isPrivate: false,
        createdAt: Date().addingTimeInterval(-86400 * 200)
    )
}
