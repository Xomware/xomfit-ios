import XCTest
@testable import XomFit

// MARK: - Mock Social Feed Service

class MockSocialFeedService: SocialFeedServiceProtocol {
    var mockFeedItems: [SocialFeedItem] = []
    var shouldThrowError = false
    var fetchFeedCallCount = 0
    var toggleLikeCallCount = 0
    var addCommentCallCount = 0
    var deleteCommentCallCount = 0
    var postActivityCallCount = 0
    var reportItemCallCount = 0
    var hideItemCallCount = 0
    var lastFetchFilter: FeedFilter?
    var lastFetchPage: Int?
    var hiddenItemIds: Set<String> = []
    var reportedItemIds: Set<String> = []

    func fetchFeed(
        userId: String,
        filter: FeedFilter,
        page: Int,
        pageSize: Int
    ) async throws -> [SocialFeedItem] {
        fetchFeedCallCount += 1
        lastFetchFilter = filter
        lastFetchPage = page
        if shouldThrowError { throw SocialFeedError.feedLoadFailed }

        let start = page * pageSize
        let end = min(start + pageSize, mockFeedItems.count)
        guard start < mockFeedItems.count else { return [] }
        return Array(mockFeedItems[start..<end])
    }

    func toggleLike(feedItemId: String, userId: String) async throws -> (isLiked: Bool, likeCount: Int) {
        toggleLikeCallCount += 1
        if shouldThrowError { throw SocialFeedError.likeFailed }
        return (isLiked: true, likeCount: 13)
    }

    func addComment(feedItemId: String, userId: String, text: String) async throws -> FeedComment {
        addCommentCallCount += 1
        if shouldThrowError { throw SocialFeedError.commentFailed }
        return FeedComment(
            id: UUID().uuidString,
            userId: userId,
            user: .mock,
            text: text,
            createdAt: Date()
        )
    }

    func deleteComment(commentId: String, userId: String) async throws {
        deleteCommentCallCount += 1
        if shouldThrowError { throw SocialFeedError.unauthorized }
    }

    func postActivity(_ item: SocialFeedItem) async throws -> SocialFeedItem {
        postActivityCallCount += 1
        if shouldThrowError { throw SocialFeedError.postFailed }
        mockFeedItems.insert(item, at: 0)
        return item
    }

    func fetchComments(feedItemId: String, page: Int, pageSize: Int) async throws -> [FeedComment] {
        return []
    }

    func reportItem(feedItemId: String, userId: String, reason: String) async throws {
        reportItemCallCount += 1
        if shouldThrowError { throw SocialFeedError.notFound }
        reportedItemIds.insert(feedItemId)
    }

    func hideItem(feedItemId: String, userId: String) async throws {
        hideItemCallCount += 1
        if shouldThrowError { throw SocialFeedError.notFound }
        hiddenItemIds.insert(feedItemId)
    }
}

// MARK: - SocialFeedItem Model Tests

final class SocialFeedItemTests: XCTestCase {

    func testWorkoutPostHasCorrectActivityType() {
        let item = SocialFeedItem.mockWorkoutPost
        XCTAssertEqual(item.activityType, .workout)
        XCTAssertNotNil(item.workoutActivity)
        XCTAssertNil(item.prActivity)
    }

    func testPRPostHasCorrectActivityType() {
        let item = SocialFeedItem.mockPRPost
        XCTAssertEqual(item.activityType, .personalRecord)
        XCTAssertNotNil(item.prActivity)
        XCTAssertNil(item.workoutActivity)
    }

    func testMilestonePostHasCorrectActivityType() {
        let item = SocialFeedItem.mockMilestonePost
        XCTAssertEqual(item.activityType, .milestone)
        XCTAssertNotNil(item.milestoneActivity)
    }

    func testStreakPostHasCorrectActivityType() {
        let item = SocialFeedItem.mockStreakPost
        XCTAssertEqual(item.activityType, .streak)
        XCTAssertNotNil(item.streakActivity)
    }

