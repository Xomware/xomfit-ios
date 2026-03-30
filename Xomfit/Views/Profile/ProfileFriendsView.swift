import SwiftUI

struct ProfileFriendsView: View {
    let friends: [FriendRow]
    let friendProfiles: [String: ProfileRow]

    var body: some View {
        if friends.isEmpty {
            emptyState
        } else {
            LazyVStack(spacing: 0) {
                ForEach(friends) { friend in
                    NavigationLink {
                        ProfileView(userId: friend.friendId)
                    } label: {
                        friendRow(friend: friend)
                    }
                    .buttonStyle(.plain)

                    if friend.id != friends.last?.id {
                        Divider()
                            .background(Theme.textSecondary.opacity(0.2))
                            .padding(.leading, 60)
                    }
                }
            }
            .background(Theme.cardBackground)
            .clipShape(.rect(cornerRadius: Theme.cornerRadius))
            .padding(.horizontal, Theme.paddingMedium)
        }
    }

    // MARK: - Friend Row

    private func friendRow(friend: FriendRow) -> some View {
        let profile = friendProfiles[friend.friendId]
        let name = profile?.displayName ?? friend.friendId
        let username = profile?.username ?? ""
        let initials = friendInitials(name: name, fallback: username)

        return HStack(spacing: Theme.paddingMedium) {
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.2))
                    .frame(width: 40, height: 40)
                Text(initials)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                if !username.isEmpty {
                    Text("@\(username)")
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(Theme.paddingMedium)
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name)\(username.isEmpty ? "" : ", @\(username)")")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Theme.paddingSmall) {
            Image(systemName: "person.2")
                .font(.system(size: 36))
                .foregroundStyle(Theme.textSecondary)
            Text("No friends yet")
                .font(Theme.fontBody)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No friends yet")
    }

    // MARK: - Helpers

    private func friendInitials(name: String, fallback: String) -> String {
        let source = name.isEmpty ? fallback : name
        let parts = source.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(source.prefix(2)).uppercased()
    }
}
