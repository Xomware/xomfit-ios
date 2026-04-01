import SwiftUI

struct ProfileFeedView: View {
    @Binding var feedItems: [SocialFeedItem]
    var userId: String = ""
    var currentUserId: String = ""

    var body: some View {
        if feedItems.isEmpty {
            emptyState
        } else {
            LazyVStack(spacing: Theme.paddingSmall) {
                ForEach(feedItems) { item in
                    NavigationLink {
                        FeedDetailView(item: item, userId: currentUserId)
                    } label: {
                        FeedItemCard(
                            item: item,
                            onLike: { /* Like handled at feed level */ },
                            onComment: { /* Comment handled at feed level */ },
                            onDelete: item.userId == currentUserId ? {
                                Task {
                                    feedItems.removeAll { $0.id == item.id }
                                    try? await FeedService.shared.deleteFeedItem(id: item.id)
                                }
                            } : nil,
                            onEdit: item.userId == currentUserId ? { newCaption in
                                Task {
                                    if let idx = feedItems.firstIndex(where: { $0.id == item.id }) {
                                        feedItems[idx].caption = newCaption
                                    }
                                    try? await FeedService.shared.updateCaption(feedItemId: item.id, caption: newCaption)
                                }
                            } : nil
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.paddingMedium)
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.paddingSmall) {
            Image(systemName: "text.page")
                .font(.system(size: 36))
                .foregroundStyle(Theme.textSecondary)
            Text("No posts yet")
                .font(Theme.fontBody)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No posts yet")
    }
}
