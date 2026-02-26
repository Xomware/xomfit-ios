import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @EnvironmentObject var authService: AuthService
    @State private var showEditProfile = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                if viewModel.showSetupFlow {
                    // First-time setup
                    ProfileSetupView(viewModel: viewModel)
                        .environmentObject(authService)
                } else {
                    mainProfileContent
                }
            }
            .navigationTitle(viewModel.showSetupFlow ? "" : "Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !viewModel.showSetupFlow {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showEditProfile = true
                        } label: {
                            Image(systemName: "pencil")
                                .foregroundColor(Theme.accent)
                        }
                        .accessibilityLabel("Edit Profile")
                    }
                }
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView(viewModel: viewModel)
                    .environmentObject(authService)
            }
        }
        .task {
            if let userId = authService.currentUser?.id {
                await viewModel.loadProfile(userId: userId)
            }
        }
    }

    // MARK: - Main Content

    private var mainProfileContent: some View {
        ScrollView {
            VStack(spacing: Theme.paddingLarge) {
                profileHeader
                privacyBadge
                statsGrid
                volumeCard
                recentPRsSection
                signOutButton
            }
        }
        .refreshable {
            if let userId = authService.currentUser?.id {
                await viewModel.refresh(userId: userId)
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .tint(Theme.accent)
                    .scaleEffect(1.4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.background.opacity(0.6))
            }
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: 12) {
            AvatarView(
                avatarURL: viewModel.user.avatarURL,
                displayName: viewModel.user.displayName,
                size: 96
            )

            VStack(spacing: 4) {
                Text(viewModel.user.displayName)
                    .font(Theme.fontTitle)
                    .foregroundColor(Theme.textPrimary)

                Text("@\(viewModel.user.username)")
                    .font(Theme.fontBody)
                    .foregroundColor(Theme.textSecondary)
            }

            if !viewModel.user.bio.isEmpty {
                Text(viewModel.user.bio)
                    .font(Theme.fontBody)
                    .foregroundColor(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.paddingLarge)
            }

            // Member since
            Text("Member since \(viewModel.user.createdAt.memberSince)")
                .font(Theme.fontCaption)
                .foregroundColor(Theme.textSecondary.opacity(0.7))
        }
        .padding(.top, Theme.paddingMedium)
    }

    // MARK: - Privacy Badge

    @ViewBuilder
    private var privacyBadge: some View {
        if viewModel.user.isPrivate {
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11))
                Text("Private Profile")
                    .font(Theme.fontCaption)
            }
            .foregroundColor(Theme.warning)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Theme.warning.opacity(0.12))
            .cornerRadius(20)
        }
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
            spacing: 12
        ) {
            ProfileStatCard(
                value: "\(viewModel.user.stats.totalWorkouts)",
                label: "Workouts",
                icon: "dumbbell.fill"
            )
            ProfileStatCard(
                value: "\(viewModel.user.stats.totalPRs)",
                label: "PRs",
                icon: "trophy.fill"
            )
            ProfileStatCard(
                value: streakText,
                label: "Day Streak",
                icon: nil
            )
        }
        .padding(.horizontal, Theme.paddingMedium)
    }

    private var streakText: String {
        let n = viewModel.user.stats.currentStreak
        return n > 0 ? "\(n) 🔥" : "\(n)"
    }

    // MARK: - Volume Card

    private var volumeCard: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Total Volume Lifted")
                    .font(Theme.fontCaption)
                    .foregroundColor(Theme.textSecondary)
                Text(formattedVolume(viewModel.user.stats.totalVolume))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Theme.accent)
                Text("Longest streak: \(viewModel.user.stats.longestStreak) days")
                    .font(Theme.fontCaption)
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()

            if let fav = viewModel.user.stats.favoriteExercise {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Favourite Lift")
                        .font(Theme.fontCaption)
                        .foregroundColor(Theme.textSecondary)
                    Text(fav)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                }
            }
        }
        .cardStyle()
        .padding(.horizontal, Theme.paddingMedium)
    }

    // MARK: - Recent PRs

    @ViewBuilder
    private var recentPRsSection: some View {
        if !viewModel.recentPRs.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Personal Records")
                    .font(Theme.fontHeadline)
                    .foregroundColor(Theme.textPrimary)
                    .padding(.horizontal, Theme.paddingMedium)

                ForEach(viewModel.recentPRs) { pr in
                    HStack {
                        Image(systemName: "trophy.fill")
                            .foregroundColor(Theme.prGold)
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(pr.exerciseName)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Theme.textPrimary)
                            Text(pr.date.timeAgo)
                                .font(Theme.fontCaption)
                                .foregroundColor(Theme.textSecondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(pr.weight.formattedWeight) lbs × \(pr.reps)")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(Theme.accent)
                            if let imp = pr.improvementString {
                                Text(imp)
                                    .font(Theme.fontCaption)
                                    .foregroundColor(Theme.accent.opacity(0.7))
                            }
                        }
                    }
                    .cardStyle()
                    .padding(.horizontal, Theme.paddingMedium)
                }
            }
        }
    }

    // MARK: - Sign Out

    private var signOutButton: some View {
        Button {
            Task { try? await authService.signOut() }
        } label: {
            Text("Sign Out")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Theme.destructive)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.destructive.opacity(0.1))
                .cornerRadius(Theme.cornerRadius)
        }
        .padding(.horizontal, Theme.paddingMedium)
        .padding(.bottom, Theme.paddingLarge)
    }

    // MARK: - Helpers

    private func formattedVolume(_ volume: Double) -> String {
        if volume >= 1_000_000 {
            return String(format: "%.1fM lbs", volume / 1_000_000)
        } else if volume >= 1_000 {
            return String(format: "%.0fk lbs", volume / 1_000)
        }
        return "\(Int(volume)) lbs"
    }
}

// MARK: - Stat Card

struct ProfileStatCard: View {
    let value: String
    let label: String
    var icon: String?

    var body: some View {
        VStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(Theme.accent.opacity(0.75))
            }
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Theme.textPrimary)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }
}
