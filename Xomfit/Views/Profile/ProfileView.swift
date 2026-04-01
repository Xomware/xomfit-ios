import SwiftUI

struct ProfileView: View {
    @Environment(AuthService.self) private var authService
    @State private var viewModel = ProfileViewModel()
    @State private var showEditSheet = false

    /// Pass a userId to view another user's profile. nil = current user (tab root).
    var userId: String? = nil

    private var resolvedUserId: String {
        userId ?? authService.currentUser?.id.uuidString ?? ""
    }

    private var currentUserId: String {
        authService.currentUser?.id.uuidString ?? ""
    }

    var body: some View {
        // Tab root (own profile) gets its own NavigationStack.
        // Pushed profiles (userId != nil) are already inside a NavigationStack.
        if userId == nil {
            NavigationStack {
                profileContent
                    .toolbar { ownProfileToolbar }
            }
        } else {
            profileContent
        }
    }

    // MARK: - Profile Content

    private var profileContent: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if viewModel.isLoading {
                profileSkeleton
            } else if !viewModel.isOwnProfile && viewModel.isPrivate && viewModel.friendshipStatus != .friends {
                PrivateProfileView(
                    displayName: viewModel.displayName,
                    username: viewModel.username,
                    initials: viewModel.initials,
                    friendshipStatus: viewModel.friendshipStatus,
                    onSendRequest: {
                        Task {
                            await viewModel.sendFriendRequest(
                                fromUserId: currentUserId,
                                toUserId: resolvedUserId
                            )
                        }
                    }
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
                    isPrivate: viewModel.isPrivate,
                    isOwnProfile: viewModel.isOwnProfile,
                    feedItemCount: viewModel.feedItemCount,
                    friendCount: viewModel.friendCount,
                    prCount: viewModel.totalPRs,
                    friendshipStatus: viewModel.friendshipStatus,
                    friends: viewModel.friends,
                    friendProfiles: viewModel.friendProfiles,
                    currentUserId: resolvedUserId,
                    onStatTapped: { tab in
                        withAnimation(.xomConfident) {
                            viewModel.selectedTab = tab
                        }
                    },
                    onActionTapped: {
                        if viewModel.isOwnProfile {
                            viewModel.beginEditing()
                            showEditSheet = true
                        } else if viewModel.friendshipStatus == .none {
                            Task {
                                await viewModel.sendFriendRequest(
                                    fromUserId: currentUserId,
                                    toUserId: resolvedUserId
                                )
                            }
                        }
                    }
                )

                // Tab picker (pinned) + tab content
                Section {
                    tabContent
                        .padding(.top, Theme.Spacing.sm)
                        .padding(.bottom, 100) // Space for floating tab bar
                } header: {
                    ProfileTabPicker(selectedTab: Bindable(viewModel).selectedTab)
                        .background(Theme.background)
                }
            }
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.selectedTab {
        case .feed:
            ProfileFeedView(feedItems: $viewModel.feedItems, userId: resolvedUserId, currentUserId: currentUserId)
        case .calendar:
            ProfileCalendarView(workoutDays: viewModel.workoutDays, userId: resolvedUserId)
        case .stats:
            ProfileStatsView(
                totalWorkouts: viewModel.totalWorkouts,
                totalVolume: viewModel.formattedVolume,
                totalPRs: viewModel.totalPRs,
                recentPRs: viewModel.recentPRs,
                muscleGroupSetsThisWeek: viewModel.muscleGroupSetsThisWeek,
                muscleGroupSetsThisMonth: viewModel.muscleGroupSetsThisMonth
            )
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var ownProfileToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 16) {
                Button {
                    viewModel.beginEditing()
                    showEditSheet = true
                } label: {
                    Image(systemName: "pencil")
                        .foregroundStyle(Theme.textSecondary)
                }
                .accessibilityLabel("Edit Profile")

                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(Theme.textSecondary)
                }
                .accessibilityLabel("Settings")
            }
        }
    }
}
