import SwiftUI

struct ProfileFeedView: View {
    @Binding var feedItems: [SocialFeedItem]
    var userId: String = ""
    var currentUserId: String = ""

    var body: some View {
        if feedItems.isEmpty {
            emptyState
        } else {
            LazyVStack(spacing: Theme.Spacing.sm) {
                ForEach(feedItems) { item in
                    NavigationLink {
                        FeedDetailView(item: item, userId: currentUserId)
                    } label: {
                        FeedItemCard(
                            item: item,
                            onLike: { /* Like handled at feed level */ },
                            onComment: { /* Comment handled at feed level */ },
                            onDelete: deleteAction(for: item),
                            onEdit: editAction(for: item)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
        }
    }

    private func deleteAction(for item: SocialFeedItem) -> (() -> Void)? {
        guard item.userId == currentUserId else { return nil }
        return {
            feedItems.removeAll { $0.id == item.id }
            Task { try? await FeedService.shared.deleteFeedItem(id: item.id) }
        }
    }

    private func editAction(for item: SocialFeedItem) -> ((String) -> Void)? {
        guard item.userId == currentUserId else { return nil }
        return { newCaption in
            if let idx = feedItems.firstIndex(where: { $0.id == item.id }) {
                feedItems[idx].caption = newCaption
            }
            Task { try? await FeedService.shared.updateCaption(feedItemId: item.id, caption: newCaption) }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "text.page")
                .font(.largeTitle)
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
