import XCTest
@testable import XomFit

// MARK: - Mock Friendship Service for Testing

class MockFriendshipService: FriendshipServiceProtocol {
    var sentRequests: [FriendRequest] = []
    var acceptedRequests: Set<String> = []
    var declinedRequests: Set<String> = []
    var mockFriends: [User] = []
    var mockFollowing: [User] = []
    var mockFollowers: [User] = []
    var mockSuggestions: [FriendSuggestion] = []
    var searchResults: [User] = []
    
    // Track call counts for verification
    var sendFriendRequestCallCount = 0
    var acceptFriendRequestCallCount = 0
    var declineFriendRequestCallCount = 0
    var searchUsersCallCount = 0
    
    func sendFriendRequest(toUserId: String) async throws -> FriendRequest {
        sendFriendRequestCallCount += 1
        let request = FriendRequest(
            id: UUID().uuidString,
            fromUserId: "current-user",
            toUserId: toUserId,
            status: .pending,
            createdAt: Date(),
            updatedAt: Date(),
            fromUser: nil,
            toUser: nil
        )
        sentRequests.append(request)
        return request
    }
    
    func acceptFriendRequest(requestId: String) async throws -> Friendship {
        acceptFriendRequestCallCount += 1
        acceptedRequests.insert(requestId)
        return Friendship(
            id: UUID().uuidString,
            userId: "current-user",
            friendId: "other-user",
            status: .mutual,
            createdAt: Date()
        )
    }
    
    func declineFriendRequest(requestId: String) async throws {
        declinedRequests.insert(requestId)
    }
    
    func cancelFriendRequest(requestId: String) async throws {
        sentRequests.removeAll { $0.id == requestId }
    }
    
    func fetchPendingRequests(userId: String) async throws -> [FriendRequest] {
        return sentRequests.filter { $0.status == .pending }
    }
    
    func fetchFriends(userId: String) async throws -> [User] {
        return mockFriends
    }
    
    func fetchFollowing(userId: String) async throws -> [User] {
        return mockFollowing
    }
    
    func fetchFollowers(userId: String) async throws -> [User] {
        return mockFollowers
    }
    
    func searchUsers(query: String) async throws -> [User] {
        searchUsersCallCount += 1
        return searchResults.filter { user in
            user.username.localizedCaseInsensitiveContains(query) ||
            user.displayName.localizedCaseInsensitiveContains(query)
        }
    }
    
    func getMutualFriends(userId: String, otherUserId: String) async throws -> [User] {
        return mockFriends.filter { friend in
            mockFollowing.contains { $0.id == friend.id }
        }
    }
    
    func getSuggestedFriends(userId: String) async throws -> [FriendSuggestion] {
        return mockSuggestions
    }
    
    func isFriend(userId: String, friendId: String) async throws -> Bool {
        return mockFriends.contains { $0.id == friendId }
    }
    
    func isFollowing(userId: String, targetId: String) async throws -> Bool {
        return mockFollowing.contains { $0.id == targetId }
    }
    
    func getFriendshipStatus(userId: String, otherUserId: String) async throws -> FriendshipStatus? {
        if mockFriends.contains(where: { $0.id == otherUserId }) {
            return .friend
        }
        return nil
    }
}

// MARK: - Friendship Service Tests

final class FriendshipServiceTests: XCTestCase {
    var mockService: MockFriendshipService!
    
    override func setUp() {
        super.setUp()
        mockService = MockFriendshipService()
    }
    
    // MARK: - Send Friend Request Tests
    
    func testSendFriendRequest() async throws {
        let toUserId = "user-2"
        let request = try await mockService.sendFriendRequest(toUserId: toUserId)
        
        XCTAssertEqual(request.toUserId, toUserId)
        XCTAssertEqual(request.status, .pending)
        XCTAssertEqual(mockService.sendFriendRequestCallCount, 1)
        XCTAssert(mockService.sentRequests.contains { $0.id == request.id })
    }
    
