import SwiftUI

struct ProfileFriendsView: View {
    let friends: [FriendRow]
    let friendProfiles: [String: ProfileRow]
    let currentUserId: String

    private func otherUserId(_ friend: FriendRow) -> String {
        friend.requesterId == currentUserId ? friend.addresseeId : friend.requesterId
    }

    var body: some View {
        if friends.isEmpty {
            emptyState
        } else {
            LazyVStack(spacing: 0) {
                ForEach(friends) { friend in
                    NavigationLink {
                        ProfileView(userId: otherUserId(friend))
                            .hideTabBar()
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
            .background(Theme.surface)
            .clipShape(.rect(cornerRadius: Theme.cornerRadius))
            .padding(.horizontal, Theme.Spacing.md)
        }
    }

    // MARK: - Friend Row

    private func friendRow(friend: FriendRow) -> some View {
        let profile = friendProfiles[otherUserId(friend)]
        let name = profile?.displayName ?? otherUserId(friend)
        let username = profile?.username ?? ""
        let initials = friendInitials(name: name, fallback: username)

        return HStack(spacing: Theme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.2))
                    .frame(width: 40, height: 40)
                Text(initials)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                if !username.isEmpty {
                    Text("@\(username)")
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(Theme.Spacing.md)
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name)\(username.isEmpty ? "" : ", @\(username)")")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "person.2")
                .font(.largeTitle)
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