    func testMockFeedContainsAllTypes() {
        let feed = SocialFeedItem.mockFeed
        let types = Set(feed.map { $0.activityType })
        XCTAssertTrue(types.contains(.workout))
        XCTAssertTrue(types.contains(.personalRecord))
        XCTAssertTrue(types.contains(.milestone))
        XCTAssertTrue(types.contains(.streak))
    }

    func testFeedItemIdentifiable() {
        let items = SocialFeedItem.mockFeed
        let ids = items.map { $0.id }
        XCTAssertEqual(ids.count, Set(ids).count, "All feed items should have unique IDs")
    }

    func testWorkoutActivityExercises() {
        let item = SocialFeedItem.mockWorkoutPost
        guard let workout = item.workoutActivity else {
            XCTFail("Expected workout activity")
            return
        }
        XCTAssertGreaterThan(workout.exercises.count, 0)
        XCTAssertTrue(workout.exercises.contains { $0.isPR })
    }

    func testPRActivityImprovement() {
        let item = SocialFeedItem.mockPRPost
        guard let pr = item.prActivity else {
            XCTFail("Expected PR activity")
            return
        }
        XCTAssertNotNil(pr.improvement)
        XCTAssertGreaterThan(pr.improvement ?? 0, 0)
    }

    func testVisibilityTypes() {
        XCTAssertEqual(SocialFeedItem.mockWorkoutPost.visibility, .friends)
        XCTAssertEqual(SocialFeedItem.mockPRPost.visibility, .everyone)
    }
}

// MARK: - Activity Type Tests

final class ActivityTypeTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(ActivityType.allCases.count, 4)
    }

    func testRawValues() {
        XCTAssertEqual(ActivityType.workout.rawValue, "workout")
        XCTAssertEqual(ActivityType.personalRecord.rawValue, "personal_record")
        XCTAssertEqual(ActivityType.milestone.rawValue, "milestone")
        XCTAssertEqual(ActivityType.streak.rawValue, "streak")
    }
}

// MARK: - SocialFeedViewModel Tests

final class SocialFeedViewModelTests: XCTestCase {
    var viewModel: SocialFeedViewModel!
    var mockService: MockSocialFeedService!

    @MainActor
    override func setUp() {
        super.setUp()
        mockService = MockSocialFeedService()
        mockService.mockFeedItems = SocialFeedItem.mockFeed
        viewModel = SocialFeedViewModel(feedService: mockService, currentUserId: "user-1")
    }

    // MARK: - Feed Loading

    @MainActor
    func testLoadFeedPopulatesItems() async {
        await viewModel.loadFeed()
        XCTAssertEqual(viewModel.feedItems.count, SocialFeedItem.mockFeed.count)
        XCTAssertEqual(mockService.fetchFeedCallCount, 1)
    }

    @MainActor
    func testLoadFeedSetsLoadingState() async {
        XCTAssertFalse(viewModel.isLoading)
        await viewModel.loadFeed()
        XCTAssertFalse(viewModel.isLoading) // Should be false after completing
    }

