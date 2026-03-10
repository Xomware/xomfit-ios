import Foundation

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
    @Published var errorMessage: String?
    
    private var allPosts: [FeedPost] = []
    
    init() {
        loadFeed()
    }
    
    func loadFeed() {
        isLoading = true
        // Mock data for now - in production this would fetch from API
        allPosts = generateMockFeed()
        applyFilter()
        isLoading = false
    }
    
    func applyFilter() {
        switch selectedFilter {
        case .friends:
            // Show only posts from direct friends
            posts = allPosts.filter { $0.user.id != "user-1" }
        case .following:
            // Show posts from all followed accounts
            posts = allPosts.filter { $0.user.id != "user-1" }
        case .discover:
            // Show posts from recommended accounts
            posts = allPosts.filter { $0.user.id != "user-1" }
        }
        // Sort by most recent
        posts.sort { $0.createdAt > $1.createdAt }
    }
    
    func toggleLike(post: FeedPost) {
        guard let allPostIndex = allPosts.firstIndex(where: { $0.id == post.id }) else { return }
        allPosts[allPostIndex].isLiked.toggle()
        allPosts[allPostIndex].likes += allPosts[allPostIndex].isLiked ? 1 : -1
        applyFilter()
    }
    
    func addComment(to post: FeedPost, text: String, user: AppUser) {
        guard let index = allPosts.firstIndex(where: { $0.id == post.id }) else { return }
        let comment = FeedPost.Comment(
            id: UUID().uuidString,
            user: user,
            text: text,
            createdAt: Date()
        )
        allPosts[index].comments.append(comment)
        applyFilter()
    }
    
    func addReaction(to post: FeedPost, emoji: String) {
        guard let index = allPosts.firstIndex(where: { $0.id == post.id }) else { return }
        // In a real app, this would track reactions separately
        allPosts[index].likes += 1
        applyFilter()
    }
    
    func refresh() {
        loadFeed()
    }
    
    // MARK: - Mock Data Generation
    
    private func generateMockFeed() -> [FeedPost] {
        let friend1 = AppUser.mockFriend
        let friend2 = AppUser(
            id: "user-3",
            username: "sarahf",
            displayName: "Sarah F",
            avatarURL: nil,
            bio: "CrossFit enthusiast",
            stats: AppUser.UserStats(
                totalWorkouts: 156,
                totalVolume: 756_230,
                totalPRs: 28,
                currentStreak: 7,
                longestStreak: 45,
                favoriteExercise: "Clean & Jerk"
            ),
            isPrivate: false,
            createdAt: Date().addingTimeInterval(-86400 * 150)
        )
        
        return [
            // Friend's workout completion
            FeedPost(
                id: "fp-1",
                user: friend1,
                workout: .mockFriendWorkout,
                likes: 12,
                isLiked: false,
                comments: [
                    FeedPost.Comment(
                        id: "c-1",
                        user: .mock,
                        text: "Nice volume! 💪",
                        createdAt: Date().addingTimeInterval(-1800)
                    )
                ],
                createdAt: Date().addingTimeInterval(-3600)
            ),
            // Friend's PR
            FeedPost(
                id: "fp-2",
                user: friend1,
                workout: .mockFriendWorkout,
                likes: 24,
                isLiked: true,
                comments: [],
                createdAt: Date().addingTimeInterval(-7200)
            ),
            // Another friend's workout
            FeedPost(
                id: "fp-3",
                user: friend2,
                workout: .mock,
                likes: 8,
                isLiked: false,
                comments: [],
                createdAt: Date().addingTimeInterval(-10800)
            ),
        ]
    }
}
