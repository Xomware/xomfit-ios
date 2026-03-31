import SwiftUI

struct FriendsView: View {
    @Environment(AuthService.self) private var authService

    @State private var friends: [FriendRow] = []
    @State private var pendingRequests: [FriendRow] = []
    @State private var searchResults: [ProfileRow] = []
    @State private var searchQuery = ""
    @State private var isSearching = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?
    @State private var requesterProfiles: [String: ProfileRow] = [:]
    @State private var friendProfiles: [String: ProfileRow] = [:]

    private var userId: String {
        authService.currentUser?.id.uuidString ?? ""
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Search bar
                searchBar

                if isLoading {
                    Spacer()
                    XomFitLoaderPulse()
                    Spacer()
                } else {
                    List {
                        // Search results (shown when querying)
                        if !searchQuery.isEmpty {
                            searchResultsSection
                        } else {
                            // Pending requests
                            if !pendingRequests.isEmpty {
                                pendingRequestsSection
                            }
                            // Friends list
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
        .onAppear { loadData() }
        .refreshable { loadData() }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Theme.textSecondary)
            TextField("Search by username", text: $searchQuery)
                .foregroundColor(Theme.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: searchQuery) { _, newValue in
                    searchTask?.cancel()
                    guard !newValue.isEmpty else {
                        searchResults = []
                        return
                    }
                    searchTask = Task {
                        // Small debounce
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        guard !Task.isCancelled else { return }
                        await performSearch(query: newValue)
                    }
                }
            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                    searchResults = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
        .padding(Theme.paddingSmall)
        .padding(.horizontal, Theme.paddingSmall)
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadiusSmall)
        .padding(.horizontal, Theme.paddingMedium)
        .padding(.vertical, Theme.paddingSmall)
    }

    // MARK: - Sections

    @ViewBuilder
    private var searchResultsSection: some View {
        Section {
            if isSearching {
                HStack {
                    Spacer()
                    ProgressView().tint(Theme.accent)
                    Spacer()
                }
                .listRowBackground(Theme.cardBackground)
            } else if searchResults.filter({ $0.id != userId }).isEmpty {
                Text("No users found for \"\(searchQuery)\"")
                    .foregroundColor(Theme.textSecondary)
                    .font(Theme.fontBody)
                    .listRowBackground(Theme.cardBackground)
            } else {
                ForEach(searchResults.filter { $0.id != userId }, id: \.id) { profile in
                    SearchResultRow(
                        profile: profile,
                        isCurrentUser: false
                    ) {
                        sendRequest(toUserId: profile.id)
                    }
                    .listRowBackground(Theme.cardBackground)
                }
            }
        } header: {
            Text("Search Results")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
                .textCase(nil)
        }
    }

    @ViewBuilder
    private var pendingRequestsSection: some View {
        Section {
            ForEach(pendingRequests, id: \.id) { request in
                PendingRequestRow(
                    request: request,
                    requesterProfile: requesterProfiles[request.requesterId],
                    onAccept: { acceptRequest(request) },
                    onDecline: { declineRequest(request) }
                )
                .listRowBackground(Theme.cardBackground)
            }
        } header: {
            Text("Friend Requests")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.accent)
                .textCase(nil)
        }
    }

    @ViewBuilder
    private var friendsSection: some View {
        Section {
            if friends.isEmpty {
                Text("No friends yet. Search to add people!")
                    .foregroundColor(Theme.textSecondary)
                    .font(Theme.fontBody)
                    .listRowBackground(Theme.cardBackground)
            } else {
                ForEach(friends, id: \.id) { friend in
                    let friendId = friend.requesterId == userId ? friend.addresseeId : friend.requesterId
                    FriendListRow(
                        friend: friend,
                        currentUserId: userId,
                        friendProfile: friendProfiles[friendId]
                    ) {
                        removeFriend(friend)
                    }
                    .listRowBackground(Theme.cardBackground)
                }
            }
        } header: {
            Text("Friends (\(friends.count))")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
                .textCase(nil)
        }
    }

    // MARK: - Data Loading

