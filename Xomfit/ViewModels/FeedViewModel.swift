import Foundation

@MainActor
@Observable
final class FeedViewModel {
    var feedItems: [SocialFeedItem] = []
    var isLoading: Bool = false
    var isRefreshing: Bool = false
    var errorMessage: String? = nil
    /// #311: true while a filter change is being applied; FeedView renders a
    /// brief skeleton overlay so the list doesn't pop instantly.
    var isFiltering: Bool = false
    /// #311: distinguish a load-more failure from "truly exhausted". When set,
    /// FeedView shows a retry banner at the bottom of the list.
    var loadMoreError: String? = nil

    // Filters
    var dateRange: FeedDateRange = .all
    var selectedMuscleGroups: Set<MuscleGroup> = []

    var filteredFeedItems: [SocialFeedItem] {
        feedItems.filter { item in
            // Date filter
            if let start = dateRange.startDate, item.createdAt < start {
                return false
            }
            // Muscle group filter (only applies to workout posts)
            if !selectedMuscleGroups.isEmpty {
                guard let exercises = item.workoutActivity?.exercises else { return false }
                let itemGroups = exercises.flatMap { ex in
                    ExerciseDatabase.byName[ex.name]?.muscleGroups ?? []
                }
                if selectedMuscleGroups.isDisjoint(with: itemGroups) { return false }
            }
            return true
        }
    }

    var isFiltered: Bool { dateRange != .all || !selectedMuscleGroups.isEmpty }

    // Pagination state
    private let pageSize = 20
    private var offset = 0
    var hasMore = true

    // MARK: - Load Feed

    func loadFeed(userId: String) async {
        isLoading = true
        errorMessage = nil
        loadMoreError = nil
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

    /// #311: re-applies the current filters without re-fetching, but flips
    /// `isFiltering` for a short window so the list shows a skeleton rather
    /// than instantly snapping to a different result set. Pure UI flag.
    func applyFilterChange() async {
        isFiltering = true
        try? await Task.sleep(nanoseconds: 250_000_000) // 0.25s
        isFiltering = false
    }

    func loadMore(userId: String) async {
        guard hasMore, !isLoading else { return }
        loadMoreError = nil
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
            // #311: keep `hasMore` true so the user can retry, and surface
            // a retry banner at the bottom of the feed instead of silently
            // exhausting pagination.
            loadMoreError = error.localizedDescription
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

    // MARK: - Delete Feed Item

    func deleteFeedItem(id: String) async {
        feedItems.removeAll { $0.id == id }
        do {
            try await FeedService.shared.deleteFeedItem(id: id)
        } catch {
            // Item already removed from local state; non-fatal
        }
    }

    // MARK: - Update Caption

    func updateCaption(feedItemId: String, caption: String) async {
        if let index = feedItems.firstIndex(where: { $0.id == feedItemId }) {
            feedItems[index].caption = caption
        }
        do {
            try await FeedService.shared.updateCaption(feedItemId: feedItemId, caption: caption)
        } catch {
            // Optimistic update already applied; non-fatal
        }
    }

    // MARK: - Load Comments

    func loadComments(for feedItemId: String) async throws -> [FeedComment] {
        try await FeedService.shared.fetchComments(feedItemId: feedItemId)
    }
}
