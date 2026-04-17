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

// MARK: - Relation

enum FriendshipRelation: Equatable {
    case none
    case outgoingPending(friendshipId: String)
    case incomingPending(friendshipId: String)
    case friends(friendshipId: String)
    case blocked(friendshipId: String, blockedByCurrentUser: Bool)
}

enum FriendError: Error {
    case alreadyExists(relation: FriendshipRelation)
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

    // MARK: - Fetch Outgoing Requests (requests sent FROM this user)

    func fetchOutgoingRequests(userId: String) async throws -> [FriendRow] {
        let rows: [FriendRow] = try await supabase
            .from("friendships")
            .select()
            .eq("requester_id", value: userId)
            .eq("status", value: "pending")
            .execute()
            .value
        return rows
    }

    // MARK: - Relation Lookup

    /// Fetch the direction-aware friendship relation between the current user and another user.
    /// Returns `.none` if there is no row or the row is `declined` (treated as re-requestable).
    func relation(currentUserId: String, otherUserId: String) async throws -> FriendshipRelation {
        let rows: [FriendRow] = try await supabase
            .from("friendships")
            .select()
            .or("and(requester_id.eq.\(currentUserId),addressee_id.eq.\(otherUserId)),and(requester_id.eq.\(otherUserId),addressee_id.eq.\(currentUserId))")
            .limit(1)
            .execute()
            .value

        guard let row = rows.first else { return .none }
        return mapRelation(row: row, currentUserId: currentUserId)
    }

    /// Batch-fetch relations between the current user and a list of other users.
    /// Returns a dictionary keyed by the OTHER user id. Users with no row (or declined rows)
    /// are omitted from the dictionary; call sites should treat missing entries as `.none`.
    func batchRelations(currentUserId: String, otherUserIds: [String]) async throws -> [String: FriendshipRelation] {
        guard !otherUserIds.isEmpty else { return [:] }

        // Rows where current user is the requester
        let outgoing: [FriendRow] = try await supabase
            .from("friendships")
            .select()
            .eq("requester_id", value: currentUserId)
            .in("addressee_id", values: otherUserIds)
            .execute()
            .value

        // Rows where current user is the addressee
        let incoming: [FriendRow] = try await supabase
            .from("friendships")
            .select()
            .eq("addressee_id", value: currentUserId)
            .in("requester_id", values: otherUserIds)
            .execute()
            .value

        var result: [String: FriendshipRelation] = [:]
        for row in outgoing + incoming {
            let otherId = row.requesterId == currentUserId ? row.addresseeId : row.requesterId
            let relation = mapRelation(row: row, currentUserId: currentUserId)
            if case .none = relation {
                continue // drop declined/unknown rows
            }
            result[otherId] = relation // last write wins (UNIQUE constraint makes this safe in practice)
        }
        return result
    }

    private func mapRelation(row: FriendRow, currentUserId: String) -> FriendshipRelation {
        let isOutgoing = row.requesterId == currentUserId
        switch row.status {
        case "pending":
            return isOutgoing ? .outgoingPending(friendshipId: row.id) : .incomingPending(friendshipId: row.id)
        case "accepted":
            return .friends(friendshipId: row.id)
        case "blocked":
            return .blocked(friendshipId: row.id, blockedByCurrentUser: isOutgoing)
        case "declined":
            return .none   // treat as if no row; re-request is allowed
        default:
            return .none
        }
    }

    // MARK: - Send Friend Request

    @discardableResult
    func sendFriendRequest(fromUserId: String, toUserId: String) async throws -> String {
        let existing = try await relation(currentUserId: fromUserId, otherUserId: toUserId)
        switch existing {
        case .none:
            break  // proceed with insert
        case .blocked, .outgoingPending, .incomingPending, .friends:
            throw FriendError.alreadyExists(relation: existing)
        }

        let newId = UUID().uuidString.lowercased()
        let insert = FriendshipInsert(
            id: newId,
            requester_id: fromUserId,
            addressee_id: toUserId,
            status: "pending"
        )
        try await supabase
            .from("friendships")
            .insert(insert)
            .execute()
        return newId
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

    // MARK: - Decline / Cancel / Remove

    func declineFriendRequest(friendshipId: String) async throws {
        try await supabase
            .from("friendships")
            .delete()
            .eq("id", value: friendshipId)
            .execute()
    }

    /// Cancel an outgoing pending request. Thin wrapper over `declineFriendRequest` for call-site clarity.
    func cancelFriendRequest(friendshipId: String) async throws {
        try await declineFriendRequest(friendshipId: friendshipId)
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
