import SwiftUI

struct OnboardingFriendsScreen: View {
    let onFinish: () -> Void

    @Environment(AuthService.self) private var authService
    @State private var searchQuery = ""
    @State private var searchResults: [ProfileRow] = []
    @State private var sentRequests: Set<String> = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    private var userId: String {
        authService.currentUser?.id.uuidString.lowercased() ?? ""
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer().frame(height: Theme.Spacing.xl)

            // Header
            VStack(spacing: Theme.Spacing.sm) {
                Text("Find Your Crew")
                    .font(Theme.fontTitle)
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Training is better with friends")
                    .font(Theme.fontSubheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            .staggeredAppear(index: 0)

            // Search bar
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.textSecondary)

                TextField("Search by username", text: $searchQuery)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(Theme.textPrimary)

                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                        searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                if isSearching {
                    ProgressView()
                        .tint(Theme.accent)
                        .controlSize(.small)
                }
            }
            .padding(Theme.Spacing.sm)
            .background(Theme.surface)
            .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
            .padding(.horizontal, Theme.Spacing.lg)
            .staggeredAppear(index: 1)
            .onChange(of: searchQuery) { _, newValue in
                debouncedSearch(newValue)
            }

            // Results
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.sm) {
                    if searchResults.isEmpty && !searchQuery.isEmpty && !isSearching {
                        Text("No users found")
                            .font(Theme.fontBody)
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.top, Theme.Spacing.lg)
                    } else if searchResults.isEmpty && searchQuery.isEmpty {
                        VStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "person.2.fill")
                                .font(.largeTitle)
                                .foregroundStyle(Theme.textSecondary.opacity(0.5))
                            Text("Search by username to find friends")
                                .font(Theme.fontBody)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .padding(.top, Theme.Spacing.xxl)
                    } else {
                        ForEach(searchResults, id: \.id) { user in
                            userRow(user)
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }

            // CTA
            XomButton("Let's Go", icon: "arrow.right") {
                Haptics.success()
                onFinish()
            }
            .padding(.horizontal, Theme.Spacing.lg)
        }
    }

    // MARK: - User Row

    private func userRow(_ user: ProfileRow) -> some View {
        let isSent = sentRequests.contains(user.id)

        return HStack(spacing: Theme.Spacing.sm) {
            XomAvatar(
                name: user.displayName.isEmpty ? user.username : user.displayName,
                size: 40
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName.isEmpty ? user.username : user.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("@\(user.username)")
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            Button {
                guard !isSent else { return }
                Haptics.light()
                sendRequest(to: user.id)
            } label: {
                Text(isSent ? "Sent" : "Add")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isSent ? Theme.textSecondary : .black)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(isSent ? Theme.surface : Theme.accent)
                    .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
            }
            .disabled(isSent)
        }
        .padding(Theme.Spacing.sm)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
    }

    // MARK: - Search

    private func debouncedSearch(_ query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            do {
                let results = try await FriendsService.shared.searchUsers(
                    query: trimmed,
                    excludeUserId: userId
                )
                guard !Task.isCancelled else { return }
                searchResults = results
            } catch {
                guard !Task.isCancelled else { return }
            }
            isSearching = false
        }
    }

    private func sendRequest(to targetId: String) {
        withAnimation(.xomConfident) {
            sentRequests.insert(targetId)
        }
        Task {
            do {
                try await FriendsService.shared.sendFriendRequest(
                    fromUserId: userId,
                    toUserId: targetId
                )
            } catch {
                withAnimation {
                    sentRequests.remove(targetId)
                }
            }
        }
    }
}
