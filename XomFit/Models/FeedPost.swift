import Foundation

struct FeedPost: Codable, Identifiable {
    let id: String
    var user: User
    var workout: Workout
    var likes: Int
    var isLiked: Bool
    var comments: [Comment]
    var reactions: [String] // emoji strings
    var reactionCounts: [String: Int] // emoji: count
    var createdAt: Date
    
    struct Comment: Codable, Identifiable {
        let id: String
        var user: User
        var text: String
        var createdAt: Date
    }
    
    // Helper to check if current user has reacted with specific emoji
    func hasUserReacted(with emoji: String) -> Bool {
        reactions.contains(emoji)
    }
}

// MARK: - Mock Data
extension FeedPost {
    static let mockFeed: [FeedPost] = [
        FeedPost(
            id: "fp-1",
            user: .mock,
            workout: .mock,
            likes: 12,
            isLiked: false,
            comments: [
                Comment(id: "c-1", user: .mockFriend, text: "Nice bench! 💪", createdAt: Date().addingTimeInterval(-1800))
            ],
            reactions: ["💪", "🔥"],
            reactionCounts: ["💪": 3, "🔥": 2],
            createdAt: Date().addingTimeInterval(-3600)
        ),
        FeedPost(
            id: "fp-2",
            user: .mockFriend,
            workout: .mockFriendWorkout,
            likes: 8,
            isLiked: true,
            comments: [],
            reactions: ["💪"],
            reactionCounts: ["💪": 5],
            createdAt: Date().addingTimeInterval(-7200)
        ),
    ]
}
