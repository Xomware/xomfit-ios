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
                    .simultaneousGesture(TapGesture().onEnded { Haptics.light() })

                    if friend.id != friends.last?.id {
                        XomDivider()
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

        return HStack(spacing: Theme.Spacing.md) {
            XomAvatar(name: name, size: 40)

            VStack(alignment: .leading, spacing: Theme.Spacing.tighter) {
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
                .font(Theme.fontLargeTitle)
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

}
