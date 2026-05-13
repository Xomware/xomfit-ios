import SwiftUI

struct ProfileView: View {
    @Environment(AuthService.self) private var authService
    @Environment(WorkoutLoggerViewModel.self) private var workoutSession
    @State private var viewModel = ProfileViewModel()
    @State private var showEditSheet = false

    /// Pass a userId to view another user's profile. nil = current user (tab root).
    var userId: String? = nil

    private var resolvedUserId: String {
        userId ?? authService.currentUser?.id.uuidString.lowercased() ?? ""
    }

    private var currentUserId: String {
        authService.currentUser?.id.uuidString.lowercased() ?? ""
    }

    var body: some View {
        // Both own-profile (drawer destination) and pushed profiles live
        // inside `MainTabView`'s NavigationStack (#372). The own-profile case
        // attaches the toolbar with the edit / settings / AI Coach links.
        if userId == nil {
            profileContent
                .toolbar { ownProfileToolbar }
        } else {
            profileContent
        }
    }

    // MARK: - Profile Content

    private var profileContent: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if let error = viewModel.errorMessage, !viewModel.isLoading {
                // #311: surface the failure with a retry CTA instead of an
                // indefinite skeleton. Loading state takes precedence so the
                // skeleton still shows during the actual fetch.
                XomErrorState(
                    title: "Couldn't load profile",
                    message: error,
                    retryAction: {
                        Task {
                            await viewModel.loadAll(
                                userId: resolvedUserId,
                                currentUserId: currentUserId
                            )
                        }
                    }
                )
            } else if viewModel.isLoading {
                profileSkeleton
            } else if !viewModel.isOwnProfile && viewModel.isPrivate && !viewModel.isFriendsRelation {
                PrivateProfileView(
                    displayName: viewModel.displayName,
                    username: viewModel.username,
                    initials: viewModel.initials,
                    relation: viewModel.relation,
                    onAddFriend: {
                        Task {
                            await viewModel.sendFriendRequest(
                                fromUserId: currentUserId,
                                toUserId: resolvedUserId
                            )
                        }
                    },
                    onCancelRequest: { Task { await viewModel.cancelRequest() } },
                    onAcceptRequest: { Task { await viewModel.acceptIncoming() } },
                    onDeclineRequest: { Task { await viewModel.declineIncoming() } }
                )
            } else {
                mainScrollContent
            }
        }
        .navigationTitle(viewModel.isOwnProfile ? "Profile" : viewModel.displayName)
        .navigationBarTitleDisplayMode(viewModel.isOwnProfile ? .large : .inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await viewModel.loadAll(userId: resolvedUserId, currentUserId: currentUserId)
        }
        .refreshable {
            await viewModel.loadAll(userId: resolvedUserId, currentUserId: currentUserId)
        }
        .sheet(isPresented: $showEditSheet) {
            EditProfileSheet(viewModel: viewModel, userId: resolvedUserId)
        }
    }

    // MARK: - Skeleton Loading

    private var profileSkeleton: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Avatar placeholder
            Circle()
                .fill(Theme.surface)
                .frame(width: 80, height: 80)
                .shimmer()

            // Name placeholder
            SkeletonCard(height: 20)
                .frame(width: 160)

            // Stats row placeholder
            HStack(spacing: Theme.Spacing.md) {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonCard(height: 50)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)

            // Content placeholders
            ForEach(0..<3, id: \.self) { index in
                SkeletonCard(height: 80)
                    .staggeredAppear(index: index)
            }
            .padding(.horizontal, Theme.Spacing.md)

            Spacer()
        }
        .padding(.top, Theme.Spacing.lg)
    }

    // MARK: - Main Scroll Content

    private var mainScrollContent: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                // Header (not pinned)
                ProfileHeaderView(
                    displayName: viewModel.displayName,
                    username: viewModel.username,
                    bio: viewModel.bio,
                    initials: viewModel.initials,
                    avatarURL: viewModel.avatarURL,
                    isPrivate: viewModel.isPrivate,
                    isOwnProfile: viewModel.isOwnProfile,
                    feedItemCount: viewModel.feedItemCount,
                    friendCount: viewModel.friendCount,
                    prCount: viewModel.totalPRs,
                    relation: viewModel.relation,
                    friends: viewModel.friends,
                    friendProfiles: viewModel.friendProfiles,
                    currentUserId: resolvedUserId,
                    onStatTapped: { tab in
                        withAnimation(.xomConfident) {
                            viewModel.selectedTab = tab
                        }
                    },
                    onEditProfile: {
                        viewModel.beginEditing()
                        showEditSheet = true
                    },
                    onAddFriend: {
                        Task {
                            await viewModel.sendFriendRequest(
                                fromUserId: currentUserId,
                                toUserId: resolvedUserId
                            )
                        }
                    },
                    onCancelRequest: { Task { await viewModel.cancelRequest() } },
                    onAcceptRequest: { Task { await viewModel.acceptIncoming() } },
                    onDeclineRequest: { Task { await viewModel.declineIncoming() } },
                    onRemoveFriend: { Task { await viewModel.removeFriend() } },
                    onRefreshFriends: {
                        await viewModel.loadAll(
                            userId: resolvedUserId,
                            currentUserId: currentUserId
                        )
                    }
                )

                // Tab picker (pinned) + tab content
                Section {
                    tabContent
                        .padding(.top, Theme.Spacing.md)
                } header: {
                    ProfileTabPicker(selectedTab: Bindable(viewModel).selectedTab)
                        .background(Theme.background)
                }
            }
            .padding(.bottom, 100) // Clear floating tab bar
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.selectedTab {
        case .feed:
            ProfileFeedView(
                feedItems: Bindable(viewModel).feedItems,
                filteredItems: viewModel.filteredFeedItems,
                isFiltered: viewModel.isFeedFiltered,
                dateRange: Bindable(viewModel).feedDateRange,
                muscleGroups: Bindable(viewModel).feedMuscleGroups,
                userId: resolvedUserId,
                currentUserId: currentUserId
            )
        case .calendar:
            ProfileCalendarView(
                workoutDays: viewModel.workoutDays,
                workouts: viewModel.workouts,
                userId: resolvedUserId
            )
        case .stats:
            ProfileStatsView(
                totalWorkouts: viewModel.totalWorkouts,
                totalVolume: viewModel.formattedVolume,
                totalPRs: viewModel.totalPRs,
                recentPRs: viewModel.recentPRs,
                muscleGroupSetsThisWeek: viewModel.muscleGroupSetsThisWeek,
                muscleGroupSetsThisMonth: viewModel.muscleGroupSetsThisMonth,
                volumeTrend: viewModel.volumeTrend30d,
                workoutsPerWeek: viewModel.workoutsPerWeek4w,
                avgWorkoutsPerWeek: viewModel.avgWorkoutsPerWeek,
                topExercises: viewModel.topExercisesByVolume,
                prOfTheMonth: viewModel.prOfTheMonth,
                currentStreak: viewModel.currentStreak,
                longestStreak: viewModel.longestStreak,
                // Only own profile gets the Body link — measurements are private to the user.
                userId: viewModel.isOwnProfile ? resolvedUserId : nil,
                workouts: viewModel.workouts,
                firstPRDate: viewModel.allPRs.map(\.date).min(),
                onStartWorkout: statsEmptyStateAction
            )
        }
    }

    // MARK: - Quick Start Workout (#311 stats empty-state CTA)

    /// Returns the start-workout closure when viewing your own profile, nil
    /// otherwise. Pulled out so the call site is explicitly typed (the inline
    /// ternary trips Swift's type-checker complexity budget in `tabContent`).
    private var statsEmptyStateAction: (() -> Void)? {
        guard viewModel.isOwnProfile else { return nil }
        return { startEmptyWorkout() }
    }

    private func startEmptyWorkout() {
        Haptics.success()
        let userId = authService.currentUser?.id.uuidString.lowercased() ?? ""
        workoutSession.startWorkout(name: "Workout", userId: userId)
        workoutSession.isPresented = true
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var ownProfileToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: Theme.Spacing.md) {
                NavigationLink {
                    AICoachView()
                        .hideTabBar()
                } label: {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Theme.accent)
                }
                .accessibilityLabel("AI Coach")

                Button {
                    viewModel.beginEditing()
                    showEditSheet = true
                } label: {
                    Image(systemName: "pencil")
                        .foregroundStyle(Theme.textPrimary)
                }
                .accessibilityLabel("Edit Profile")

                NavigationLink {
                    SettingsView()
                        .hideTabBar()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(Theme.textPrimary)
                }
                .accessibilityLabel("Settings")
            }
        }
    }
}
