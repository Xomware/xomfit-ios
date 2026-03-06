import Foundation

@MainActor
class SocialFeedViewModel: ObservableObject {
    @Published var feedItems: [SocialFeedItem] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var selectedFilter: FeedFilter = .friends
    @Published var errorMessage: String?
    @Published var hasMorePages = true

    private let feedService: SocialFeedServiceProtocol
    private let currentUserId: String
    private var currentPage = 0
    private let pageSize = 20

    init(
        feedService: SocialFeedServiceProtocol = SocialFeedService.shared,
        currentUserId: String = "current-user-id"
    ) {
        self.feedService = feedService
        self.currentUserId = currentUserId
    }

    // MARK: - Feed Loading

    func loadFeed() async {
        isLoading = true
        currentPage = 0
        errorMessage = nil

        do {
            let items = try await feedService.fetchFeed(
                userId: currentUserId,
                filter: selectedFilter,
                page: 0,
                pageSize: pageSize
            )
            feedItems = items
            hasMorePages = items.count >= pageSize
        } catch {
            errorMessage = (error as? SocialFeedError)?.errorDescription ?? error.localizedDescription
        }

        isLoading = false
    }

    func loadMoreIfNeeded(currentItem: SocialFeedItem) async {
        guard let lastItem = feedItems.last,
              lastItem.id == currentItem.id,
              hasMorePages,
              !isLoadingMore else { return }

        isLoadingMore = true
        currentPage += 1

        do {
            let items = try await feedService.fetchFeed(
                userId: currentUserId,
                filter: selectedFilter,
                page: currentPage,
                pageSize: pageSize
            )
            feedItems.append(contentsOf: items)
            hasMorePages = items.count >= pageSize
        } catch {
            currentPage -= 1
            errorMessage = (error as? SocialFeedError)?.errorDescription ?? error.localizedDescription
        }

        isLoadingMore = false
    }

    func refresh() async {
        await loadFeed()
    }

    func changeFilter(to filter: FeedFilter) async {
        selectedFilter = filter
        await loadFeed()
    }

    // MARK: - Interactions

    func toggleLike(item: SocialFeedItem) async {
        guard let index = feedItems.firstIndex(where: { $0.id == item.id }) else { return }

        // Optimistic update
        feedItems[index].isLiked.toggle()
        feedItems[index].likes += feedItems[index].isLiked ? 1 : -1

        do {
            let result = try await feedService.toggleLike(
                feedItemId: item.id,
                userId: currentUserId
            )
            feedItems[index].isLiked = result.isLiked
            feedItems[index].likes = result.likeCount
        } catch {
            // Revert on failure
            feedItems[index].isLiked.toggle()
            feedItems[index].likes += feedItems[index].isLiked ? 1 : -1
            errorMessage = (error as? SocialFeedError)?.errorDescription ?? "Like failed"
        }
    }

    func addComment(to item: SocialFeedItem, text: String) async {
        guard let index = feedItems.firstIndex(where: { $0.id == item.id }) else { return }

        do {
            let comment = try await feedService.addComment(
                feedItemId: item.id,
                userId: currentUserId,
                text: text
            )
            feedItems[index].comments.append(comment)
        } catch {
            errorMessage = (error as? SocialFeedError)?.errorDescription ?? "Comment failed"
        }
    }

    func deleteComment(commentId: String, from item: SocialFeedItem) async {
        guard let itemIndex = feedItems.firstIndex(where: { $0.id == item.id }) else { return }

        do {
            try await feedService.deleteComment(commentId: commentId, userId: currentUserId)
            feedItems[itemIndex].comments.removeAll { $0.id == commentId }
        } catch {
            errorMessage = (error as? SocialFeedError)?.errorDescription ?? "Delete failed"
        }
    }

    func reportItem(_ item: SocialFeedItem, reason: String) async {
        do {
            try await feedService.reportItem(
                feedItemId: item.id,
                userId: currentUserId,
                reason: reason
            )
        } catch {
            errorMessage = "Report failed. Please try again."
        }
    }

    func hideItem(_ item: SocialFeedItem) async {
        do {
            try await feedService.hideItem(feedItemId: item.id, userId: currentUserId)
            feedItems.removeAll { $0.id == item.id }
        } catch {
            errorMessage = "Unable to hide this post."
        }
    }

    // MARK: - Computed Properties

    var workoutPosts: [SocialFeedItem] {
        feedItems.filter { $0.activityType == .workout }
    }

    var prPosts: [SocialFeedItem] {
        feedItems.filter { $0.activityType == .personalRecord }
    }

    var milestonePosts: [SocialFeedItem] {
        feedItems.filter { $0.activityType == .milestone }
    }
}
