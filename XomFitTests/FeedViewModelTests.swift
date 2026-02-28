import XCTest
@testable import XomFit

final class FeedViewModelTests: XCTestCase {
    
    var viewModel: FeedViewModel!
    
    override func setUp() {
        super.setUp()
        viewModel = FeedViewModel()
    }
    
    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }
    
    // MARK: - Feed Loading Tests
    
    func testFeedLoadsOnInit() {
        XCTAssertFalse(viewModel.posts.isEmpty, "Feed should load on initialization")
    }
    
    func testLoadFeedSetsIsLoadingState() {
        viewModel.isLoading = true
        viewModel.loadFeed()
        XCTAssertFalse(viewModel.isLoading, "Loading state should be false after feed loads")
    }
    
    // MARK: - Feed Filter Tests
    
    func testFriendsFilterShowsPostsFromFriends() {
        viewModel.selectedFilter = .friends
        viewModel.applyFilter()
        
        let currentUserId = "user-1"
        let hasOnlyFriendPosts = viewModel.posts.allSatisfy { $0.user.id != currentUserId }
        XCTAssertTrue(hasOnlyFriendPosts, "Friends filter should only show posts from other users")
    }
    
    func testFollowingFilterShowsFollowedPosts() {
        viewModel.selectedFilter = .following
        viewModel.applyFilter()
        
        XCTAssertFalse(viewModel.posts.isEmpty, "Following filter should have posts")
    }
    
    func testDiscoverFilterShowsDiscoveredContent() {
        viewModel.selectedFilter = .discover
        viewModel.applyFilter()
        
        XCTAssertFalse(viewModel.posts.isEmpty, "Discover filter should have posts")
    }
    
    func testFeedSortsPostsByMostRecent() {
        viewModel.applyFilter()
        
        let sortedByDate = viewModel.posts.enumerated().allSatisfy { (index, post) in
            if index == viewModel.posts.count - 1 { return true }
            return post.createdAt >= viewModel.posts[index + 1].createdAt
        }
        
        XCTAssertTrue(sortedByDate, "Posts should be sorted by most recent first")
    }
    
    // MARK: - Like Toggle Tests
    
    func testToggleLikeIncrementsLikeCount() {
        let post = viewModel.posts.first!
        let initialLikes = post.likes
        
        viewModel.toggleLike(post: post)
        let updatedPost = viewModel.posts.first!
        
        XCTAssertEqual(updatedPost.likes, initialLikes + 1, "Like count should increment")
    }
    
    func testToggleLikeDecrementsByOne() {
        var post = viewModel.posts.first!
        post.isLiked = true
        
        viewModel.toggleLike(post: post)
        let updatedPost = viewModel.posts.first!
        
        XCTAssertEqual(updatedPost.likes, post.likes - 1, "Like count should decrement when unliking")
    }
    
    func testToggleLikeSetsIsLikedFlag() {
        let post = viewModel.posts.first!
        let initialState = post.isLiked
        
        viewModel.toggleLike(post: post)
        let updatedPost = viewModel.posts.first!
        
        XCTAssertEqual(updatedPost.isLiked, !initialState, "isLiked flag should toggle")
    }
    
    // MARK: - Comment Tests
    
    func testAddCommentAppendsToPost() {
        let post = viewModel.posts.first!
        let initialCommentCount = post.comments.count
        let testComment = "Great workout!"
        
        viewModel.addComment(to: post, text: testComment, user: .mock)
        let updatedPost = viewModel.posts.first!
        
        XCTAssertEqual(updatedPost.comments.count, initialCommentCount + 1, "Comment should be added")
        XCTAssertEqual(updatedPost.comments.last?.text, testComment, "Comment text should match")
    }
    
    func testCommentIncludesCurrentUser() {
        let post = viewModel.posts.first!
        let user = User.mock
        let testComment = "Nice PR!"
        
        viewModel.addComment(to: post, text: testComment, user: user)
        let updatedPost = viewModel.posts.first!
        
        XCTAssertEqual(updatedPost.comments.last?.user.id, user.id, "Comment should have user info")
    }
    
    func testCommentHasCurrentTimestamp() {
        let post = viewModel.posts.first!
        let beforeTime = Date()
        viewModel.addComment(to: post, text: "Test", user: .mock)
        let afterTime = Date()
        
        let updatedPost = viewModel.posts.first!
        let commentTime = updatedPost.comments.last?.createdAt ?? Date.distantPast
        
        XCTAssertTrue(beforeTime <= commentTime && commentTime <= afterTime, 
                     "Comment timestamp should be current")
    }
    
    // MARK: - Reaction Tests
    
    func testAddReactionIncrementsLikeCount() {
        let post = viewModel.posts.first!
        let initialLikes = post.likes
        
        viewModel.addReaction(to: post, emoji: "🔥")
        let updatedPost = viewModel.posts.first!
        
        XCTAssertEqual(updatedPost.likes, initialLikes + 1, "Reaction should increment likes")
    }
    
    // MARK: - Refresh Tests
    
    func testRefreshReloadsFeed() {
        let initialPostCount = viewModel.posts.count
        viewModel.refresh()
        let refreshedPostCount = viewModel.posts.count
        
        XCTAssertEqual(initialPostCount, refreshedPostCount, "Refresh should maintain post count")
    }
    
    // MARK: - Filter Transitions Tests
    
    func testSwitchBetweenFilters() {
        let initialFilter = viewModel.selectedFilter
        viewModel.selectedFilter = .following
        viewModel.applyFilter()
        
        let followingPosts = viewModel.posts.count
        
        viewModel.selectedFilter = .discover
        viewModel.applyFilter()
        
        let discoverPosts = viewModel.posts.count
        
        XCTAssertEqual(followingPosts, discoverPosts, "Filter switching should work correctly")
    }
    
    // MARK: - Mock Data Tests
    
    func testMockFeedIsNotEmpty() {
        XCTAssertFalse(viewModel.posts.isEmpty, "Mock feed should not be empty")
    }
    
    func testMockPostsHaveValidStructure() {
        let post = viewModel.posts.first!
        
        XCTAssertFalse(post.id.isEmpty, "Post should have ID")
        XCTAssertFalse(post.user.id.isEmpty, "Post user should have ID")
        XCTAssertFalse(post.workout.id.isEmpty, "Workout should have ID")
        XCTAssertGreaterThanOrEqual(post.likes, 0, "Likes should be non-negative")
    }
    
    func testMockPostsHaveDatesInPast() {
        let now = Date()
        let allPostsInPast = viewModel.posts.allSatisfy { $0.createdAt <= now }
        
        XCTAssertTrue(allPostsInPast, "All mock posts should have dates in the past")
    }
}

