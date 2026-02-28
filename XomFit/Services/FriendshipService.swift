import Foundation

protocol FriendshipServiceProtocol {
    // Friend Request Operations
    func sendFriendRequest(toUserId: String) async throws -> FriendRequest
    func acceptFriendRequest(requestId: String) async throws -> Friendship
    func declineFriendRequest(requestId: String) async throws
    func cancelFriendRequest(requestId: String) async throws
    
    // Fetch Operations
    func fetchPendingRequests(userId: String) async throws -> [FriendRequest]
    func fetchFriends(userId: String) async throws -> [User]
    func fetchFollowing(userId: String) async throws -> [User]
    func fetchFollowers(userId: String) async throws -> [User]
    func searchUsers(query: String) async throws -> [User]
    func getMutualFriends(userId: String, otherUserId: String) async throws -> [User]
    func getSuggestedFriends(userId: String) async throws -> [FriendSuggestion]
    
    // Status Operations
    func isFriend(userId: String, friendId: String) async throws -> Bool
    func isFollowing(userId: String, targetId: String) async throws -> Bool
    func getFriendshipStatus(userId: String, otherUserId: String) async throws -> FriendshipStatus?
}

enum FriendshipStatus {
    case friend
    case following
    case follower
    case mutualFollows
    case none
}

class FriendshipService: FriendshipServiceProtocol {
    static let shared = FriendshipService()
    private let baseURL = "https://api.xomfit.com/v1" // TODO: Configure
    
    // MARK: - Friend Request Operations
    
    func sendFriendRequest(toUserId: String) async throws -> FriendRequest {
        // TODO: Replace with real API call
        let request = FriendRequest(
            id: UUID().uuidString,
            fromUserId: "current-user-id",
            toUserId: toUserId,
            status: .pending,
            createdAt: Date(),
            updatedAt: Date(),
            fromUser: .mock,
            toUser: nil
        )
        return request
    }
    
    func acceptFriendRequest(requestId: String) async throws -> Friendship {
        // TODO: Replace with real API call
        let friendship = Friendship(
            id: UUID().uuidString,
            userId: "current-user-id",
            friendId: "other-user-id",
            status: .mutual,
            createdAt: Date()
        )
        return friendship
    }
    
    func declineFriendRequest(requestId: String) async throws {
        // TODO: Replace with real API call
        // Mark request as declined
    }
    
    func cancelFriendRequest(requestId: String) async throws {
        // TODO: Replace with real API call
        // Delete the request
    }
    
    // MARK: - Fetch Operations
    
    func fetchPendingRequests(userId: String) async throws -> [FriendRequest] {
        // TODO: Replace with real API call
        return [.mockPending]
    }
    
    func fetchFriends(userId: String) async throws -> [User] {
        // TODO: Replace with real API call
        // Returns users with mutual friendships
        return [.mockFriend]
    }
    
    func fetchFollowing(userId: String) async throws -> [User] {
        // TODO: Replace with real API call
        // Returns users that userId is following
        return [.mockFriend]
    }
    
    func fetchFollowers(userId: String) async throws -> [User] {
        // TODO: Replace with real API call
        // Returns users following userId
        return [.mockFriend]
    }
    
    func searchUsers(query: String) async throws -> [User] {
        // TODO: Replace with real API call
        // Search by username, displayName, or bio
        guard !query.isEmpty else { return [] }
        return [.mockFriend, .mock]
    }
    
    func getMutualFriends(userId: String, otherUserId: String) async throws -> [User] {
        // TODO: Replace with real API call
        // Returns users that are friends with both userId and otherUserId
        return [.mockFriend]
    }
    
    func getSuggestedFriends(userId: String) async throws -> [FriendSuggestion] {
        // TODO: Replace with real API call
        // Returns suggested friends based on:
        // - Same gym
        // - Mutual connections
        // - Similar interests/exercises
        return [.mockSameGym, .mockMutualFriends]
    }
    
    // MARK: - Status Operations
    
    func isFriend(userId: String, friendId: String) async throws -> Bool {
        // TODO: Replace with real API call
        // Returns true if users have mutual friendship
        return true
    }
    
    func isFollowing(userId: String, targetId: String) async throws -> Bool {
        // TODO: Replace with real API call
        // Returns true if userId is following targetId
        return true
    }
    
    func getFriendshipStatus(userId: String, otherUserId: String) async throws -> FriendshipStatus? {
        // TODO: Replace with real API call
        // Determine the relationship between two users
        return .friend
    }
}
