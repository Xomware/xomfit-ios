import Foundation
import Supabase

// MARK: - FriendsViewModel

@MainActor
@Observable
final class FriendsViewModel {
    // MARK: - Friends
    var friends: [FriendRow] = []
    var friendProfiles: [String: ProfileRow] = [:]

    // MARK: - Requests
    var incomingRequests: [FriendRow] = []
    var outgoingRequests: [FriendRow] = []
    var requesterProfiles: [String: ProfileRow] = [:]   // for incoming rows
    var addresseeProfiles: [String: ProfileRow] = [:]   // for outgoing rows

    // MARK: - Search
    var searchQuery: String = ""
    var searchResults: [ProfileRow] = []
    var searchRelations: [String: FriendshipRelation] = [:]
    var isSearching: Bool = false

    // MARK: - State
    var isLoading: Bool = false
    var errorMessage: String?

    // MARK: - Load All

    func loadAll(userId: String) async {
        guard !userId.isEmpty else { return }
        isLoading = true

        async let friendsTask = FriendsService.shared.fetchFriends(userId: userId)
        async let incomingTask = FriendsService.shared.fetchPendingRequests(userId: userId)
        async let outgoingTask = FriendsService.shared.fetchOutgoingRequests(userId: userId)

        do {
            let (friendsResult, incomingResult, outgoingResult) = try await (friendsTask, incomingTask, outgoingTask)
            friends = friendsResult
            incomingRequests = incomingResult
            outgoingRequests = outgoingResult

            await hydrateProfiles(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func hydrateProfiles(userId: String) async {
        // Friends
        for friend in friends {
            let friendId = friend.requesterId == userId ? friend.addresseeId : friend.requesterId
            if friendProfiles[friendId] == nil {
                if let profile = try? await ProfileService.shared.fetchProfile(userId: friendId) {
                    friendProfiles[friendId] = profile
                }
            }
        }
        // Incoming (requester is the other user)
        for req in incomingRequests where requesterProfiles[req.requesterId] == nil {
            if let profile = try? await ProfileService.shared.fetchProfile(userId: req.requesterId) {
                requesterProfiles[req.requesterId] = profile
            }
        }
        // Outgoing (addressee is the other user)
        for req in outgoingRequests where addresseeProfiles[req.addresseeId] == nil {
            if let profile = try? await ProfileService.shared.fetchProfile(userId: req.addresseeId) {
                addresseeProfiles[req.addresseeId] = profile
            }
        }
    }

    // MARK: - Search

    func clearSearch() {
        searchResults = []
        searchRelations = [:]
        isSearching = false
    }

    func performSearch(query: String, userId: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !userId.isEmpty else {
            searchResults = []
            searchRelations = [:]
            return
        }
        isSearching = true
        do {
            let results = try await FriendsService.shared.searchUsers(query: trimmed, excludeUserId: userId)
            searchResults = results
            let ids = results.map { $0.id }
            let relations = try await FriendsService.shared.batchRelations(currentUserId: userId, otherUserIds: ids)
            searchRelations = relations
        } catch {
            errorMessage = error.localizedDescription
            searchResults = []
            searchRelations = [:]
        }
        isSearching = false
    }

    // MARK: - Mutations

    func sendRequest(fromUserId: String, toUserId: String) async {
        do {
            let newId = try await FriendsService.shared.sendFriendRequest(
                fromUserId: fromUserId,
                toUserId: toUserId
            )
            searchRelations[toUserId] = .outgoingPending(friendshipId: newId)
            // Reconcile outgoing list: add a synthetic row until next reload
            let nowIso = ISO8601DateFormatter().string(from: Date())
            let row = FriendRow(
                id: newId,
                requesterId: fromUserId,
                addresseeId: toUserId,
                status: "pending",
                createdAt: nowIso
            )
            outgoingRequests.append(row)
            // Cache profile for display
            if let profile = searchResults.first(where: { $0.id == toUserId }) {
                addresseeProfiles[toUserId] = profile
            }
        } catch FriendError.alreadyExists(let existing) {
            searchRelations[toUserId] = existing
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancelRequest(friendshipId: String, otherUserId: String) async {
        do {
            try await FriendsService.shared.cancelFriendRequest(friendshipId: friendshipId)
            outgoingRequests.removeAll { $0.id == friendshipId }
            searchRelations[otherUserId] = .none
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func acceptRequest(friendshipId: String, otherUserId: String, userId: String) async {
        do {
            try await FriendsService.shared.acceptFriendRequest(friendshipId: friendshipId)
            if let idx = incomingRequests.firstIndex(where: { $0.id == friendshipId }) {
                var row = incomingRequests.remove(at: idx)
                row = FriendRow(
                    id: row.id,
                    requesterId: row.requesterId,
                    addresseeId: row.addresseeId,
                    status: "accepted",
                    createdAt: row.createdAt
                )
                friends.append(row)
                // Promote incoming requester profile into friend profile cache
                if let profile = requesterProfiles[row.requesterId] {
                    friendProfiles[row.requesterId] = profile
                }
            }
            searchRelations[otherUserId] = .friends(friendshipId: friendshipId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func declineRequest(friendshipId: String, otherUserId: String) async {
        do {
            try await FriendsService.shared.declineFriendRequest(friendshipId: friendshipId)
            incomingRequests.removeAll { $0.id == friendshipId }
            searchRelations[otherUserId] = .none
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeFriend(friendshipId: String, otherUserId: String) async {
        do {
            try await FriendsService.shared.removeFriend(friendshipId: friendshipId)
            friends.removeAll { $0.id == friendshipId }
            searchRelations[otherUserId] = .none
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