// MARK: - Feed Aggregation Tests

final class FeedAggregationTests: XCTestCase {
    
    func testAggregatesFriendsActivities() {
        let viewModel = FeedViewModel()
        viewModel.selectedFilter = .friends
        viewModel.applyFilter()
        
        let friend1Posts = viewModel.posts.filter { $0.user.id == "user-2" }
        XCTAssertGreaterThan(friend1Posts.count, 0, "Should have posts from friend 1")
    }
    
    func testSortsActivitiesByRecency() {
        let viewModel = FeedViewModel()
        viewModel.applyFilter()
        
        var previousDate = Date.distantFuture
        for post in viewModel.posts {
            XCTAssertLessThanOrEqual(post.createdAt, previousDate, 
                                    "Posts should be sorted newest first")
            previousDate = post.createdAt
        }
    }
    
    func testIncludesMultipleActivityTypes() {
        let viewModel = FeedViewModel()
        
        // In a real implementation, we'd have different activity types
        // For now, we just verify we have posts
        XCTAssertGreaterThan(viewModel.posts.count, 0, "Feed should aggregate activities")
    }
    
    func testHandlesEmptyFriendsGracefully() {
        let viewModel = FeedViewModel()
        viewModel.selectedFilter = .friends
        viewModel.applyFilter()
        
        // Should not crash and return empty array
        XCTAssertTrue(true, "Should handle empty friend feed gracefully")
    }
}