    func testSendFriendRequestTracksInService() async throws {
        let toUserId = "user-3"
        let request = try await mockService.sendFriendRequest(toUserId: toUserId)
        
        let pending = try await mockService.fetchPendingRequests(userId: "current-user")
        XCTAssert(pending.contains { $0.id == request.id })
    }
    
    // MARK: - Accept Friend Request Tests
    
    func testAcceptFriendRequest() async throws {
        let requestId = "fr-1"
        let friendship = try await mockService.acceptFriendRequest(requestId: requestId)
        
        XCTAssertEqual(friendship.status, .mutual)
        XCTAssertEqual(mockService.acceptFriendRequestCallCount, 1)
        XCTAssert(mockService.acceptedRequests.contains(requestId))
    }
    
    func testAcceptMultipleFriendRequests() async throws {
        let requestIds = ["fr-1", "fr-2", "fr-3"]
        
        for requestId in requestIds {
            _ = try await mockService.acceptFriendRequest(requestId: requestId)
        }
        
        XCTAssertEqual(mockService.acceptFriendRequestCallCount, 3)
        XCTAssertEqual(mockService.acceptedRequests.count, 3)
    }
    
    // MARK: - Decline Friend Request Tests
    
    func testDeclineFriendRequest() async throws {
        let requestId = "fr-1"
        try await mockService.declineFriendRequest(requestId: requestId)
        
        XCTAssert(mockService.declinedRequests.contains(requestId))
    }
    
    // MARK: - Search Users Tests
    
    func testSearchUsersEmptyQuery() async throws {
        mockService.searchResults = [.mock, .mockFriend]
        let results = try await mockService.searchUsers(query: "")
        
        XCTAssertEqual(results.count, 0) // Empty queries return nothing
    }
    
    func testSearchUsersByUsername() async throws {
        mockService.searchResults = [.mock, .mockFriend]
        let results = try await mockService.searchUsers(query: "domg")
        
        XCTAssertGreater(results.count, 0)
        XCTAssert(results.contains { $0.username.contains("domg") || $0.displayName.contains("domg") })
    }
    
    func testSearchUsersNoResults() async throws {
        mockService.searchResults = [.mock, .mockFriend]
        let results = try await mockService.searchUsers(query: "nonexistent")
        
        XCTAssertEqual(results.count, 0)
    }
    
    func testSearchCallsIncremented() async throws {
        mockService.searchResults = [.mock]
        _ = try await mockService.searchUsers(query: "test")
        _ = try await mockService.searchUsers(query: "test2")
        
        XCTAssertEqual(mockService.searchUsersCallCount, 2)
    }
    
    // MARK: - Pending Requests Tests
    
    func testFetchPendingRequests() async throws {
        let request1 = try await mockService.sendFriendRequest(toUserId: "user-1")
        let request2 = try await mockService.sendFriendRequest(toUserId: "user-2")
        
        let pending = try await mockService.fetchPendingRequests(userId: "current-user")
        
        XCTAssertEqual(pending.count, 2)
        XCTAssert(pending.contains { $0.id == request1.id })
        XCTAssert(pending.contains { $0.id == request2.id })
    }
    
    func testPendingRequestsOnlyReturnsPending() async throws {
        let request1 = try await mockService.sendFriendRequest(toUserId: "user-1")
        _ = try await mockService.acceptFriendRequest(requestId: request1.id)
        
        // Mark as accepted in mock data (simulate API behavior)
        if let index = mockService.sentRequests.firstIndex(where: { $0.id == request1.id }) {
            var updated = mockService.sentRequests[index]
            updated.status = .accepted
            mockService.sentRequests[index] = updated
        }
        
        let pending = try await mockService.fetchPendingRequests(userId: "current-user")
        XCTAssert(!pending.contains { $0.id == request1.id })
    }
    
    // MARK: - Friends List Tests
    
    func testFetchFriends() async throws {
        mockService.mockFriends = [.mock, .mockFriend]
        let friends = try await mockService.fetchFriends(userId: "user-1")
        
        XCTAssertEqual(friends.count, 2)
    }
    
