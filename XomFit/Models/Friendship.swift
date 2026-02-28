import Foundation

struct Friendship: Codable, Identifiable {
    let id: String
    let userId: String
    let friendId: String
    let status: FriendshipStatus
    let createdAt: Date
    
    enum FriendshipStatus: String, Codable {
        case following      // One-way follow
        case mutual         // Bidirectional friendship
    }
}

// MARK: - Mock Data
extension Friendship {
    static let mockMutual = Friendship(
        id: "f-1",
        userId: "user-1",
        friendId: "user-2",
        status: .mutual,
        createdAt: Date().addingTimeInterval(-86400 * 30)
    )
    
    static let mockFollowing = Friendship(
        id: "f-2",
        userId: "user-1",
        friendId: "user-4",
        status: .following,
        createdAt: Date().addingTimeInterval(-86400 * 15)
    )
}
