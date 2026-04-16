import SwiftUI

struct ProfileFeedView: View {
    @Binding var feedItems: [SocialFeedItem]
    var filteredItems: [SocialFeedItem]
    var isFiltered: Bool
    @Binding var dateRange: FeedDateRange
    @Binding var muscleGroups: Set<MuscleGroup>
    var userId: String = ""
    var currentUserId: String = ""

    var body: some View {
        VStack(spacing: 0) {
            if !feedItems.isEmpty {
                FeedFilterBar(
                    selectedDateRange: $dateRange,
                    selectedMuscleGroups: $muscleGroups
                )
            }

            if feedItems.isEmpty {
                emptyState
            } else if isFiltered && filteredItems.isEmpty {
                VStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.largeTitle)
                        .foregroundStyle(Theme.textSecondary)
                    Text("No matching posts")
                        .font(Theme.fontBody)
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                LazyVStack(spacing: Theme.Spacing.md) {
                    ForEach(filteredItems) { item in
                        NavigationLink {
                            FeedDetailView(item: item, userId: currentUserId)
                                .hideTabBar()
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
        XomEmptyState(
            symbolStack: ["text.page", "dumbbell.fill"],
            title: "No posts yet",
            subtitle: "Workouts, PRs, and milestones will appear here.",
            floatingLoop: true
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
