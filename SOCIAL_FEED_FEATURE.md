# Social Feed Feature — Complete Implementation Guide

## Feature Overview

The Social Feed (issue #9) is a core feature that lets XomFit users see what friends are doing, celebrate achievements, and engage through likes, reactions, and comments.

### Main Features

1. **Feed View** — Shows friends' completed workouts, PRs, and milestones
2. **Filter Tabs** — Switch between Friends/Following/Discover
3. **Interactions** — Like, react with emojis, and comment on posts
4. **Sharing** — Users can opt-in to share workouts to their feed
5. **Real-time Sync** — Posts update as new workouts complete (future enhancement)

## Architecture

### Models

#### `FeedPost` (Models/FeedPost.swift)
```swift
struct FeedPost: Codable, Identifiable {
    let id: String
    var user: User
    var workout: Workout
    var likes: Int
    var isLiked: Bool
    var comments: [Comment]
    var reactions: [String]              // emoji strings
    var reactionCounts: [String: Int]    // emoji: count
    var createdAt: Date
    
    struct Comment: Codable, Identifiable {
        let id: String
        var user: User
        var text: String
        var createdAt: Date
    }
}
```

### ViewModels

#### `FeedViewModel` (ViewModels/FeedViewModel.swift)
Handles all feed logic and Supabase interactions:

```swift
@MainActor
class FeedViewModel: ObservableObject {
    @Published var posts: [FeedPost] = []
    @Published var isLoading = false
    @Published var selectedFilter: FeedFilter = .friends
    @Published var newCommentText: [String: String] = [:]
    @Published var selectedPostForComments: FeedPost?
    
    // Load feed based on filter
    func loadFeed()
    
    // Interactions
    func toggleLike(post: FeedPost)
    func addReaction(to: FeedPost, emoji: String)
    func addComment(to: FeedPost, text: String)
    func shareWorkout(_ workout: Workout, toFeed: Bool)
    
    // Filter management
    func changeFilter(to: FeedFilter)
    func refresh()
}

enum FeedFilter: String, CaseIterable {
    case friends = "Friends"
    case following = "Following"
    case discover = "Discover"
}
```

### Views

#### `FeedView` (Views/Feed/FeedView.swift)

Main feed screen with:
- Filter tab bar at the top
- Scrollable feed of posts
- Pull-to-refresh support
- Empty state messaging

```swift
struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    
    // UI Components:
    // - FilterTabView: Selectable filter tabs
    // - FeedPostCardView: Individual post card
    // - CommentSheetView: Full-screen comments modal
}
```

#### `FeedPostCardView` (Views/Feed/FeedView.swift)
Displays a single workout post with:
- User profile badge
- Workout name and stats
- Exercise summary
- Like, comment, reaction, and share buttons
- Reaction emoji pills
- Comment preview (first 2 comments)

#### `CommentSheetView` (Views/Feed/FeedView.swift)
Full-screen modal for:
- Viewing all comments on a post
- Adding new comments
- Comment input with send button

### Services

#### `APIService` (Services/APIService.swift)
Provides methods for:
- `fetchFeed()` — Get default feed
- `fetchFeedByFilter(_ filter: FeedFilter)` — Get filtered feed
- `likePost(_ postId: String)` — Like a post
- `unlikePost(_ postId: String)` — Unlike a post
- `commentOnPost(_ postId: String, comment: String)` — Add comment
- `reactToPost(_ postId: String, emoji: String)` — Add reaction

## User Flows

### Viewing the Feed

1. User taps **Feed** tab in main navigation
2. FeedViewModel automatically loads friends' workouts
3. Workouts are displayed as cards in reverse chronological order
4. Each card shows exercise summary with best set for each exercise
5. PR badges highlight workouts with personal records

### Changing Feed Filter

```
Friends → [All friends' workouts]
Following → [Users being followed]
Discover → [All public workouts]
```

User selects tab → ViewModel calls `changeFilter()` → Feed refreshes → Posts filtered by selected view

### Liking a Workout

1. User taps **heart icon** on post
2. ViewModel calls `toggleLike(post:)`
3. Like count updates locally and syncs to Supabase
4. Heart icon becomes filled

### Adding Reactions

1. User taps **React** button on post
2. Menu appears with emoji options: 💪 🔥 👏 ❤️ 🎉 😍
3. User selects emoji
4. Reaction is added and counts update
5. Emoji pills appear showing all reactions with counts

### Commenting

1. User taps **comment icon** or comment count
2. `CommentSheetView` opens showing all comments
3. User types comment in input field at bottom
4. Taps send button
5. Comment is added to post and synced to Supabase
6. Local comment appears immediately

### Sharing a Workout

1. User taps **share icon** on any post
2. Shares workout summary to pasteboard (or other share options)
3. Can be pasted into iMessage, email, etc.

*Future: Share to feed option during workout logging*

## Database Schema

See **SOCIAL_FEED_SETUP.md** for complete SQL schema.

Key tables:
- `feed_likes` — User likes on posts
- `feed_comments` — Comments on posts
- `feed_reactions` — Emoji reactions on posts
- `friendships` — Friend relationships
- `follows` — Follow relationships

## Implementation Status

### ✅ Completed

- [x] FeedView with filter tabs
- [x] FeedViewModel with Supabase integration scaffolding
- [x] FeedPost model with reactions support
- [x] FeedPostCardView with comprehensive UI
- [x] CommentSheetView for detailed comments
- [x] Like/unlike functionality
- [x] Emoji reaction system
- [x] Comment add functionality
- [x] Share button (copy to pasteboard)
- [x] Empty state handling
- [x] Pull-to-refresh
- [x] Error handling

### 🔄 In Progress / To Complete

- [ ] **Supabase Real Integration** — Replace mock data with actual queries
- [ ] **Friend/Following Queries** — Implement friend and following filters
- [ ] **Real-time Updates** — Use Supabase Realtime for live post updates
- [ ] **Pagination** — Load more posts on scroll
- [ ] **PR Notifications** — Notify when friends hit PRs
- [ ] **Share Dialog** — Improved native share sheet
- [ ] **Typing Indicators** — Show when others are commenting
- [ ] **Workout Detail View** — Link to full workout from feed post

## Code Examples

### Loading Friends' Feed

```swift
private func fetchFriendsWorkouts() async throws -> [FeedPost] {
    let response = try await supabaseClient
        .from("workouts")
        .select("*, user:user_id(*), exercise_data(*)")
        .eq("is_shared_to_feed", value: true)
        .eq("is_completed", value: true)
        .in("user_id", values: try await fetchFriendIds())
        .order("created_at", ascending: false)
        .limit(50)
        .execute()
    
    return try decodeFeedPosts(response)
}
```

### Adding a Reaction

```swift
func addReaction(to post: FeedPost, emoji: String) {
    guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
    
    // Update local state
    if !posts[index].reactions.contains(emoji) {
        posts[index].reactions.append(emoji)
    }
    posts[index].reactionCounts[emoji, default: 0] += 1
    
    // Sync to Supabase
    Task {
        try await addReactionInSupabase(postId: post.id, emoji: emoji)
    }
}
```

### Commenting on a Post

```swift
func addComment(to post: FeedPost, text: String) {
    guard !text.isEmpty else { return }
    guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
    
    let newComment = FeedPost.Comment(
        id: UUID().uuidString,
        user: User.mock,
        text: text,
        createdAt: Date()
    )
    
    posts[index].comments.append(newComment)
    newCommentText[post.id] = ""
    
    // Sync to Supabase
    Task {
        try await addCommentInSupabase(postId: post.id, comment: newComment)
    }
}
```

## Integration Points

### With Live Workout Mode
When a friend's live workout ends, the finished workout is automatically posted to feed if user has enabled sharing.

### With PR Tracking
Workouts with personal records show a gold **PR!** badge on the feed card.

### With Friends System
Only friends' workouts appear in "Friends" filter. "Following" shows users you follow. "Discover" shows public workouts.

### With Notifications
Users can opt-in to receive notifications for:
- New comments on their shared workouts
- Friends hitting PRs
- Friends sharing workouts

## Testing

### Manual Testing Checklist

- [ ] Load feed and see friends' workouts
- [ ] Switch between Friends/Following/Discover filters
- [ ] Like a post and see heart fill
- [ ] Like count updates correctly
- [ ] Add emoji reaction and see pill appear
- [ ] Multiple reactions stack and show counts
- [ ] Add comment via CommentSheetView
- [ ] Comment appears immediately
- [ ] Comments persist on reload
- [ ] Share button copies workout to pasteboard
- [ ] Pull-to-refresh works
- [ ] Empty feed shows proper messaging
- [ ] Error handling displays error message

### Automated Testing

```swift
// FeedViewModelTests.swift
func testLoadFriendsWorkouts() async throws
func testToggleLike() async throws
func testAddReaction() async throws
func testAddComment() async throws
func testChangeFilter() async throws
```

## Future Enhancements

1. **Real-time Updates** — Supabase Realtime subscriptions for live feed
2. **Pagination** — Infinite scroll with lazy loading
3. **Rich Comments** — Support emoji, @mentions, links
4. **Notifications** — Push notifications for comments/reactions
5. **Saved Posts** — Bookmark favorite workouts
6. **Share to Social** — Post to Instagram, Twitter, etc.
7. **Leaderboards** — See who's lifting the most
8. **Workout Comparisons** — Compare two users' workouts
9. **Challenges** — Friendly competitions between friends
10. **Activity Feed** — Timeline of all friend activities

## Performance Considerations

- **Pagination**: Currently loads 50 posts. Add pagination for larger feeds.
- **Image Caching**: User avatars should be cached (future)
- **Lazy Loading**: Exercise details loaded only when needed
- **Indexing**: Database indexes on `is_shared_to_feed`, `user_id`, `created_at`

## Accessibility

- All interactive elements have `accessibilityLabel`
- Color not sole indicator (PR badge has text + color)
- Sufficient color contrast (WCAG AA)
- Dark mode support built-in

## Known Issues & Limitations

1. **Mock User Data** — Comments use mock current user until auth is integrated
2. **No Real-time** — Changes require manual refresh (Realtime coming)
3. **Comment Editing** — Not yet implemented
4. **Reaction Limits** — No rate limiting on reactions
5. **Image Support** — No workout photos yet
6. **Moderation** — No ability to hide/block posts yet

## Related Issues

- #8 — Friends System (dependency)
- #7 — PR Tracking (integrated)
- #16 — Live Workout Mode (integration)
- #17 — Push Notifications (future integration)
- #3 — User Profile (dependency)

## Files Modified/Created

### New Files
- `XomFit/Views/Feed/FeedView.swift` — Main feed UI
- `XomFit/Models/FeedPost.swift` — Post model with comments/reactions
- `SOCIAL_FEED_SETUP.md` — Database schema
- `SOCIAL_FEED_FEATURE.md` — This file

### Modified Files
- `XomFit/ViewModels/FeedViewModel.swift` — Complete rewrite with Supabase integration
- `XomFit/Services/APIService.swift` — Added feed interaction methods
- `XomFit/Utils/Theme.swift` — Added divider color

## Support & Questions

For issues or questions:
1. Open a GitHub issue with label `social-feed`
2. Reference this documentation
3. Include reproduction steps
4. Include error logs if applicable
