import SwiftUI

struct ProfileView: View {
    @Environment(AuthService.self) private var authService
    @Environment(WorkoutLoggerViewModel.self) private var workoutSession
    @State private var viewModel = ProfileViewModel()
    @State private var showEditSheet = false

    /// Destination picked from the profile's quick links. Presented here rather
    /// than routed through `MainTabView`, so Profile owns its own navigation
    /// instead of reaching back into the shell.
    @State private var quickLink: AppDestination?

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
            // Pull the latest logged bodyweight so strength ranks score against
            // a current number. Nothing called this before, which meant the
            // service always fell back to the manually-entered value even for
            // lifters who log measurements.
            if viewModel.isOwnProfile {
                await StrengthLevelService.shared.refreshBodyweight(userId: resolvedUserId)
            }
        }
        .refreshable {
            await viewModel.loadAll(userId: resolvedUserId, currentUserId: currentUserId)
        }
        .fullScreenCover(item: $quickLink) { destination in
            NavigationStack {
                quickLinkDestination(destination)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { quickLink = nil }
                                .foregroundStyle(Theme.accent)
                        }
                    }
            }
            .environment(authService)
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showEditSheet) {
            EditProfileSheet(viewModel: viewModel, userId: resolvedUserId)
        }
    }

    @ViewBuilder
    private func quickLinkDestination(_ destination: AppDestination) -> some View {
        switch destination {
        case .stretches: StretchesView()
        case .stats:     XomProgressView()
        default:         SettingsView()
        }
    }

    /// Rows into the destinations that have no tab of their own.
    private var profileQuickLinks: some View {
        VStack(spacing: 0) {
            quickLinkRow("Stretches", icon: "figure.cooldown") { quickLink = .stretches }
            Divider().overlay(Theme.hairline)
            quickLinkRow("Stats", icon: "chart.bar.xaxis") { quickLink = .stats }
            Divider().overlay(Theme.hairline)
            quickLinkRow("Settings", icon: "gearshape.fill") { quickLink = .settings }
        }
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.md))
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.sm)
    }

    private func quickLinkRow(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: icon)
                    .frame(width: Theme.Spacing.lg)
                    .foregroundStyle(Theme.accent)
                Text(title)
                    .font(Theme.fontBody)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
                    anthem: viewModel.anthem,
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

                // The 4th tab as the "more" destination, which is what a bottom
                // nav bar implies it is. These lived only behind the avatar in
                // the toolbar — a second navigation system layered on top of the
                // tabs, and the one place nothing announced itself. The avatar
                // still works; it just is not the only way in any more.
                if viewModel.isOwnProfile {
                    profileQuickLinks
                }

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
                allPRs: viewModel.allPRs,
                viewedUserId: resolvedUserId,
                onStartWorkout: statsEmptyStateAction
            )
        case .music:
            ProfileMusicView(tracks: viewModel.aggregatedTracks)
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
