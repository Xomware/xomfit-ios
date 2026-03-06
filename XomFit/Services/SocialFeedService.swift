import Foundation

// MARK: - Social Feed Service Protocol

protocol SocialFeedServiceProtocol {
    /// Fetch paginated feed items for the current user's friends
    func fetchFeed(
        userId: String,
        filter: FeedFilter,
        page: Int,
        pageSize: Int
    ) async throws -> [SocialFeedItem]

    /// Toggle like on a feed item; returns updated like count
    func toggleLike(feedItemId: String, userId: String) async throws -> (isLiked: Bool, likeCount: Int)

    /// Add a comment to a feed item
    func addComment(feedItemId: String, userId: String, text: String) async throws -> FeedComment

    /// Delete a comment (only the author can delete)
    func deleteComment(commentId: String, userId: String) async throws

    /// Post a new activity to the feed
    func postActivity(_ item: SocialFeedItem) async throws -> SocialFeedItem

    /// Fetch comments for a feed item
    func fetchComments(feedItemId: String, page: Int, pageSize: Int) async throws -> [FeedComment]

    /// Report a feed item
    func reportItem(feedItemId: String, userId: String, reason: String) async throws

    /// Hide a feed item from the user's feed
    func hideItem(feedItemId: String, userId: String) async throws
}

// MARK: - Social Feed Service Errors

enum SocialFeedError: Error, LocalizedError {
    case feedLoadFailed
    case likeFailed
    case commentFailed
    case postFailed
    case unauthorized
    case notFound
    case networkError(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .feedLoadFailed:
            return "Unable to load feed. Please try again."
        case .likeFailed:
            return "Unable to update like. Please try again."
        case .commentFailed:
            return "Unable to post comment. Please try again."
        case .postFailed:
            return "Unable to share activity. Please try again."
        case .unauthorized:
            return "You don't have permission for this action."
        case .notFound:
            return "Content not found or has been removed."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Supabase-backed Implementation

class SocialFeedService: SocialFeedServiceProtocol {
    static let shared = SocialFeedService()

    private let friendshipService: FriendshipServiceProtocol

    init(friendshipService: FriendshipServiceProtocol = FriendshipService.shared) {
        self.friendshipService = friendshipService
    }

    func fetchFeed(
        userId: String,
        filter: FeedFilter,
        page: Int,
        pageSize: Int
    ) async throws -> [SocialFeedItem] {
        // In production, this queries Supabase:
        // SELECT fi.*, u.*, (SELECT count(*) FROM feed_likes WHERE feed_item_id = fi.id) as likes,
        //   EXISTS(SELECT 1 FROM feed_likes WHERE feed_item_id = fi.id AND user_id = $userId) as is_liked
        // FROM feed_items fi
        // JOIN users u ON fi.user_id = u.id
        // WHERE fi.user_id IN (SELECT friend_id FROM friendships WHERE user_id = $userId)
        // ORDER BY fi.created_at DESC
        // LIMIT $pageSize OFFSET $page * $pageSize

        do {
            let friends = try await friendshipService.fetchFriends(userId: userId)
            let friendIds = Set(friends.map { $0.id })

            var items = SocialFeedItem.mockFeed

            switch filter {
            case .friends:
                items = items.filter { friendIds.contains($0.userId) || $0.userId == userId }
            case .following:
                let following = try await friendshipService.fetchFollowing(userId: userId)
                let followingIds = Set(following.map { $0.id })
                items = items.filter { followingIds.contains($0.userId) || friendIds.contains($0.userId) }
            case .discover:
                // Show all public posts
                items = items.filter { $0.visibility == .everyone }
            }

            // Apply pagination
            let start = page * pageSize
            let end = min(start + pageSize, items.count)
            guard start < items.count else { return [] }

            return Array(items[start..<end])
                .sorted { $0.createdAt > $1.createdAt }
        } catch {
            throw SocialFeedError.networkError(underlying: error)
        }
    }

    func toggleLike(feedItemId: String, userId: String) async throws -> (isLiked: Bool, likeCount: Int) {
        // In production:
        // Check if like exists → DELETE or INSERT into feed_likes
        // Return updated count
        return (isLiked: true, likeCount: 13)
    }

    func addComment(feedItemId: String, userId: String, text: String) async throws -> FeedComment {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SocialFeedError.commentFailed
        }

        // In production: INSERT INTO feed_comments
        return FeedComment(
            id: UUID().uuidString,
            userId: userId,
            user: .mock,
            text: text,
            createdAt: Date()
        )
    }

    func deleteComment(commentId: String, userId: String) async throws {
        // In production: DELETE FROM feed_comments WHERE id = $commentId AND user_id = $userId
    }

    func postActivity(_ item: SocialFeedItem) async throws -> SocialFeedItem {
        // In production: INSERT INTO feed_items
        return item
    }

    func fetchComments(feedItemId: String, page: Int, pageSize: Int) async throws -> [FeedComment] {
        // In production: SELECT * FROM feed_comments WHERE feed_item_id = $feedItemId
        return []
    }

    func reportItem(feedItemId: String, userId: String, reason: String) async throws {
        // In production: INSERT INTO feed_reports
    }

    func hideItem(feedItemId: String, userId: String) async throws {
        // In production: INSERT INTO feed_hidden_items
    }
}
