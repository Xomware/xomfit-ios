import Foundation

@MainActor
class FeedViewModel: ObservableObject {
    @Published var posts: [FeedPost] = []
    @Published var isLoading = false
    
    init() {
        loadFeed()
    }
    
    func loadFeed() {
        isLoading = true
        // Mock data for now
        posts = FeedPost.mockFeed
        isLoading = false
    }
    
    func toggleLike(post: FeedPost) {
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        posts[index].isLiked.toggle()
        posts[index].likes += posts[index].isLiked ? 1 : -1
    }
    
    func refresh() {
        loadFeed()
    }
}
