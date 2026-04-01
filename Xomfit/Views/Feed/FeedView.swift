import SwiftUI

struct FeedView: View {
    @Environment(AuthService.self) private var authService
    @State private var viewModel = FeedViewModel()
    @State private var showUserSearch = false
    @State private var selectedFeedItem: SocialFeedItem? = nil

    private var userId: String {
        authService.currentUser?.id.uuidString.lowercased() ?? ""
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
            .navigationDestination(item: $selectedFeedItem) { item in
                FeedDetailView(item: item, userId: userId)
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
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(viewModel.feedItems.enumerated()), id: \.element.id) { index, item in
                    FeedItemCard(
                        item: item,
                        onLike: {
                            Task { await viewModel.toggleLike(feedItem: item, userId: userId) }
                        },
                        onComment: {
                            selectedFeedItem = item
                        },
                        onDelete: makeDeleteAction(for: item),
                        onEdit: makeEditAction(for: item),
                        onSave: makeSaveAction(for: item)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedFeedItem = item
                    }
                    .staggeredAppear(index: index)
                    .onAppear {
                        if item.id == viewModel.feedItems.last?.id {
                            Task { await viewModel.loadMore(userId: userId) }
                        }
                    }
                }

                if !viewModel.hasMore && !viewModel.feedItems.isEmpty {
                    Text("You're all caught up!")
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(Theme.paddingMedium)
                }
            }
            .padding(.horizontal, Theme.paddingMedium)
            .padding(.top, Theme.paddingSmall)
            .padding(.bottom, 100)
        }
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

    // MARK: - Feed Item Actions

    private func makeDeleteAction(for item: SocialFeedItem) -> (() -> Void)? {
        guard item.userId == userId else { return nil }
        return { Task { await viewModel.deleteFeedItem(id: item.id) } }
    }

    private func makeEditAction(for item: SocialFeedItem) -> ((String) -> Void)? {
        guard item.userId == userId else { return nil }
        return { newCaption in Task { await viewModel.updateCaption(feedItemId: item.id, caption: newCaption) } }
    }

    private func makeSaveAction(for item: SocialFeedItem) -> (() -> Void)? {
        guard item.userId != userId, item.activityType == .workout else { return nil }
        return { saveWorkoutFromFeed(item: item) }
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