    @MainActor
    func testLoadFeedHandlesError() async {
        mockService.shouldThrowError = true
        await viewModel.loadFeed()
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.feedItems.isEmpty)
    }

    @MainActor
    func testLoadFeedClearsErrorOnSuccess() async {
        mockService.shouldThrowError = true
        await viewModel.loadFeed()
        XCTAssertNotNil(viewModel.errorMessage)

        mockService.shouldThrowError = false
        await viewModel.loadFeed()
        XCTAssertNil(viewModel.errorMessage)
    }

    @MainActor
    func testRefreshReloadsFeed() async {
        await viewModel.loadFeed()
        XCTAssertEqual(mockService.fetchFeedCallCount, 1)
        await viewModel.refresh()
        XCTAssertEqual(mockService.fetchFeedCallCount, 2)
    }

    // MARK: - Filter

    @MainActor
    func testChangeFilterUpdatesAndReloads() async {
        await viewModel.changeFilter(to: .discover)
        XCTAssertEqual(viewModel.selectedFilter, .discover)
        XCTAssertEqual(mockService.lastFetchFilter, .discover)
    }

    @MainActor
    func testDefaultFilterIsFriends() {
        XCTAssertEqual(viewModel.selectedFilter, .friends)
    }

    // MARK: - Pagination

    @MainActor
    func testLoadMoreAppendsItems() async {
        // Set up 25 items, page size is 20
        var items: [SocialFeedItem] = []
        for idx in 0..<25 {
            var item = SocialFeedItem.mockWorkoutPost
            // Create unique items by using a mutable copy pattern
            items.append(SocialFeedItem(
                id: "sfi-page-\(idx)",
                userId: item.userId,
                activityType: item.activityType,
                createdAt: item.createdAt.addingTimeInterval(Double(-idx * 60)),
                user: item.user,
                likes: item.likes,
                isLiked: item.isLiked,
                comments: item.comments,
                workoutActivity: item.workoutActivity,
                caption: item.caption,
                visibility: item.visibility
            ))
        }
        mockService.mockFeedItems = items

        await viewModel.loadFeed()
        XCTAssertEqual(viewModel.feedItems.count, 20)
        XCTAssertTrue(viewModel.hasMorePages)

        // Trigger load more with last item
        if let lastItem = viewModel.feedItems.last {
            await viewModel.loadMoreIfNeeded(currentItem: lastItem)
        }
        XCTAssertEqual(viewModel.feedItems.count, 25)
    }

    @MainActor
    func testLoadMoreDoesNothingWhenNotLastItem() async {
        await viewModel.loadFeed()
        let firstItem = viewModel.feedItems[0]
        await viewModel.loadMoreIfNeeded(currentItem: firstItem)
        // Should only have called fetch once (the initial load)
        XCTAssertEqual(mockService.fetchFeedCallCount, 1)
    }

    // MARK: - Like

    @MainActor
    func testToggleLikeUpdatesItem() async {
        await viewModel.loadFeed()
        guard let item = viewModel.feedItems.first else {
            XCTFail("No items")
            return
        }
        let originalLiked = item.isLiked

        await viewModel.toggleLike(item: item)

        XCTAssertEqual(mockService.toggleLikeCallCount, 1)
        // After server response, isLiked should be true (mock returns true)
        XCTAssertTrue(viewModel.feedItems[0].isLiked)
    }

    @MainActor
    func testToggleLikeRevertsOnError() async {
        await viewModel.loadFeed()
        guard let item = viewModel.feedItems.first else {
            XCTFail("No items")
            return
        }
        let originalLikes = item.likes
        let originalLiked = item.isLiked

        mockService.shouldThrowError = true
        await viewModel.toggleLike(item: item)

        // Should revert to original state
        XCTAssertEqual(viewModel.feedItems[0].isLiked, originalLiked)
        XCTAssertEqual(viewModel.feedItems[0].likes, originalLikes)
    }

    // MARK: - Comments

    @MainActor
    func testAddCommentAppendsToItem() async {
        await viewModel.loadFeed()
        guard let item = viewModel.feedItems.first else {
            XCTFail("No items")
            return
        }
        let originalCount = item.comments.count

        await viewModel.addComment(to: item, text: "Great workout!")
        XCTAssertEqual(viewModel.feedItems[0].comments.count, originalCount + 1)
        XCTAssertEqual(mockService.addCommentCallCount, 1)
    }

    @MainActor
    func testAddCommentHandlesError() async {
        await viewModel.loadFeed()
        guard let item = viewModel.feedItems.first else {
            XCTFail("No items")
            return
        }
        let originalCount = item.comments.count

        mockService.shouldThrowError = true
        await viewModel.addComment(to: item, text: "Test")

        XCTAssertEqual(viewModel.feedItems[0].comments.count, originalCount)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    @MainActor
    func testDeleteCommentRemovesFromItem() async {
        await viewModel.loadFeed()
        guard let item = viewModel.feedItems.first,
              let comment = item.comments.first else {
            XCTFail("No items or comments")
            return
        }

        await viewModel.deleteComment(commentId: comment.id, from: item)
        XCTAssertFalse(viewModel.feedItems[0].comments.contains { $0.id == comment.id })
    }

    // MARK: - Report & Hide

    @MainActor
    func testReportItemCallsService() async {
        await viewModel.loadFeed()
        guard let item = viewModel.feedItems.first else {
            XCTFail("No items")
            return
        }

        await viewModel.reportItem(item, reason: "Spam")
        XCTAssertEqual(mockService.reportItemCallCount, 1)
    }

    @MainActor
    func testHideItemRemovesFromFeed() async {
        await viewModel.loadFeed()
        let originalCount = viewModel.feedItems.count
        guard let item = viewModel.feedItems.first else {
            XCTFail("No items")
            return
        }

        await viewModel.hideItem(item)
        XCTAssertEqual(viewModel.feedItems.count, originalCount - 1)
        XCTAssertFalse(viewModel.feedItems.contains { $0.id == item.id })
    }

    @MainActor
    func testHideItemHandlesError() async {
        await viewModel.loadFeed()
        let originalCount = viewModel.feedItems.count
        guard let item = viewModel.feedItems.first else {
            XCTFail("No items")
            return
        }

        mockService.shouldThrowError = true
        await viewModel.hideItem(item)
        // Item should still be there on error
        XCTAssertEqual(viewModel.feedItems.count, originalCount)
    }

    // MARK: - Computed Properties

    @MainActor
    func testWorkoutPostsFilter() async {
        await viewModel.loadFeed()
        let workoutPosts = viewModel.workoutPosts
        XCTAssertTrue(workoutPosts.allSatisfy { $0.activityType == .workout })
    }

    @MainActor
    func testPRPostsFilter() async {
        await viewModel.loadFeed()
        let prPosts = viewModel.prPosts
        XCTAssertTrue(prPosts.allSatisfy { $0.activityType == .personalRecord })
    }

    @MainActor
    func testMilestonePostsFilter() async {
        await viewModel.loadFeed()
        let milestonePosts = viewModel.milestonePosts
        XCTAssertTrue(milestonePosts.allSatisfy { $0.activityType == .milestone })
    }
}

