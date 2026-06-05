import Foundation

@MainActor
@Observable
final class FeedViewModel {
    var feedItems: [SocialFeedItem] = []

    // MARK: - Profile Update Listener (#385)

    /// Patches cached feed items inline when the current user updates their avatar.
    /// Called from a `.task` in `FeedView` so it lives on the main actor.
    func subscribeToProfileUpdates() async {
        for await notification in NotificationCenter.default.notifications(named: .userProfileUpdated) {
            guard let avatarURL = notification.object as? String,
                  let userId = notification.userInfo?["userId"] as? String else { continue }
            print("[FeedViewModel] .userProfileUpdated received — userId=\(userId) url=\(avatarURL)")
            for index in feedItems.indices where feedItems[index].userId == userId {
                feedItems[index].user.avatarURL = avatarURL
                print("[FeedViewModel] patched feedItems[\(index)] avatarURL")
            }
        }
    }
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
    /// Minimum overall workout rating to show (0 = no filter). Only applies to
    /// workout posts — non-workout activity is filtered out when set.
    var minRating: Int = 0
    /// User ids to restrict the feed to (empty = all users).
    var selectedUserIds: Set<String> = []
    /// Sort order applied after filtering.
    var sortOption: FeedSortOption = .recent

    var filteredFeedItems: [SocialFeedItem] {
        let filtered = feedItems.filter { item in
            // Date filter
            if let start = dateRange.startDate, item.createdAt < start {
                return false
            }
            // User filter
            if !selectedUserIds.isEmpty, !selectedUserIds.contains(item.userId) {
                return false
            }
            // Minimum rating filter (only applies to workout posts)
            if minRating > 0 {
                guard let rating = item.workoutActivity?.rating, rating >= minRating else {
                    return false
                }
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
        return sortItems(filtered)
    }

    /// Applies `sortOption`. Posts without a rating sort as 0 so they sink to
    /// the bottom for "highest rated" and rise to the top for "lowest rated".
    private func sortItems(_ items: [SocialFeedItem]) -> [SocialFeedItem] {
        switch sortOption {
        case .recent:
            return items.sorted { $0.createdAt > $1.createdAt }
        case .highestRated:
            return items.sorted { ($0.workoutActivity?.rating ?? 0) > ($1.workoutActivity?.rating ?? 0) }
        case .lowestRated:
            return items.sorted { ($0.workoutActivity?.rating ?? 0) < ($1.workoutActivity?.rating ?? 0) }
        }
    }

    /// Distinct users present in the loaded feed, for the user filter chips.
    /// Keyed on `item.userId` so the chip identity matches the filter key.
    var availableUsers: [FeedUserOption] {
        var seen = Set<String>()
        var result: [FeedUserOption] = []
        for item in feedItems where !seen.contains(item.userId) {
            seen.insert(item.userId)
            let name = item.user.displayName.isEmpty ? item.user.username : item.user.displayName
            result.append(FeedUserOption(id: item.userId, name: name, avatarURL: item.user.avatarURL))
        }
        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// `sortOption` is intentionally excluded — sorting reorders but never
    /// reduces the result set, so it shouldn't trigger the "no matches" state.
    var isFiltered: Bool {
        dateRange != .all
            || !selectedMuscleGroups.isEmpty
            || !selectedUserIds.isEmpty
            || minRating > 0
    }

    // Pagination state
    private let pageSize = 20
    private var offset = 0
    var hasMore = true

    // MARK: - Load Feed

    /// Initial fetch (or full reload on error retry). Shows the full skeleton
    /// while the network is in flight by flipping `isLoading`. Replaces the
    /// existing feed wholesale on success. Use `refreshFeed` for pull-to-refresh
    /// — that variant keeps the prior items visible so the system spinner
    /// owns the loading affordance.
    func loadFeed(userId: String) async {
        // Only flip the loading skeleton when the feed is empty. Re-entering
        // this function after a prior successful load (e.g. tab switch) keeps
        // the existing rows on-screen while we refetch in the background so
        // the user never sees a flash of the skeleton (#410).
        let showSkeleton = feedItems.isEmpty
        if showSkeleton { isLoading = true }
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
        } catch is CancellationError {
            // A newer pull-to-refresh / view re-render replaced this task — leave
            // the existing feed in place rather than blowing it away with a
            // "cancelled" toast.
            isLoading = false
            return
        } catch let urlError as URLError where urlError.code == .cancelled {
            isLoading = false
            return
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Pull-to-refresh entry point. Re-fetches the first page without touching
    /// `isLoading` so the existing list stays mounted and the system pull
    /// spinner owns the loading UI. The await chain runs all the way through
    /// the network call so SwiftUI's `.refreshable` correctly dismisses its
    /// spinner only after the new data is applied. (#410)
    func refreshFeed(userId: String) async {
        // Don't trip `isLoading` — that swaps the list for the skeleton and
        // races with the system pull-to-refresh spinner.
        isRefreshing = true
        defer { isRefreshing = false }

        loadMoreError = nil

        do {
            let items = try await FeedService.shared.fetchFeed(
                userId: userId,
                limit: pageSize,
                offset: 0
            )
            feedItems = items
            offset = items.count
            hasMore = items.count == pageSize
            errorMessage = nil
        } catch is CancellationError {
            // A subsequent refresh replaced this one — leave the existing
            // list intact.
            return
        } catch let urlError as URLError where urlError.code == .cancelled {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
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
        } catch is CancellationError {
            return
        } catch let urlError as URLError where urlError.code == .cancelled {
            return
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
