import SwiftUI

struct FeedView: View {
    @Environment(AuthService.self) private var authService
    @State private var viewModel = FeedViewModel()
    @State private var showUserSearch = false
    @State private var showNotifications = false
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
                    VStack(spacing: 0) {
                        FeedFilterBar(
                            selectedDateRange: $viewModel.dateRange,
                            selectedMuscleGroups: $viewModel.selectedMuscleGroups
                        )

                        if viewModel.isFiltered && viewModel.filteredFeedItems.isEmpty {
                            Spacer()
                            XomEmptyState(
                                icon: "line.3.horizontal.decrease",
                                title: "No matching posts",
                                subtitle: "Try adjusting your filters"
                            )
                            Spacer()
                        } else {
                            feedList
                        }
                    }
                }
            }
            .navigationTitle("Feed")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: Theme.Spacing.md) {
                        Button {
                            showNotifications = true
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "bell")
                                    .foregroundStyle(Theme.textPrimary)
                                if NotificationService.shared.unreadCount > 0 {
                                    Circle()
                                        .fill(Theme.destructive)
                                        .frame(width: 8, height: 8)
                                        .offset(x: 3, y: -3)
                                }
                            }
                        }
                        .accessibilityLabel("Notifications")

                        Button {
                            showUserSearch = true
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(Theme.textPrimary)
                        }
                        .accessibilityLabel("Search users")

                        NavigationLink {
                            FriendsView()
                                .hideTabBar()
                        } label: {
                            Image(systemName: "person.badge.plus")
                                .foregroundStyle(Theme.textPrimary)
                        }
                    }
                }
            }
            .navigationDestination(item: $selectedFeedItem) { item in
                FeedDetailView(item: item, userId: userId)
                    .hideTabBar()
            }
            .sheet(isPresented: $showUserSearch) {
                UserSearchView()
            }
            .sheet(isPresented: $showNotifications) {
                NotificationInboxView()
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
                XomSkeletonRow(style: .feedPost)
                    .staggeredAppear(index: index)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.md)
    }

    // MARK: - Feed List

    private var feedList: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.md) {
                ForEach(Array(viewModel.filteredFeedItems.enumerated()), id: \.element.id) { index, item in
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

                if !viewModel.hasMore && !viewModel.filteredFeedItems.isEmpty {
                    Text("You're all caught up!")
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(Theme.Spacing.md)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, Theme.Spacing.sm)
        }
        .refreshable {
            await viewModel.refreshFeed(userId: userId)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        XomEmptyState(
            icon: "person.2.fill",
            title: "Your feed is empty",
            subtitle: "Add friends to see their workouts, PRs, and milestones here",
            ctaLabel: "Find Friends",
            ctaAction: { showUserSearch = true }
        )
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
                exercise: ExerciseDatabase.byName[ex.name]
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
        XomEmptyState(
            icon: "exclamationmark.triangle",
            title: "Failed to load feed",
            subtitle: message,
            ctaLabel: "Try Again",
            ctaAction: { Task { await viewModel.loadFeed(userId: userId) } }
        )
    }
}
