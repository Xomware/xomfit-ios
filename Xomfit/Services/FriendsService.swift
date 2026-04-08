import Foundation
import Supabase

// MARK: - DB Row Types

struct FriendRow: Codable, Identifiable {
    let id: String
    let requesterId: String
    let addresseeId: String
    let status: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case requesterId = "requester_id"
        case addresseeId = "addressee_id"
        case status
        case createdAt = "created_at"
    }
}

// MARK: - Insert / Update Payloads

private struct FriendshipInsert: Encodable {
    let id: String
    let requester_id: String
    let addressee_id: String
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
        // Friends where I'm the requester
        let sent: [FriendRow] = try await supabase
            .from("friendships")
            .select()
            .eq("requester_id", value: userId)
            .eq("status", value: "accepted")
            .execute()
            .value

        // Friends where I'm the addressee
        let received: [FriendRow] = try await supabase
            .from("friendships")
            .select()
            .eq("addressee_id", value: userId)
            .eq("status", value: "accepted")
            .execute()
            .value

        return sent + received
    }

    // MARK: - Fetch Pending Requests (requests sent TO this user)

    func fetchPendingRequests(userId: String) async throws -> [FriendRow] {
        let rows: [FriendRow] = try await supabase
            .from("friendships")
            .select()
            .eq("addressee_id", value: userId)
            .eq("status", value: "pending")
            .execute()
            .value
        return rows
    }

    // MARK: - Send Friend Request

    func sendFriendRequest(fromUserId: String, toUserId: String) async throws {
        let insert = FriendshipInsert(
            id: UUID().uuidString.lowercased(),
            requester_id: fromUserId,
            addressee_id: toUserId,
            status: "pending"
        )
        try await supabase
            .from("friendships")
            .insert(insert)
            .execute()
    }

    // MARK: - Accept Friend Request

    func acceptFriendRequest(friendshipId: String) async throws {
        let update = FriendshipStatusUpdate(status: "accepted")
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

    func searchUsers(query: String, excludeUserId: String? = nil) async throws -> [ProfileRow] {
        guard !query.isEmpty else { return [] }

        // Search by username
        let byUsername: [ProfileRow] = try await supabase
            .from("profiles")
            .select()
            .ilike("username", pattern: "%\(query)%")
            .limit(20)
            .execute()
            .value

        // Search by display name
        let byName: [ProfileRow] = try await supabase
            .from("profiles")
            .select()
            .ilike("display_name", pattern: "%\(query)%")
            .limit(20)
            .execute()
            .value

        // Merge and deduplicate
        var seen = Set<String>()
        var rows: [ProfileRow] = []
        for row in byUsername + byName {
            if seen.insert(row.id).inserted {
                rows.append(row)
            }
        }

        if let excludeId = excludeUserId {
            rows = rows.filter { $0.id != excludeId }
        }

        return rows
    }
}
