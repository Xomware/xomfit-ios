import Foundation
import Supabase

// MARK: - DB Row Types

struct FriendRow: Codable, Identifiable {
    let id: String
    let userId: String
    let friendId: String
    let status: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case friendId = "friend_id"
        case status
        case createdAt = "created_at"
    }
}

// MARK: - Insert / Update Payloads

private struct FriendshipInsert: Encodable {
    let id: String
    let user_id: String
    let friend_id: String
    let status: String
}

private struct FriendshipStatusUpdate: Encodable {
    let status: String
}

// MARK: - FriendsService

@MainActor
final class FriendsService {
    static let shared = FriendsService()

    private init() {}

    // MARK: - Fetch Friends

    func fetchFriends(userId: String) async throws -> [FriendRow] {
        let rows: [FriendRow] = try await supabase
            .from("friendships")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        return rows
    }

    // MARK: - Fetch Pending Requests (requests sent TO this user)

    func fetchPendingRequests(userId: String) async throws -> [FriendRow] {
        let rows: [FriendRow] = try await supabase
            .from("friendships")
            .select()
            .eq("friend_id", value: userId)
            .eq("status", value: "pending")
            .execute()
            .value
        return rows
    }

    // MARK: - Send Friend Request

    func sendFriendRequest(fromUserId: String, toUserId: String) async throws {
        let insert = FriendshipInsert(
            id: UUID().uuidString,
            user_id: fromUserId,
            friend_id: toUserId,
            status: "pending"
        )
        try await supabase
            .from("friendships")
            .insert(insert)
            .execute()
    }

    // MARK: - Accept Friend Request

    func acceptFriendRequest(friendshipId: String) async throws {
        let update = FriendshipStatusUpdate(status: "mutual")
        try await supabase
            .from("friendships")
            .update(update)
            .eq("id", value: friendshipId)
            .execute()
    }

    // MARK: - Decline / Remove

    func declineFriendRequest(friendshipId: String) async throws {
        try await supabase
            .from("friendships")
            .delete()
            .eq("id", value: friendshipId)
            .execute()
    }

    func removeFriend(friendshipId: String) async throws {
        try await supabase
            .from("friendships")
            .delete()
            .eq("id", value: friendshipId)
            .execute()
    }

    // MARK: - Search Users

    func searchUsers(query: String) async throws -> [ProfileRow] {
        guard !query.isEmpty else { return [] }
        let rows: [ProfileRow] = try await supabase
            .from("profiles")
            .select()
            .ilike("username", value: "%\(query)%")
            .limit(20)
            .execute()
            .value
        return rows
    }
}
