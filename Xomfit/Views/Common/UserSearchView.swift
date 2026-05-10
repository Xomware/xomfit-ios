import SwiftUI

struct UserSearchView: View {
    @Environment(AuthService.self) private var authService
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [ProfileRow] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    private var currentUserId: String {
        authService.currentUser?.id.uuidString.lowercased() ?? ""
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    searchBar
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)

                    if isSearching {
                        VStack(spacing: Theme.Spacing.sm) {
                            ForEach(0..<5, id: \.self) { _ in
                                SkeletonCard(height: 56)
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.top, Theme.Spacing.md)
                        Spacer()
                    } else if results.isEmpty && !query.isEmpty {
                        Spacer()
                        noResultsView
                        Spacer()
                    } else if results.isEmpty {
                        Spacer()
                        emptyState
                        Spacer()
                    } else {
                        resultsList
                    }
                }
            }
            .navigationTitle("Search Users")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.textSecondary)
                .font(Theme.fontBody)

            TextField("Search by username", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(Theme.textPrimary)

            if !query.isEmpty {
                Button {
                    query = ""
                    results = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.textSecondary)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(12)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
        .onChange(of: query) { _, newValue in
            searchTask?.cancel()
            guard !newValue.isEmpty else {
                results = []
                isSearching = false
                return
            }
            searchTask = Task {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                await performSearch(newValue)
            }
        }
    }

    // MARK: - Results List

    private var resultsList: some View {
        List {
            ForEach(results, id: \.id) { profile in
                NavigationLink {
                    ProfileView(userId: profile.id)
                } label: {
                    userRow(profile)
                }
                .listRowBackground(Theme.surface)
                .listRowSeparatorTint(Theme.textSecondary.opacity(0.2))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - User Row

    private func userRow(_ profile: ProfileRow) -> some View {
        HStack(spacing: 12) {
            // Avatar circle with initials
            initialsAvatar(profile)

            VStack(alignment: .leading, spacing: Theme.Spacing.tighter) {
                Text(profile.displayName.isEmpty ? profile.username : profile.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("@\(profile.username)")
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()
        }
        .padding(.vertical, Theme.Spacing.tight)
        .accessibilityElement(children: .combine)
    }

    private func initialsAvatar(_ profile: ProfileRow) -> some View {
        let name = profile.displayName.isEmpty ? profile.username : profile.displayName
        let parts = name.split(separator: " ")
        let initials: String
        if parts.count >= 2 {
            initials = String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        } else {
            initials = String(name.prefix(2)).uppercased()
        }

        return Text(initials)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Theme.accent)
            .frame(width: 40, height: 40)
            .background(Theme.accent.opacity(0.15))
            .clipShape(Circle())
    }

    // MARK: - Empty / No Results

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(Theme.fontLargeTitle)
                .foregroundStyle(Theme.textSecondary)
            Text("Search for users by username")
                .font(Theme.fontBody)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var noResultsView: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "person.slash")
                .font(Theme.fontLargeTitle)
                .foregroundStyle(Theme.textSecondary)
            Text("No users found")
                .font(Theme.fontBody)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: - Search

    private func performSearch(_ searchQuery: String) async {
        isSearching = true
        do {
            let rows = try await FriendsService.shared.searchUsers(
                query: searchQuery,
                excludeUserId: currentUserId
            )
            if !Task.isCancelled {
                results = rows
            }
        } catch {
            if !Task.isCancelled {
                results = []
            }
        }
        if !Task.isCancelled {
            isSearching = false
        }
    }
}
