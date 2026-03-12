import SwiftUI

struct ProfileView: View {
    @Environment(AuthService.self) private var authService
    @State private var viewModel = ProfileViewModel()
    @State private var showEditSheet = false
    @State private var showSignOutConfirm = false

    private var userId: String {
        authService.currentUser?.id.uuidString ?? ""
    }

    private var userEmail: String {
        authService.currentUser?.email ?? ""
    }

    private var initials: String {
        let name = viewModel.displayName.isEmpty ? userEmail : viewModel.displayName
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView()
                        .tint(Theme.accent)
                } else {
                    ScrollView {
                        VStack(spacing: Theme.paddingMedium) {
                            avatarHeader
                            statsGrid
                            recentPRsSection
                            navigationLinks
                            signOutSection
                        }
                        .padding(Theme.paddingMedium)
                    }
                }
            }
            .navigationTitle("Profile")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.beginEditing()
                        showEditSheet = true
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundColor(Theme.accent)
                    }
                }
            }
        }
        .onAppear {
            Task { await viewModel.loadProfile(userId: userId) }
        }
        .sheet(isPresented: $showEditSheet) {
            EditProfileSheet(viewModel: viewModel, userId: userId)
        }
        .alert("Sign Out?", isPresented: $showSignOutConfirm) {
            Button("Sign Out", role: .destructive) {
                Task { await authService.signOut() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will be returned to the login screen.")
        }
    }

    // MARK: - Avatar Header

    private var avatarHeader: some View {
        VStack(spacing: Theme.paddingSmall) {
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.2))
                    .frame(width: 80, height: 80)
                Text(initials)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Theme.accent)
            }

            if !viewModel.displayName.isEmpty {
                Text(viewModel.displayName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
            }

            if !viewModel.username.isEmpty {
                Text("@\(viewModel.username)")
                    .font(Theme.fontCaption)
                    .foregroundColor(Theme.textSecondary)
            }

            if !viewModel.bio.isEmpty {
                Text(viewModel.bio)
                    .font(Theme.fontBody)
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if viewModel.isPrivate {
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                    Text("Private Account")
                        .font(Theme.fontSmall)
                }
                .foregroundColor(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.paddingLarge)
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        HStack(spacing: 1) {
            statCell(
                value: "\(viewModel.totalWorkouts)",
                label: "Workouts",
                icon: "dumbbell.fill"
            )
            Divider()
                .background(Theme.background)
                .frame(width: 1)
            statCell(
                value: formattedVolume,
                label: "Volume",
                icon: "scalemass.fill"
            )
            Divider()
                .background(Theme.background)
                .frame(width: 1)
            statCell(
                value: "\(viewModel.totalPRs)",
                label: "PRs",
                icon: "trophy.fill"
            )
        }
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
    }

    private func statCell(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(Theme.accent)
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Theme.textPrimary)
            Text(label)
                .font(Theme.fontSmall)
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.paddingMedium)
    }

    private var formattedVolume: String {
        if viewModel.totalVolume >= 1_000_000 {
            return String(format: "%.1fM", viewModel.totalVolume / 1_000_000)
        } else if viewModel.totalVolume >= 1000 {
            return String(format: "%.1fk", viewModel.totalVolume / 1000)
        }
        return "\(Int(viewModel.totalVolume))"
    }

    // MARK: - Recent PRs

    @ViewBuilder
    private var recentPRsSection: some View {
        if !viewModel.recentPRs.isEmpty {
            VStack(alignment: .leading, spacing: Theme.paddingSmall) {
                Text("Recent PRs")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)

                ForEach(viewModel.recentPRs) { pr in
                    PRBadgeRow(pr: pr)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.paddingMedium)
            .background(Theme.cardBackground)
            .cornerRadius(Theme.cornerRadius)
        }
    }

    // MARK: - Navigation Links

    private var navigationLinks: some View {
        VStack(spacing: 0) {
            NavigationLink {
                PRListView(userId: userId)
            } label: {
                navRow(icon: "trophy.fill", iconColor: Theme.prGold, title: "All Personal Records")
            }

            Divider()
                .background(Theme.background)

            NavigationLink {
                SettingsView()
            } label: {
                navRow(icon: "gearshape.fill", iconColor: Theme.textSecondary, title: "Settings")
            }

            Divider()
                .background(Theme.background)

            NavigationLink {
                FriendsView()
            } label: {
                navRow(icon: "person.2.fill", iconColor: Theme.accent, title: "Friends")
            }
        }
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
    }

    private func navRow(icon: String, iconColor: Color, title: String) -> some View {
        HStack(spacing: Theme.paddingMedium) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundColor(iconColor)
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Theme.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(Theme.paddingMedium)
    }

    // MARK: - Sign Out

    private var signOutSection: some View {
        Button(role: .destructive) {
            showSignOutConfirm = true
        } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Sign Out")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(Theme.destructive)
            .frame(maxWidth: .infinity)
            .padding(Theme.paddingMedium)
            .background(Theme.cardBackground)
            .cornerRadius(Theme.cornerRadius)
        }
    }
}

// MARK: - PR Badge Row

private struct PRBadgeRow: View {
    let pr: PersonalRecord

    var body: some View {
        HStack {
            Image(systemName: "trophy.fill")
                .foregroundColor(Theme.prGold)
                .font(.system(size: 14))

            Text(pr.exerciseName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.textPrimary)

            Spacer()

            Text("\(pr.weight.formattedWeight) × \(pr.reps)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Theme.accent)

            if let imp = pr.improvementString {
                Text(imp)
                    .font(Theme.fontSmall)
                    .foregroundColor(Theme.prGold)
            }
        }
    }
}

// MARK: - Edit Profile Sheet

private struct EditProfileSheet: View {
    let viewModel: ProfileViewModel
    let userId: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                Form {
                    Section("Display Name") {
                        TextField("Your name", text: Bindable(viewModel).editDisplayName)
                            .listRowBackground(Theme.cardBackground)
                            .foregroundColor(Theme.textPrimary)
                    }

                    Section("Bio") {
                        TextField("Tell people about yourself", text: Bindable(viewModel).editBio, axis: .vertical)
                            .lineLimit(3...5)
                            .listRowBackground(Theme.cardBackground)
                            .foregroundColor(Theme.textPrimary)
                    }

                    Section {
                        Toggle("Private Account", isOn: Bindable(viewModel).editIsPrivate)
                            .tint(Theme.accent)
                            .listRowBackground(Theme.cardBackground)
                            .foregroundColor(Theme.textPrimary)
                    } footer: {
                        Text("Only friends can see your activity when your account is private.")
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.isSaving {
                        ProgressView().tint(Theme.accent)
                    } else {
                        Button("Save") {
                            Task {
                                await viewModel.updateProfile(userId: userId)
                                if viewModel.errorMessage == nil {
                                    dismiss()
                                }
                            }
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.accent)
                    }
                }
            }
        }
    }
}
