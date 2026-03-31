import SwiftUI

struct FeedView: View {
    @Environment(AuthService.self) private var authService
    @State private var viewModel = FeedViewModel()

    private var userId: String {
        authService.currentUser?.id.uuidString ?? ""
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                if viewModel.isLoading {
                    XomFitLoaderPulse()
                } else if let error = viewModel.errorMessage {
                    errorView(message: error)
                } else if viewModel.feedItems.isEmpty {
                    emptyState
                } else {
                    feedList
                }
            }
            .navigationTitle("Feed")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        FriendsView()
                    } label: {
                        Image(systemName: "person.badge.plus")
                            .foregroundColor(Theme.accent)
                    }
                }
            }
        }
        .onAppear {
            guard !userId.isEmpty else { return }
            Task { await viewModel.loadFeed(userId: userId) }
        }
    }

    // MARK: - Feed List

    private var feedList: some View {
        List {
            ForEach(viewModel.feedItems) { item in
                NavigationLink {
                    FeedDetailView(item: item, userId: userId)
                } label: {
                    FeedItemCard(
                        item: item,
                        onLike: {
                            Task { await viewModel.toggleLike(feedItem: item, userId: userId) }
                        },
                        onComment: {}
                    )
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(
                    top: 6,
                    leading: Theme.paddingMedium,
                    bottom: 6,
                    trailing: Theme.paddingMedium
                ))
                .buttonStyle(.plain)
                .onAppear {
                    // Load more when near the end
                    if item.id == viewModel.feedItems.last?.id {
                        Task { await viewModel.loadMore(userId: userId) }
                    }
                }
            }

            if !viewModel.hasMore && !viewModel.feedItems.isEmpty {
                Text("You're all caught up!")
                    .font(Theme.fontCaption)
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(Theme.paddingMedium)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable {
            await viewModel.refreshFeed(userId: userId)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Theme.paddingMedium) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 48))
                .foregroundColor(Theme.textSecondary)
            Text("Your feed is empty")
                .font(Theme.fontHeadline)
                .foregroundColor(Theme.textPrimary)
            Text("Add friends to see their workouts, PRs, and milestones here")
                .font(Theme.fontBody)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.paddingLarge)

            NavigationLink {
                FriendsView()
            } label: {
                Text("Find Friends")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, Theme.paddingLarge)
                    .padding(.vertical, 12)
                    .background(Theme.accent)
                    .cornerRadius(Theme.cornerRadius)
            }
        }
        .padding(Theme.paddingLarge)
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: Theme.paddingMedium) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(Theme.warning)
            Text("Failed to load feed")
                .font(Theme.fontHeadline)
                .foregroundColor(Theme.textPrimary)
            Text(message)
                .font(Theme.fontCaption)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task { await viewModel.loadFeed(userId: userId) }
            }
            .foregroundColor(Theme.accent)
        }
        .padding(Theme.paddingLarge)
    }
}
