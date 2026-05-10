import SwiftUI

struct FriendsView: View {
    @Environment(AuthService.self) private var authService

    @State private var vm = FriendsViewModel()
    @State private var searchTask: Task<Void, Never>?

    private var userId: String {
        authService.currentUser?.id.uuidString.lowercased() ?? ""
    }

    var body: some View {
        @Bindable var vm = vm

        return ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Search bar
                searchBar(bindable: $vm.searchQuery)

                if vm.isLoading && vm.searchQuery.isEmpty {
                    Spacer()
                    XomFitLoaderPulse()
                    Spacer()
                } else {
                    List {
                        if !vm.searchQuery.isEmpty {
                            searchResultsSection
                        } else {
                            if !vm.incomingRequests.isEmpty {
                                incomingRequestsSection
                            }
                            if !vm.outgoingRequests.isEmpty {
                                outgoingRequestsSection
                            }
                            friendsSection
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("Friends")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await vm.loadAll(userId: userId) }
        .refreshable { await vm.loadAll(userId: userId) }
        .alert("Error", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    // MARK: - Search Bar

    private func searchBar(bindable query: Binding<String>) -> some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.textSecondary)
            TextField("Search by username", text: query)
                .foregroundStyle(Theme.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: query.wrappedValue) { _, newValue in
                    searchTask?.cancel()
                    let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else {
                        vm.clearSearch()
                        return
                    }
                    searchTask = Task {
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        guard !Task.isCancelled else { return }
                        await vm.performSearch(query: trimmed, userId: userId)
                    }
                }
            if !query.wrappedValue.isEmpty {
                Button {
                    query.wrappedValue = ""
                    vm.clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.textSecondary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(Theme.Spacing.sm)
        .padding(.horizontal, Theme.Spacing.sm)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.Radius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .strokeBorder(Theme.hairline, lineWidth: 0.5)
        )
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
    }

    // MARK: - Sections

    @ViewBuilder
    private var searchResultsSection: some View {
        Section {
            if vm.isSearching {
                HStack {
                    Spacer()
                    ProgressView().tint(Theme.accent)
                    Spacer()
                }
                .listRowBackground(Theme.surface)
            } else {
                let visible = vm.searchResults.filter { profile in
                    if case .blocked = vm.searchRelations[profile.id] ?? .none { return false }
                    return true
                }

                if visible.isEmpty {
                    Text("No users found for \"\(vm.searchQuery)\"")
                        .foregroundStyle(Theme.textSecondary)
                        .font(Theme.fontBody)
                        .listRowBackground(Theme.surface)
                } else {
                    ForEach(visible, id: \.id) { profile in
                        SearchResultRow(
                            profile: profile,
                            relation: vm.searchRelations[profile.id] ?? .none,
                            onAdd: {
                                Task { await vm.sendRequest(fromUserId: userId, toUserId: profile.id) }
                            },
                            onCancel: {
                                if case .outgoingPending(let fid) = vm.searchRelations[profile.id] ?? .none {
                                    Task { await vm.cancelRequest(friendshipId: fid, otherUserId: profile.id) }
                                }
                            },
                            onAccept: {
                                if case .incomingPending(let fid) = vm.searchRelations[profile.id] ?? .none {
                                    Task { await vm.acceptRequest(friendshipId: fid, otherUserId: profile.id, userId: userId) }
                                }
                            },
                            onDecline: {
                                if case .incomingPending(let fid) = vm.searchRelations[profile.id] ?? .none {
                                    Task { await vm.declineRequest(friendshipId: fid, otherUserId: profile.id) }
                                }
                            }
                        )
                        .listRowBackground(Theme.surface)
                    }
                }
            }
        } header: {
            Text("Search Results")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
                .textCase(nil)
        }
    }

    @ViewBuilder
    private var incomingRequestsSection: some View {
        Section {
            ForEach(vm.incomingRequests, id: \.id) { req in
                PendingRequestRow(
                    request: req,
                    requesterProfile: vm.requesterProfiles[req.requesterId],
                    onAccept: {
                        Task { await vm.acceptRequest(friendshipId: req.id, otherUserId: req.requesterId, userId: userId) }
                    },
                    onDecline: {
                        Task { await vm.declineRequest(friendshipId: req.id, otherUserId: req.requesterId) }
                    }
                )
                .listRowBackground(Theme.surface)
            }
        } header: {
            Text("Incoming")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .textCase(nil)
        }
    }

    @ViewBuilder
    private var outgoingRequestsSection: some View {
        Section {
            ForEach(vm.outgoingRequests, id: \.id) { req in
                OutgoingRequestRow(
                    request: req,
                    addresseeProfile: vm.addresseeProfiles[req.addresseeId],
                    onCancel: {
                        Task { await vm.cancelRequest(friendshipId: req.id, otherUserId: req.addresseeId) }
                    }
                )
                .listRowBackground(Theme.surface)
            }
        } header: {
            Text("Sent")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
                .textCase(nil)
        }
    }

    @ViewBuilder
    private var friendsSection: some View {
        Section {
            if vm.friends.isEmpty {
                Text("No friends yet. Search to add people!")
                    .foregroundStyle(Theme.textSecondary)
                    .font(Theme.fontBody)
                    .listRowBackground(Theme.surface)
            } else {
                ForEach(vm.friends, id: \.id) { friend in
                    let friendId = friend.requesterId == userId ? friend.addresseeId : friend.requesterId
                    FriendListRow(
                        friend: friend,
                        currentUserId: userId,
                        friendProfile: vm.friendProfiles[friendId]
                    ) {
                        Task { await vm.removeFriend(friendshipId: friend.id, otherUserId: friendId) }
                    }
                    .listRowBackground(Theme.surface)
                }
            }
        } header: {
            Text("Friends (\(vm.friends.count))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
                .textCase(nil)
        }
    }
}

// MARK: - Search Result Row

private struct SearchResultRow: View {
    let profile: ProfileRow
    let relation: FriendshipRelation
    let onAdd: () -> Void
    let onCancel: () -> Void
    let onAccept: () -> Void
    let onDecline: () -> Void

    @State private var showCancelDialog = false

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            XomAvatar(
                name: profile.displayName.isEmpty ? profile.username : profile.displayName,
                size: 40
            )

            VStack(alignment: .leading, spacing: Theme.Spacing.tighter) {
                Text(profile.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("@\(profile.username)")
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textTertiary)
            }

            Spacer()

            actionView
        }
        .padding(.vertical, Theme.Spacing.tight)
        .confirmationDialog(
            "Cancel friend request?",
            isPresented: $showCancelDialog,
            titleVisibility: .visible
        ) {
            Button("Cancel Request", role: .destructive) {
                Haptics.light()
                onCancel()
            }
            Button("Keep", role: .cancel) {}
        }
    }

    @ViewBuilder
    private var actionView: some View {
        switch relation {
        case .none:
            Button {
                Haptics.success()
                onAdd()
            } label: {
                pill(text: "Add", style: .primary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add friend")

        case .outgoingPending:
            Button {
                Haptics.light()
                showCancelDialog = true
            } label: {
                pill(text: "Sent", style: .ghost)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cancel friend request")

        case .incomingPending:
            VStack(spacing: 6) {
                Button {
                    Haptics.success()
                    onAccept()
                } label: {
                    pill(text: "Accept", style: .primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Accept friend request")

                Button {
                    Haptics.light()
                    onDecline()
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
        let borderColor: Color = (style == .primary) ? .clear : Theme.hairline

        return Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(background)
            .clipShape(.rect(cornerRadius: Theme.Radius.xs))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.xs)
                    .strokeBorder(borderColor, lineWidth: 0.5)
            )
    }
}

// MARK: - Pending (Incoming) Request Row

private struct PendingRequestRow: View {
    let request: FriendRow
    let requesterProfile: ProfileRow?
    let onAccept: () -> Void
    let onDecline: () -> Void

    private var requesterName: String {
        if let profile = requesterProfile {
            return profile.displayName.isEmpty ? profile.username : profile.displayName
        }
        return String(request.requesterId.prefix(8))
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            XomAvatar(name: requesterName, size: 40)

            VStack(alignment: .leading, spacing: Theme.Spacing.tighter) {
                Text(requesterName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                if let profile = requesterProfile {
                    Text("@\(profile.username)")
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: Theme.Spacing.sm) {
                Button("Accept") {
                    Haptics.light()
                    onAccept()
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Theme.accent)
                .clipShape(.rect(cornerRadius: Theme.Radius.xs))
                .buttonStyle(.plain)
                .accessibilityLabel("Accept friend request")

                Button("Decline") {
                    Haptics.light()
                    onDecline()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.destructive)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Theme.destructive.opacity(0.12))
                .clipShape(.rect(cornerRadius: Theme.Radius.xs))
                .buttonStyle(.plain)
                .accessibilityLabel("Decline friend request")
            }
        }
        .padding(.vertical, Theme.Spacing.tight)
    }
}

// MARK: - Outgoing Request Row

private struct OutgoingRequestRow: View {
    let request: FriendRow
    let addresseeProfile: ProfileRow?
    let onCancel: () -> Void

    @State private var showCancelDialog = false

    private var addresseeName: String {
        if let profile = addresseeProfile {
            return profile.displayName.isEmpty ? profile.username : profile.displayName
        }
        return String(request.addresseeId.prefix(8))
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            XomAvatar(name: addresseeName, size: 40)

            VStack(alignment: .leading, spacing: Theme.Spacing.tighter) {
                Text(addresseeName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                if let profile = addresseeProfile {
                    Text("@\(profile.username)")
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button("Cancel") {
                Haptics.light()
                showCancelDialog = true
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.destructive)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.destructive.opacity(0.12))
            .clipShape(.rect(cornerRadius: Theme.Radius.xs))
            .buttonStyle(.plain)
            .accessibilityLabel("Cancel outgoing friend request")
        }
        .padding(.vertical, Theme.Spacing.tight)
        .confirmationDialog(
            "Cancel friend request?",
            isPresented: $showCancelDialog,
            titleVisibility: .visible
        ) {
            Button("Cancel Request", role: .destructive) {
                Haptics.light()
                onCancel()
            }
            Button("Keep", role: .cancel) {}
        }
    }
}

// MARK: - Friend List Row

private struct FriendListRow: View {
    let friend: FriendRow
    let currentUserId: String
    let friendProfile: ProfileRow?
    let onRemove: () -> Void

    private var friendName: String {
        if let profile = friendProfile {
            return profile.displayName.isEmpty ? profile.username : profile.displayName
        }
        let friendId = friend.requesterId == currentUserId ? friend.addresseeId : friend.requesterId
        return String(friendId.prefix(8))
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            XomAvatar(name: friendName, size: 40)

            VStack(alignment: .leading, spacing: Theme.Spacing.tighter) {
                Text(friendName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                if let profile = friendProfile {
                    Text("@\(profile.username)")
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textTertiary)
                } else {
                    Text(friend.status == "accepted" ? "Friends" : "Pending")
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textTertiary)
                }
            }

            Spacer()
        }
        .padding(.vertical, Theme.Spacing.tight)
        .swipeActions(edge: .trailing) {
            Button("Remove", role: .destructive) {
                onRemove()
            }
        }
    }
}
