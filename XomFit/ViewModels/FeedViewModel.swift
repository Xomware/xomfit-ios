import Foundation
import Supabase

enum FeedFilter: String, CaseIterable {
    case friends = "Friends"
    case following = "Following"
    case discover = "Discover"
}

@MainActor
class FeedViewModel: ObservableObject {
    @Published var posts: [FeedPost] = []
    @Published var isLoading = false
    @Published var selectedFilter: FeedFilter = .friends
    @Published var newCommentText: [String: String] = [:]
    @Published var selectedPostForComments: FeedPost?
    @Published var showingCommentSheet = false
    @Published var error: String?
    
    private let apiService = APIService.shared
    private let supabaseClient = supabase
    
    init() {
        loadFeed()
    }
    
    func loadFeed() {
        isLoading = true
        Task {
            do {
                switch selectedFilter {
                case .friends:
                    posts = try await apiService.fetchFeedByFilter(.friends)
                case .following:
                    posts = try await apiService.fetchFeedByFilter(.following)
                case .discover:
                    posts = try await apiService.fetchFeedByFilter(.discover)
                }
                isLoading = false
            } catch {
                self.error = error.localizedDescription
                // Fall back to mock data if API fails
                posts = FeedPost.mockFeed
                isLoading = false
            }
        }
    }
    
    // MARK: - Interaction Methods
    
    func toggleLike(post: FeedPost) {
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        posts[index].isLiked.toggle()
        posts[index].likes += posts[index].isLiked ? 1 : -1
        
        // Update in Supabase
        Task {
            try await updateLikeInSupabase(postId: post.id, liked: posts[index].isLiked)
        }
    }
    
    func addReaction(to post: FeedPost, emoji: String) {
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        
        // Update local state
        if !posts[index].reactions.contains(emoji) {
            posts[index].reactions.append(emoji)
        }
        posts[index].reactionCounts[emoji, default: 0] += 1
        
        // Update in Supabase
        Task {
            try await addReactionInSupabase(postId: post.id, emoji: emoji)
        }
    }
    
    func addComment(to post: FeedPost, text: String) {
        guard !text.isEmpty else { return }
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        
        let newComment = FeedPost.Comment(
            id: UUID().uuidString,
            user: User.mock, // TODO: Get current user from auth
            text: text,
            createdAt: Date()
        )
        
        posts[index].comments.append(newComment)
        newCommentText[post.id] = ""
        
        // Update in Supabase
        Task {
            try await addCommentInSupabase(postId: post.id, comment: newComment)
        }
    }
    
    func shareWorkout(_ workout: Workout, toFeed: Bool) {
        // Update workout to mark as shared to feed
        Task {
            do {
                try await supabaseClient
                    .from("workouts")
                    .update(["is_shared_to_feed": toFeed])
                    .eq("id", value: workout.id)
                    .execute()
                
                // Reload feed if share was successful
                if toFeed {
                    await MainActor.run {
                        self.loadFeed()
                    }
                }
            } catch {
                self.error = "Failed to share workout: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Supabase Updates
    
    private func updateLikeInSupabase(postId: String, liked: Bool) async throws {
        guard let userId = try await getCurrentUserId() else { return }
        
        if liked {
            try await supabaseClient
                .from("feed_likes")
                .insert(["post_id": postId, "user_id": userId])
                .execute()
        } else {
            try await supabaseClient
                .from("feed_likes")
                .delete()
                .eq("post_id", value: postId)
                .eq("user_id", value: userId)
                .execute()
        }
    }
    
    private func addReactionInSupabase(postId: String, emoji: String) async throws {
        guard let userId = try await getCurrentUserId() else { return }
        
        try await supabaseClient
            .from("feed_reactions")
            .insert(["post_id": postId, "user_id": userId, "emoji": emoji])
            .execute()
    }
    
    private func addCommentInSupabase(postId: String, comment: FeedPost.Comment) async throws {
        guard let userId = try await getCurrentUserId() else { return }
        
        try await supabaseClient
            .from("feed_comments")
            .insert([
                "post_id": postId,
                "user_id": userId,
                "text": comment.text,
                "created_at": ISO8601DateFormatter().string(from: comment.createdAt)
            ])
            .execute()
    }
    
    private func getCurrentUserId() async throws -> String? {
        guard let session = try await supabaseClient.auth.session else { return nil }
        return session.user.id.uuidString
    }
    
    func changeFilter(to filter: FeedFilter) {
        selectedFilter = filter
        loadFeed()
    }
    
    func refresh() {
        loadFeed()
    }
}
