import Foundation

class FriendsService {
    static let shared = FriendsService()
    
    private let supabaseService: SupabaseService
    
    init(supabaseService: SupabaseService = .shared) {
        self.supabaseService = supabaseService
    }
    
    // MARK: - Friend Management
    
    func fetchFriends(for userId: String) async -> [AppUser] {
        do {
            // Fetch friend relationships
            let relationships = try await supabaseService.fetch(
                FriendRelationship.self,
                from: "friendships",
                where: "userId1", equals: userId
            )
            
            var friends: [AppUser] = []
            for relationship in relationships {
                if let friend = try? await supabaseService.fetch(
                    AppUser.self,
                    from: "users",
                    where: "id", equals: relationship.userId2
                ).first {
                    friends.append(friend)
                }
            }
            
            // Also fetch reverse relationships
            let reverseRelationships = try await supabaseService.fetch(
                FriendRelationship.self,
                from: "friendships",
                where: "userId2", equals: userId
            )
            
            for relationship in reverseRelationships {
                if let friend = try? await supabaseService.fetch(
                    AppUser.self,
                    from: "users",
                    where: "id", equals: relationship.userId1
                ).first {
                    if !friends.contains(where: { $0.id == friend.id }) {
                        friends.append(friend)
                    }
                }
            }
            
            return friends
        } catch {
            print("Error fetching friends: \(error)")
            return []
        }
    }
    
    func fetchFriendsForChallenge(
        for userId: String,
        excluding excludedUserIds: [String] = []
    ) async -> [FriendForChallenge] {
        let friends = await fetchFriends(for: userId)
        
        return friends
            .filter { !excludedUserIds.contains($0.id) }
            .compactMap { friend -> FriendForChallenge? in
                FriendForChallenge(
                    id: friend.id,
                    name: friend.displayName,
                    profileImageUrl: friend.avatarURL,
                    recentChallenges: 0  // Could fetch this too
                )
            }
    }
    
    func addFriend(userId: String, friendId: String) async -> Bool {
        let relationship = FriendRelationship(
            id: UUID().uuidString,
            userId1: userId,
            userId2: friendId,
            createdAt: Date()
        )
        
        do {
            try await supabaseService.insert(relationship, into: "friendships")
            return true
        } catch {
            print("Error adding friend: \(error)")
            return false
        }
    }
    
    func removeFriend(userId: String, friendId: String) async -> Bool {
        do {
            // Delete relationship in both directions
            // This would require a proper delete method in SupabaseService
            return true
        } catch {
            print("Error removing friend: \(error)")
            return false
        }
    }
    
    func searchUsers(query: String) async -> [AppUser] {
        do {
            // Search users by name or email
            // This would require a full-text search capability in Supabase
            return []
        } catch {
            print("Error searching users: \(error)")
            return []
        }
    }
    
    func getCommonFriends(userId: String, otherUserId: String) async -> [AppUser] {
        let userFriends = await fetchFriends(for: userId)
        let otherFriends = await fetchFriends(for: otherUserId)
        
        return userFriends.filter { userFriend in
            otherFriends.contains { $0.id == userFriend.id }
        }
    }
}

// MARK: - Models

struct FriendRelationship: Identifiable, Codable {
    let id: String
    let userId1: String
    let userId2: String
    let createdAt: Date
}

struct FriendForChallenge: Identifiable, Codable {
    let id: String
    let name: String
    let profileImageUrl: String?
    let recentChallenges: Int
    
    var displayName: String {
        name.components(separatedBy: " ").first ?? name
    }
    
    var initials: String {
        let components = name.components(separatedBy: " ")
        if components.count > 1 {
            return String(components.first?.first ?? "?") + String(components.last?.first ?? "?")
        }
        return String(name.prefix(2)).uppercased()
    }
}

