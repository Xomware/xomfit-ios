import SwiftUI

struct FeedView: View {
    @Environment(AuthService.self) private var authService
    @State private var viewModel = FeedViewModel()
    @State private var showUserSearch = false
    @State private var showNotifications = false
    @State private var selectedFeedItem: SocialFeedItem? = nil

    /// #319: locally-hidden feed item ids. Backed by AppStorage so hides persist
    /// across launches. Stored as a comma-separated string because @AppStorage
    /// doesn't support Set<String> natively. Items are filtered out client-side
    /// in `visibleFeedItems`.
    @AppStorage("xomfit_hidden_feed_ids") private var hiddenIdsRaw: String = ""

    private var hiddenIds: Set<String> {
        Set(hiddenIdsRaw.split(separator: ",").map { String($0) }.filter { !$0.isEmpty })
    }

    private func setHiddenIds(_ ids: Set<String>) {
        hiddenIdsRaw = ids.sorted().joined(separator: ",")
    }

    private func hide(_ id: String) {
        var ids = hiddenIds
        ids.insert(id)
        setHiddenIds(ids)
    }

    /// Filtered feed list with locally-hidden items removed. Wraps the
    /// view-model's filtered list (date + muscle filters).
    private var visibleFeedItems: [SocialFeedItem] {
        let ids = hiddenIds
        guard !ids.isEmpty else { return viewModel.filteredFeedItems }
        return viewModel.filteredFeedItems.filter { !ids.contains($0.id) }
    }

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

                        if viewModel.isFiltered && visibleFeedItems.isEmpty {
                            Spacer()
                            XomEmptyState(
                                icon: "line.3.horizontal.decrease",
                                title: "No matching posts",
                                subtitle: "Try adjusting your filters"
                            )
                            Spacer()
                        } else {
                            ZStack {
                                feedList
                                // #311: brief skeleton overlay while a refresh
                                // or filter change is in flight so the list
                                // doesn't pop without feedback.
                                if viewModel.isRefreshing || viewModel.isFiltering {
                                    feedSkeleton
                                        .background(Theme.background)
                                        .transition(.opacity)
                                }
                            }
                            .animation(.easeInOut(duration: 0.2), value: viewModel.isRefreshing)
                            .animation(.easeInOut(duration: 0.2), value: viewModel.isFiltering)
                        }
                    }
                    // #311: trip the filtering flag whenever the date range or
                    // muscle-group selection changes so the skeleton flashes.
                    .onChange(of: viewModel.dateRange) { _, _ in
                        Task { await viewModel.applyFilterChange() }
                    }
                    .onChange(of: viewModel.selectedMuscleGroups) { _, _ in
                        Task { await viewModel.applyFilterChange() }
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
                                        .frame(width: Theme.Spacing.sm, height: Theme.Spacing.sm)
                                        .offset(x: 3, y: -3)
                                }
                            }
                        }
                        .accessibilityLabel(NotificationService.shared.unreadCount > 0
                            ? "Notifications, \(NotificationService.shared.unreadCount) unread"
                            : "Notifications")

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
                        .accessibilityLabel("Friends and requests")
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
        // #319: List-backed so `.swipeActions` works on each feed row. The
        // visual is matched to the prior LazyVStack via hidden separators,
        // background, and tight insets so the change is invisible to the user.
        List {
            ForEach(Array(visibleFeedItems.enumerated()), id: \.element.id) { index, item in
                FeedItemCard(
                    item: item,
                    onLike: {
                        Haptics.selection()
                        Task { await viewModel.toggleLike(feedItem: item, userId: userId) }
                    },
                    onComment: {
                        Haptics.light()
                        selectedFeedItem = item
                    },
                    onDelete: makeDeleteAction(for: item),
                    onEdit: makeEditAction(for: item),
                    onSave: makeSaveAction(for: item)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    Haptics.light()
                    selectedFeedItem = item
                }
                .staggeredAppear(index: index)
                .onAppear {
                    // Trigger pagination off the *visible* list (#359). The
                    // ForEach iterates `visibleFeedItems` (filtered/hidden-
                    // aware), so comparing against `viewModel.feedItems.last`
                    // could miss or mis-fire when hides/filters are applied.
                    if item.id == visibleFeedItems.last?.id {
                        Task { await viewModel.loadMore(userId: userId) }
                    }
                }
                .listRowBackground(Theme.background)
                .listRowInsets(EdgeInsets(
                    top: Theme.Spacing.sm,
                    leading: Theme.Spacing.md,
                    bottom: Theme.Spacing.sm,
                    trailing: Theme.Spacing.md
                ))
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        Haptics.medium()
                        hide(item.id)
                    } label: {
                        Label("Hide", systemImage: "eye.slash")
                    }
                    .tint(Theme.textSecondary)
                }
            }

            // #311: surface load-more failures with a retry banner so the
            // user knows pagination didn't silently exhaust.
            if let loadMoreError = viewModel.loadMoreError {
                loadMoreRetryBanner(message: loadMoreError)
                    .listRowBackground(Theme.background)
                    .listRowInsets(EdgeInsets(top: 0, leading: Theme.Spacing.md, bottom: 0, trailing: Theme.Spacing.md))
                    .listRowSeparator(.hidden)
            } else if !viewModel.hasMore && !visibleFeedItems.isEmpty {
                Text("You're all caught up!")
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(Theme.Spacing.md)
                    .listRowBackground(Theme.background)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable {
            await viewModel.refreshFeed(userId: userId)
        }
    }

    // MARK: - Load-More Retry Banner (#311)

    private func loadMoreRetryBanner(message: String) -> some View {
        VStack(spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.alert)
                Text("Couldn't load more posts")
                    .font(Theme.fontCaption.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
            }
            Text(message)
                .font(Theme.fontCaption)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                Haptics.light()
                Task { await viewModel.loadMore(userId: userId) }
            } label: {
                Text("Retry")
                    .font(Theme.fontCaption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .frame(minHeight: 36)
                    .background(
                        Capsule().fill(Theme.accent.opacity(0.15))
                    )
            }
            .accessibilityLabel("Retry loading more posts")
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .fill(Theme.alert.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .strokeBorder(Theme.alert.opacity(0.4), lineWidth: 0.5)
                )
        )
        .padding(.vertical, Theme.Spacing.sm)
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
        XomErrorState(
            title: "Failed to load feed",
            message: message,
            retryAction: { Task { await viewModel.loadFeed(userId: userId) } }
        )
    }
}
