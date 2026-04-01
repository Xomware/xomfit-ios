import SwiftUI

struct ProfileFeedView: View {
    let feedItems: [SocialFeedItem]
    var userId: String = ""

    var body: some View {
        if feedItems.isEmpty {
            emptyState
        } else {
            LazyVStack(spacing: Theme.paddingSmall) {
                ForEach(feedItems) { item in
                    NavigationLink {
                        FeedDetailView(item: item, userId: userId)
                    } label: {
                        FeedItemCard(
                            item: item,
                            onLike: { /* Like handled at feed level */ },
                            onComment: { /* Comment handled at feed level */ }
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
