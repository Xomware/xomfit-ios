import SwiftUI

struct ProfileHeaderView: View {
    let displayName: String
    let username: String
    let bio: String
    let initials: String
    let isPrivate: Bool
    let isOwnProfile: Bool
    let feedItemCount: Int
    let friendCount: Int
    let prCount: Int
    let friendshipStatus: ProfileFriendshipStatus
    let friends: [FriendRow]
    let friendProfiles: [String: ProfileRow]
    let currentUserId: String
    let onStatTapped: (ProfileTab) -> Void
    let onActionTapped: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Top row: avatar + stats
            HStack(alignment: .center, spacing: Theme.Spacing.md) {
                XomAvatar(name: displayName.isEmpty ? username : displayName, size: 72)
                    .accessibilityLabel("Profile avatar")

                HStack(spacing: Theme.Spacing.sm) {
                    statColumn(value: feedItemCount, label: "Posts") {
                        onStatTapped(.feed)
                    }
                    NavigationLink {
                        FriendsListView(
                            friends: friends,
                            friendProfiles: friendProfiles,
                            currentUserId: currentUserId
                        )
                        .hideTabBar()
                    } label: {
                        VStack(spacing: 2) {
                            Text("\(friendCount)")
                                .font(Theme.fontNumberLarge)
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                            XomMetricLabel("Friends")
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(friendCount) Friends")
                    .accessibilityAddTraits(.isButton)

                    statColumn(value: prCount, label: "PRs") {
                        onStatTapped(.stats)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            // Name + username + bio
            VStack(alignment: .leading, spacing: 4) {
                if !displayName.isEmpty {
                    Text(displayName)
                        .font(Theme.fontTitle2)
                        .foregroundStyle(Theme.textPrimary)
                }

                if !username.isEmpty {
                    Text("@\(username)")
                        .font(Theme.fontSubheadline)
                        .foregroundStyle(Theme.textTertiary)
                }

                if !bio.isEmpty {
                    Text(bio)
                        .font(Theme.fontBody)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(4)
                        .truncationMode(.tail)
                        .padding(.top, 2)
                }

                if isPrivate && isOwnProfile {
                    XomBadge("Private Account", icon: "lock.fill", variant: .secondary)
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Action button
            actionButton
        }
        .padding(Theme.Spacing.md)
    }

    // MARK: - Stat Column

    private func statColumn(value: Int, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text("\(value)")
                    .font(Theme.fontNumberLarge)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                XomMetricLabel(label)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(value) \(label)")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Action Button

    private var actionButton: some View {
        Group {
            if isOwnProfile {
                XomButton("Edit Profile", variant: .secondary, action: {
                    Haptics.light()
                    onActionTapped()
                })
            } else {
                switch friendshipStatus {
                case .none:
                    XomButton("Add Friend", variant: .primary, icon: "person.badge.plus", action: {
                        Haptics.light()
                        onActionTapped()
                    })
                case .pending:
                    XomButton("Requested", variant: .ghost, action: {
                        Haptics.light()
                        onActionTapped()
                    })
                case .friends:
                    XomButton("Friends", variant: .secondary, icon: "checkmark", action: {
                        Haptics.light()
                        onActionTapped()
                    })
                }
            }
        }
    }
}