// MARK: - SocialFeedService Tests

final class SocialFeedServiceTests: XCTestCase {

    func testServiceUsesCorrectFilter() async {
        let mockService = MockSocialFeedService()
        mockService.mockFeedItems = SocialFeedItem.mockFeed

        _ = try? await mockService.fetchFeed(userId: "user-1", filter: .discover, page: 0, pageSize: 20)
        XCTAssertEqual(mockService.lastFetchFilter, .discover)
    }

    func testServicePagination() async {
        let mockService = MockSocialFeedService()
        mockService.mockFeedItems = SocialFeedItem.mockFeed

        let page0 = try? await mockService.fetchFeed(userId: "user-1", filter: .friends, page: 0, pageSize: 2)
        XCTAssertEqual(page0?.count, 2)

        let page1 = try? await mockService.fetchFeed(userId: "user-1", filter: .friends, page: 1, pageSize: 2)
        XCTAssertEqual(page1?.count, 2)

        let page2 = try? await mockService.fetchFeed(userId: "user-1", filter: .friends, page: 2, pageSize: 2)
        XCTAssertEqual(page2?.count, 0)
    }

    func testToggleLikeReturnsResult() async throws {
        let mockService = MockSocialFeedService()
        let result = try await mockService.toggleLike(feedItemId: "sfi-1", userId: "user-1")
        XCTAssertTrue(result.isLiked)
        XCTAssertEqual(result.likeCount, 13)
    }

    func testAddCommentReturnsComment() async throws {
        let mockService = MockSocialFeedService()
        let comment = try await mockService.addComment(feedItemId: "sfi-1", userId: "user-1", text: "Nice!")
        XCTAssertEqual(comment.text, "Nice!")
        XCTAssertEqual(comment.userId, "user-1")
    }

