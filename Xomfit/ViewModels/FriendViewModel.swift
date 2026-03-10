import Foundation

@MainActor
class FriendViewModel: ObservableObject {
    @Published var friends: [AppUser] = []
    @Published var following: [AppUser] = []
    @Published var followers: [AppUser] = []
    @Published var pendingRequests: [FriendRequest] = []
    @Published var suggestedFriends: [FriendSuggestion] = []
    @Published var searchResults: [AppUser] = []
    
    @Published var isLoading = false
    @Published var error: String?
    
    private let friendshipService: FriendshipServiceProtocol
    private let currentUserId: String
    
    init(
        friendshipService: FriendshipServiceProtocol = FriendshipService.shared,
        currentUserId: String = "current-user-id"
    ) {
        self.friendshipService = friendshipService
        self.currentUserId = currentUserId
    }
    
    // MARK: - Friend Request Actions
    
    func sendFriendRequest(toUserId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let request = try await friendshipService.sendFriendRequest(toUserId: toUserId)
            // Remove from suggested if present
            suggestedFriends.removeAll { $0.user.id == toUserId }
            // Show success
            error = nil
        } catch {
            self.error = "Failed to send friend request: \(error.localizedDescription)"
        }
    }
    
    func acceptFriendRequest(_ request: FriendRequest) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let friendship = try await friendshipService.acceptFriendRequest(requestId: request.id)
            
            // Remove from pending requests
            pendingRequests.removeAll { $0.id == request.id }
            
            // Add to friends if user data available
            if let fromUser = request.fromUser {
                friends.append(fromUser)
            }
            
            error = nil
        } catch {
            self.error = "Failed to accept friend request: \(error.localizedDescription)"
        }
    }
    
    func declineFriendRequest(_ request: FriendRequest) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await friendshipService.declineFriendRequest(requestId: request.id)
            pendingRequests.removeAll { $0.id == request.id }
            error = nil
        } catch {
            self.error = "Failed to decline friend request: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Fetch Data
    
    func loadFriends() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            friends = try await friendshipService.fetchFriends(userId: currentUserId)
            error = nil
        } catch {
            self.error = "Failed to load friends: \(error.localizedDescription)"
        }
    }
    
    func loadFollowing() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            following = try await friendshipService.fetchFollowing(userId: currentUserId)
            error = nil
        } catch {
            self.error = "Failed to load following: \(error.localizedDescription)"
        }
    }
    
    func loadFollowers() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            followers = try await friendshipService.fetchFollowers(userId: currentUserId)
            error = nil
        } catch {
            self.error = "Failed to load followers: \(error.localizedDescription)"
        }
    }
    
    func loadPendingRequests() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            pendingRequests = try await friendshipService.fetchPendingRequests(userId: currentUserId)
            error = nil
        } catch {
            self.error = "Failed to load pending requests: \(error.localizedDescription)"
        }
    }
    
    func loadSuggestedFriends() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            suggestedFriends = try await friendshipService.getSuggestedFriends(userId: currentUserId)
            error = nil
        } catch {
            self.error = "Failed to load suggested friends: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Search
    
    func searchUsers(_ query: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            searchResults = try await friendshipService.searchUsers(query: query)
            error = nil
        } catch {
            self.error = "Search failed: \(error.localizedDescription)"
        }
    }
    
    func clearSearch() {
        searchResults = []
        error = nil
    }
    
    // MARK: - Status Checks
    
    func getMutualFriendsCount(with userId: String) async -> Int {
        do {
            let mutuals = try await friendshipService.getMutualFriends(userId: currentUserId, otherUserId: userId)
            return mutuals.count
        } catch {
            return 0
        }
    }
}
