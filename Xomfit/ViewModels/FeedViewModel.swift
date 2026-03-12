import Foundation

@MainActor
@Observable
final class FeedViewModel {
    var feedItems: [SocialFeedItem] = []
    var isLoading: Bool = false
    var isRefreshing: Bool = false
    var errorMessage: String? = nil

    // Pagination state
    private let pageSize = 20
    private var offset = 0
    var hasMore = true

    // MARK: - Load Feed

    func loadFeed(userId: String) async {
        isLoading = true
        errorMessage = nil
        offset = 0
        hasMore = true

        do {
            let items = try await FeedService.shared.fetchFeed(
                userId: userId,
                limit: pageSize,
                offset: 0
            )
            feedItems = items
            offset = items.count
            hasMore = items.count == pageSize
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func refreshFeed(userId: String) async {
        isRefreshing = true
        await loadFeed(userId: userId)
        isRefreshing = false
    }

    func loadMore(userId: String) async {
        guard hasMore, !isLoading else { return }
        do {
            let items = try await FeedService.shared.fetchFeed(
                userId: userId,
                limit: pageSize,
                offset: offset
            )
            feedItems.append(contentsOf: items)
            offset += items.count
            hasMore = items.count == pageSize
        } catch {
            // Non-fatal — just stop paginating
            hasMore = false
        }
    }

    // MARK: - Like / Unlike

    func toggleLike(feedItem: SocialFeedItem, userId: String) async {
        guard let index = feedItems.firstIndex(where: { $0.id == feedItem.id }) else { return }
        let wasLiked = feedItems[index].isLiked

        // Optimistic update
        feedItems[index].isLiked = !wasLiked
        feedItems[index].likes += wasLiked ? -1 : 1

        do {
            if wasLiked {
                try await FeedService.shared.unlikeFeedItem(
                    feedItemId: feedItem.id,
                    userId: userId
                )
            } else {
                try await FeedService.shared.likeFeedItem(
                    feedItemId: feedItem.id,
                    userId: userId
                )
            }
        } catch {
            // Revert on failure
            feedItems[index].isLiked = wasLiked
            feedItems[index].likes += wasLiked ? 1 : -1
        }
    }

    // MARK: - Comment

    func postComment(feedItemId: String, userId: String, text: String) async throws {
        try await FeedService.shared.postComment(
            feedItemId: feedItemId,
            userId: userId,
            text: text
        )
        // Reload comments for that item
        if let index = feedItems.firstIndex(where: { $0.id == feedItemId }) {
            let updated = try await FeedService.shared.fetchComments(feedItemId: feedItemId)
            feedItems[index].comments = updated
        }
    }

    // MARK: - Load Comments

    func loadComments(for feedItemId: String) async throws -> [FeedComment] {
        try await FeedService.shared.fetchComments(feedItemId: feedItemId)
    }
}