    func testPostActivityAddsToFeed() async throws {
        let mockService = MockSocialFeedService()
        let item = SocialFeedItem.mockWorkoutPost
        _ = try await mockService.postActivity(item)
        XCTAssertEqual(mockService.postActivityCallCount, 1)
        XCTAssertTrue(mockService.mockFeedItems.contains { $0.id == item.id })
    }

    func testReportItemTracksReport() async throws {
        let mockService = MockSocialFeedService()
        try await mockService.reportItem(feedItemId: "sfi-1", userId: "user-1", reason: "Spam")
        XCTAssertTrue(mockService.reportedItemIds.contains("sfi-1"))
    }

    func testHideItemTracksHidden() async throws {
        let mockService = MockSocialFeedService()
        try await mockService.hideItem(feedItemId: "sfi-1", userId: "user-1")
        XCTAssertTrue(mockService.hiddenItemIds.contains("sfi-1"))
    }
}

// MARK: - SocialFeedError Tests

final class SocialFeedErrorTests: XCTestCase {

    func testErrorDescriptions() {
        XCTAssertNotNil(SocialFeedError.feedLoadFailed.errorDescription)
        XCTAssertNotNil(SocialFeedError.likeFailed.errorDescription)
        XCTAssertNotNil(SocialFeedError.commentFailed.errorDescription)
        XCTAssertNotNil(SocialFeedError.postFailed.errorDescription)
        XCTAssertNotNil(SocialFeedError.unauthorized.errorDescription)
        XCTAssertNotNil(SocialFeedError.notFound.errorDescription)
    }

    func testNetworkErrorWrapsUnderlying() {
        let underlying = NSError(domain: "test", code: 500)
        let error = SocialFeedError.networkError(underlying: underlying)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("Network error") ?? false)
    }
}

// MARK: - FeedComment Tests

final class FeedCommentTests: XCTestCase {

    func testCommentCreation() {
        let comment = FeedComment(
            id: "test-1",
            userId: "user-1",
            user: .mock,
            text: "Great workout!",
            createdAt: Date()
        )
        XCTAssertEqual(comment.id, "test-1")
        XCTAssertEqual(comment.text, "Great workout!")
        XCTAssertNotNil(comment.user)
    }

    func testCommentWithoutUser() {
        let comment = FeedComment(
            id: "test-2",
            userId: "user-1",
            user: nil,
            text: "Nice!",
            createdAt: Date()
        )
        XCTAssertNil(comment.user)
    }
}

// MARK: - WorkoutActivity Tests

final class WorkoutActivityTests: XCTestCase {

    func testExerciseSummaryIdentifiable() {
        let summary = WorkoutActivity.ExerciseSummary(
            id: "es-1",
            name: "Bench Press",
            bestWeight: 225,
            bestReps: 5,
            isPR: true
        )
        XCTAssertEqual(summary.id, "es-1")
        XCTAssertTrue(summary.isPR)
    }
}

// MARK: - MilestoneActivity Tests

final class MilestoneActivityTests: XCTestCase {

    func testMilestoneTypes() {
        XCTAssertEqual(MilestoneActivity.MilestoneType.workoutCount.rawValue, "workoutCount")
        XCTAssertEqual(MilestoneActivity.MilestoneType.volumeTotal.rawValue, "volumeTotal")
        XCTAssertEqual(MilestoneActivity.MilestoneType.prCount.rawValue, "prCount")
        XCTAssertEqual(MilestoneActivity.MilestoneType.streakRecord.rawValue, "streakRecord")
        XCTAssertEqual(MilestoneActivity.MilestoneType.custom.rawValue, "custom")
    }
}

// MARK: - StreakActivity Tests

final class StreakActivityTests: XCTestCase {

    func testStreakNewRecord() {
        let streak = StreakActivity(currentStreak: 14, previousBest: 10, isNewRecord: true)
        XCTAssertTrue(streak.isNewRecord)
        XCTAssertGreaterThan(streak.currentStreak, streak.previousBest)
    }

    func testStreakNotNewRecord() {
        let streak = StreakActivity(currentStreak: 5, previousBest: 10, isNewRecord: false)
        XCTAssertFalse(streak.isNewRecord)
    }
}
