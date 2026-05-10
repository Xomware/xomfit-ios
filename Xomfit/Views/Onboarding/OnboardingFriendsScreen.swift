import SwiftUI

struct OnboardingFriendsScreen: View {
    let onFinish: () -> Void

    @Environment(AuthService.self) private var authService
    @State private var searchQuery = ""
    @State private var searchResults: [ProfileRow] = []
    @State private var relations: [String: FriendshipRelation] = [:]
    @State private var errorMessage: String?
    @State private var cancelTargetId: String?
    @State private var showCancelDialog = false
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
                        relations = [:]
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.textSecondary)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Clear search")
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
                                .font(Theme.fontLargeTitle)
                                .foregroundStyle(Theme.textSecondary.opacity(0.5))
                            Text("Search by username to find friends")
                                .font(Theme.fontBody)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .padding(.top, Theme.Spacing.xxl)
                    } else {
                        ForEach(searchResults.filter { user in
                            if case .blocked = relations[user.id] ?? .none { return false }
                            return true
                        }, id: \.id) { user in
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
        .confirmationDialog(
            "Cancel friend request?",
            isPresented: $showCancelDialog,
            titleVisibility: .visible
        ) {
            Button("Cancel Request", role: .destructive) {
                if let id = cancelTargetId,
                   case .outgoingPending(let fid) = relations[id] ?? .none {
                    cancelRequest(targetId: id, friendshipId: fid)
                }
                cancelTargetId = nil
            }
            Button("Keep", role: .cancel) {
                cancelTargetId = nil
            }
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - User Row

    @ViewBuilder
    private func userRow(_ user: ProfileRow) -> some View {
        let relation = relations[user.id] ?? .none

        HStack(spacing: Theme.Spacing.sm) {
            XomAvatar(
                name: user.displayName.isEmpty ? user.username : user.displayName,
                size: 40
            )

            VStack(alignment: .leading, spacing: Theme.Spacing.tighter) {
                Text(user.displayName.isEmpty ? user.username : user.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("@\(user.username)")
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            actionView(for: user, relation: relation)
        }
        .padding(Theme.Spacing.sm)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
    }

    @ViewBuilder
    private func actionView(for user: ProfileRow, relation: FriendshipRelation) -> some View {
        switch relation {
        case .none:
            Button {
                Haptics.light()
                sendRequest(to: user.id)
            } label: {
                pill(text: "Add", style: .primary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add friend")

        case .outgoingPending:
            Button {
                Haptics.light()
                cancelTargetId = user.id
                showCancelDialog = true
            } label: {
                pill(text: "Sent", style: .ghost)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cancel friend request")

        case .incomingPending(let friendshipId):
            VStack(spacing: 6) {
                Button {
                    Haptics.success()
                    acceptRequest(user.id, friendshipId: friendshipId)
                } label: {
                    pill(text: "Accept", style: .primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Accept friend request")

                Button {
                    Haptics.light()
                    declineRequest(user.id, friendshipId: friendshipId)
                } label: {
                    Text("Decline")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.destructive)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Decline friend request")
            }

        case .friends:
            pill(text: "Friends", style: .disabled)

        case .blocked:
            // Row is filtered out upstream; render nothing defensively.
            EmptyView()
        }
    }

    private enum PillStyle { case primary, ghost, disabled }

    private func pill(text: String, style: PillStyle) -> some View {
        let foreground: Color = {
            switch style {
            case .primary: return .black
            case .ghost, .disabled: return Theme.textSecondary
            }
        }()
        let background: Color = {
            switch style {
            case .primary: return Theme.accent
            case .ghost, .disabled: return Theme.surfaceElevated
            }
        }()

        return Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(foreground)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.xs)
            .background(background)
            .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
    }

    // MARK: - Search

    private func debouncedSearch(_ query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            searchResults = []
            relations = [:]
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
                let ids = results.map { $0.id }
                let fetched = try await FriendsService.shared.batchRelations(
                    currentUserId: userId,
                    otherUserIds: ids
                )
                guard !Task.isCancelled else { return }
                relations = fetched
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
            }
            isSearching = false
        }
    }

    // MARK: - Mutations

    private func sendRequest(to targetId: String) {
        // Optimistic
        let placeholder = FriendshipRelation.outgoingPending(friendshipId: "pending")
        _ = withAnimation(.xomConfident) {
            relations[targetId] = placeholder
        }
        Task {
            do {
                let newId = try await FriendsService.shared.sendFriendRequest(
                    fromUserId: userId,
                    toUserId: targetId
                )
                relations[targetId] = .outgoingPending(friendshipId: newId)
            } catch FriendError.alreadyExists(let existing) {
                relations[targetId] = existing
            } catch {
                _ = withAnimation {
                    relations[targetId] = FriendshipRelation.none
                }
                errorMessage = error.localizedDescription
            }
        }
    }

    private func cancelRequest(targetId: String, friendshipId: String) {
        guard friendshipId != "pending" else {
            relations[targetId] = .none
            return
        }
        Task {
            do {
                try await FriendsService.shared.cancelFriendRequest(friendshipId: friendshipId)
                relations[targetId] = .none
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func acceptRequest(_ targetId: String, friendshipId: String) {
        Task {
            do {
                try await FriendsService.shared.acceptFriendRequest(friendshipId: friendshipId)
                relations[targetId] = .friends(friendshipId: friendshipId)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func declineRequest(_ targetId: String, friendshipId: String) {
        Task {
            do {
                try await FriendsService.shared.declineFriendRequest(friendshipId: friendshipId)
                relations[targetId] = .none
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
