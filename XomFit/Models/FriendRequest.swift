import Foundation

enum FriendRequestStatus: String, Codable {
    case pending
    case accepted
    case declined
}

struct FriendRequest: Codable, Identifiable {
    let id: String
    let fromUserId: String
    let toUserId: String
    var status: FriendRequestStatus
    let createdAt: Date
    let updatedAt: Date
    
    // For UI display
    var fromUser: User?
    var toUser: User?
}

// MARK: - Mock Data
extension FriendRequest {
    static let mockPending = FriendRequest(
        id: "fr-1",
        fromUserId: "user-2",
        toUserId: "user-1",
        status: .pending,
        createdAt: Date().addingTimeInterval(-3600),
        updatedAt: Date().addingTimeInterval(-3600),
        fromUser: .mockFriend,
        toUser: .mock
    )
    
    static let mockAccepted = FriendRequest(
        id: "fr-2",
        fromUserId: "user-1",
        toUserId: "user-3",
        status: .accepted,
        createdAt: Date().addingTimeInterval(-86400 * 7),
        updatedAt: Date().addingTimeInterval(-86400 * 7),
        fromUser: .mock,
        toUser: nil
    )
}