    private func loadData() {
        guard !userId.isEmpty else { return }
        isLoading = true
        Task {
            do {
                async let friendsResult = FriendsService.shared.fetchFriends(userId: userId)
                async let pendingResult = FriendsService.shared.fetchPendingRequests(userId: userId)
                (friends, pendingRequests) = try await (friendsResult, pendingResult)

                // Fetch profiles for pending request senders
                for request in pendingRequests {
                    if requesterProfiles[request.requesterId] == nil {
                        if let profile = try? await ProfileService.shared.fetchProfile(userId: request.requesterId) {
                            requesterProfiles[request.requesterId] = profile
                        }
                    }
                }

                // Fetch profiles for friends
                for friend in friends {
                    let friendId = friend.requesterId == userId ? friend.addresseeId : friend.requesterId
                    if friendProfiles[friendId] == nil {
                        if let profile = try? await ProfileService.shared.fetchProfile(userId: friendId) {
                            friendProfiles[friendId] = profile
                        }
                    }
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func performSearch(query: String) async {
        isSearching = true
        do {
            searchResults = try await FriendsService.shared.searchUsers(query: query, excludeUserId: userId)
        } catch {
            searchResults = []
        }
        isSearching = false
    }

    private func sendRequest(toUserId: String) {
        Task {
            do {
                try await FriendsService.shared.sendFriendRequest(
                    fromUserId: userId,
                    toUserId: toUserId
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func acceptRequest(_ request: FriendRow) {
        Task {
            do {
                try await FriendsService.shared.acceptFriendRequest(friendshipId: request.id)
                pendingRequests.removeAll { $0.id == request.id }
                loadData()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func declineRequest(_ request: FriendRow) {
        Task {
            do {
                try await FriendsService.shared.declineFriendRequest(friendshipId: request.id)
                pendingRequests.removeAll { $0.id == request.id }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func removeFriend(_ friend: FriendRow) {
        Task {
            do {
                try await FriendsService.shared.removeFriend(friendshipId: friend.id)
                friends.removeAll { $0.id == friend.id }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Search Result Row

private struct SearchResultRow: View {
    let profile: ProfileRow
    let isCurrentUser: Bool
    let onAdd: () -> Void

    @State private var requested = false

    var body: some View {
        HStack(spacing: Theme.paddingMedium) {
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.2))
                    .frame(width: 40, height: 40)
                Text(String(profile.displayName.prefix(2)).uppercased())
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Text("@\(profile.username)")
                    .font(Theme.fontCaption)
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()

            if !isCurrentUser {
                Button {
                    requested = true
                    onAdd()
                } label: {
                    Text(requested ? "Sent" : "Add")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(requested ? Theme.textSecondary : .black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(requested ? Theme.cardBackground : Theme.accent)
                        .cornerRadius(Theme.cornerRadiusSmall)
                }
                .disabled(requested)
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Pending Request Row

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

    private var requesterInitials: String {
        let name = requesterName
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    var body: some View {
        HStack(spacing: Theme.paddingMedium) {
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.2))
                    .frame(width: 40, height: 40)
                Text(requesterInitials)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(requesterName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                if let profile = requesterProfile {
                    Text("@\(profile.username)")
                        .font(Theme.fontCaption)
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button("Accept") {
                    onAccept()
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Theme.accent)
                .cornerRadius(6)
                .buttonStyle(.plain)

                Button("Decline") {
                    onDecline()
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.destructive)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Theme.destructive.opacity(0.15))
                .cornerRadius(6)
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
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

    private var friendInitials: String {
        let name = friendName
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    var body: some View {
        HStack(spacing: Theme.paddingMedium) {
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.2))
                    .frame(width: 40, height: 40)
                Text(friendInitials)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(friendName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                if let profile = friendProfile {
                    Text("@\(profile.username)")
                        .font(Theme.fontCaption)
                        .foregroundColor(Theme.textSecondary)
                } else {
                    Text(friend.status == "accepted" ? "Friends" : "Pending")
                        .font(Theme.fontCaption)
                        .foregroundColor(Theme.textSecondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing) {
            Button("Remove", role: .destructive) {
                onRemove()
            }
        }
    }
}
