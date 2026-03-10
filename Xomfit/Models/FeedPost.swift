import Foundation

struct FeedPost: Codable, Identifiable {
    let id: String
    var user: AppUser
    var workout: Workout
    var likes: Int
    var isLiked: Bool
    var comments: [Comment]
    var createdAt: Date
    
    struct Comment: Codable, Identifiable {
        let id: String
        var user: AppUser
        var text: String
        var createdAt: Date
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
            createdAt: Date().addingTimeInterval(-3600)
        ),
        FeedPost(
            id: "fp-2",
            user: .mockFriend,
            workout: .mockFriendWorkout,
            likes: 8,
            isLiked: true,
            comments: [],
            createdAt: Date().addingTimeInterval(-7200)
        ),
    ]
}