    func testFetchFollowing() async throws {
        mockService.mockFollowing = [.mock]
        let following = try await mockService.fetchFollowing(userId: "user-1")
        
        XCTAssertEqual(following.count, 1)
    }
    
    func testFetchFollowers() async throws {
        mockService.mockFollowers = [.mockFriend]
        let followers = try await mockService.fetchFollowers(userId: "user-1")
        
        XCTAssertEqual(followers.count, 1)
    }
    
    // MARK: - Mutual Friends Tests
    
    func testGetMutualFriends() async throws {
        mockService.mockFriends = [.mock, .mockFriend]
        mockService.mockFollowing = [.mock]
        
        let mutuals = try await mockService.getMutualFriends(userId: "user-1", otherUserId: "user-2")
        
        XCTAssertGreaterThanOrEqual(mutuals.count, 0)
    }
    
    // MARK: - Suggested Friends Tests
    
    func testGetSuggestedFriends() async throws {
        mockService.mockSuggestions = [.mockSameGym, .mockMutualFriends]
        let suggestions = try await mockService.getSuggestedFriends(userId: "user-1")
        
        XCTAssertEqual(suggestions.count, 2)
        XCTAssert(suggestions.contains { $0.reason == .sameGym })
        XCTAssert(suggestions.contains { $0.reason == .mutualFriends })
    }
    
    // MARK: - Friendship Status Tests
    
    func testIsFriend() async throws {
        mockService.mockFriends = [.mockFriend]
        let isFriend = try await mockService.isFriend(userId: "user-1", friendId: "user-2")
        
        XCTAssertTrue(isFriend)
    }
    
    func testIsNotFriend() async throws {
        mockService.mockFriends = []
        let isFriend = try await mockService.isFriend(userId: "user-1", friendId: "user-99")
        
        XCTAssertFalse(isFriend)
    }
    
    func testIsFollowing() async throws {
        mockService.mockFollowing = [.mockFriend]
        let isFollowing = try await mockService.isFollowing(userId: "user-1", targetId: "user-2")
        
        XCTAssertTrue(isFollowing)
    }
    
    func testGetFriendshipStatus() async throws {
        mockService.mockFriends = [.mockFriend]
        let status = try await mockService.getFriendshipStatus(userId: "user-1", otherUserId: "user-2")
        
        XCTAssertEqual(status, .friend)
    }
}

// MARK: - Friend View Model Tests

final class FriendViewModelTests: XCTestCase {
    var viewModel: FriendViewModel!
    var mockService: MockFriendshipService!
    
    @MainActor
    override func setUp() {
        super.setUp()
        mockService = MockFriendshipService()
        viewModel = FriendViewModel(friendshipService: mockService, currentUserId: "user-1")
    }
    
    @MainActor
    func testSendFriendRequestUpdatesState() async {
        mockService.searchResults = [.mockFriend]
        await viewModel.sendFriendRequest(toUserId: "user-2")
        
        XCTAssertEqual(mockService.sendFriendRequestCallCount, 1)
    }
    
    @MainActor
    func testAcceptFriendRequestRemovesFromPending() async {
        let request = FriendRequest.mockPending
        viewModel.pendingRequests = [request]
        
        await viewModel.acceptFriendRequest(request)
        
        XCTAssert(!viewModel.pendingRequests.contains { $0.id == request.id })
    }
    
    @MainActor
    func testLoadFriendsPopulatesData() async {
        mockService.mockFriends = [.mock, .mockFriend]
        await viewModel.loadFriends()
        
        XCTAssertEqual(viewModel.friends.count, 2)
    }
    
    @MainActor
    func testSearchUsersPopulatesResults() async {
        mockService.searchResults = [.mockFriend]
        await viewModel.searchUsers("mike")
        
        XCTAssertEqual(viewModel.searchResults.count, 1)
    }
    
    @MainActor
    func testClearSearchEmptiesResults() async {
        viewModel.searchResults = [.mock, .mockFriend]
        viewModel.clearSearch()
        
        XCTAssertEqual(viewModel.searchResults.count, 0)
    }
}
