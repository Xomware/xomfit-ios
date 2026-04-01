import SwiftUI

struct FeedView: View {
    @Environment(AuthService.self) private var authService
    @State private var viewModel = FeedViewModel()
    @State private var showUserSearch = false

    private var userId: String {
        authService.currentUser?.id.uuidString ?? ""
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                if viewModel.isLoading {
                    feedSkeleton
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
                    HStack(spacing: 16) {
                        Button {
                            showUserSearch = true
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(Theme.accent)
                        }
                        .accessibilityLabel("Search users")

                        NavigationLink {
                            FriendsView()
                        } label: {
                            Image(systemName: "person.badge.plus")
                                .foregroundColor(Theme.accent)
                        }
                    }
                }
            }
            .sheet(isPresented: $showUserSearch) {
                UserSearchView()
            }
        }
        .onAppear {
            guard !userId.isEmpty else { return }
            Task { await viewModel.loadFeed(userId: userId) }
        }
    }

    // MARK: - Skeleton Loading

    private var feedSkeleton: some View {
        VStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { index in
                SkeletonCard(height: 120)
                    .staggeredAppear(index: index)
            }
        }
        .padding(.horizontal, Theme.paddingMedium)
        .padding(.top, Theme.paddingMedium)
    }

    // MARK: - Feed List

    private var feedList: some View {
        List {
            ForEach(Array(viewModel.feedItems.enumerated()), id: \.element.id) { index, item in
                NavigationLink {
                    FeedDetailView(item: item, userId: userId)
                } label: {
                    FeedItemCard(
                        item: item,
                        onLike: {
                            Task { await viewModel.toggleLike(feedItem: item, userId: userId) }
                        },
                        onComment: {},
                        onDelete: item.userId == userId ? {
                            Task { await viewModel.deleteFeedItem(id: item.id) }
                        } : nil,
                        onEdit: item.userId == userId ? { newCaption in
                            Task { await viewModel.updateCaption(feedItemId: item.id, caption: newCaption) }
                        } : nil,
                        onSave: item.userId != userId && item.activityType == .workout ? {
                            saveWorkoutFromFeed(item: item)
                        } : nil
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
                .staggeredAppear(index: index)
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
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 80) }
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

    // MARK: - Save Workout from Feed

    private func saveWorkoutFromFeed(item: SocialFeedItem) {
        guard let activity = item.workoutActivity else { return }
        let templateExercises = activity.exercises.map { ex in
            WorkoutTemplate.TemplateExercise(
                id: UUID().uuidString,
                exercise: ExerciseDatabase.all.first(where: { $0.name == ex.name })
                    ?? Exercise(
                        id: ex.id,
                        name: ex.name,
                        muscleGroups: [],
                        equipment: .other,
                        category: .compound,
                        description: "",
                        tips: []
                    ),
                targetSets: 3,
                targetReps: "\(ex.bestReps)",
                notes: nil
            )
        }

        let template = WorkoutTemplate(
            id: UUID().uuidString,
            name: activity.workoutName,
            description: "Saved from \(item.user.displayName.isEmpty ? item.user.username : item.user.displayName)",
            exercises: templateExercises,
            estimatedDuration: Int(activity.duration / 60),
            category: .saved,
            isCustom: true
        )
        TemplateService.shared.saveCustomTemplate(template)
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
