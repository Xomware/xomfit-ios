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
    let relation: FriendshipRelation
    let friends: [FriendRow]
    let friendProfiles: [String: ProfileRow]
    let currentUserId: String
    let onStatTapped: (ProfileTab) -> Void
    let onEditProfile: () -> Void
    let onAddFriend: () -> Void
    let onCancelRequest: () -> Void
    let onAcceptRequest: () -> Void
    let onDeclineRequest: () -> Void
    let onRemoveFriend: () -> Void
    /// Pull-to-refresh hook for the friends list child view. Optional — when
    /// nil the friends list won't show a refresh control.
    var onRefreshFriends: (() async -> Void)? = nil

    @State private var showCancelDialog = false
    @State private var showRemoveDialog = false

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
                            currentUserId: currentUserId,
                            onRefresh: onRefreshFriends
                        )
                        .hideTabBar()
                    } label: {
                        VStack(spacing: Theme.Spacing.tighter) {
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
            VStack(alignment: .leading, spacing: Theme.Spacing.tight) {
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
                        .padding(.top, Theme.Spacing.tighter)
                }

                if isPrivate && isOwnProfile {
                    XomBadge("Private Account", icon: "lock.fill", variant: .secondary)
                        .padding(.top, Theme.Spacing.tight)
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
            VStack(spacing: Theme.Spacing.tighter) {
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
                XomButton("Edit Profile", variant: .secondary) {
                    Haptics.light()
                    onEditProfile()
                }
            } else {
                switch relation {
                case .none:
                    XomButton("Add Friend", variant: .primary, icon: "person.badge.plus") {
                        Haptics.light()
                        onAddFriend()
                    }

                case .outgoingPending:
                    XomButton("Sent", variant: .ghost) {
                        Haptics.light()
                        showCancelDialog = true
                    }
                    .confirmationDialog(
                        "Cancel friend request?",
                        isPresented: $showCancelDialog,
                        titleVisibility: .visible
                    ) {
                        Button("Cancel Request", role: .destructive) {
                            onCancelRequest()
                        }
                        Button("Keep", role: .cancel) {}
                    }

                case .incomingPending:
                    VStack(spacing: Theme.Spacing.sm) {
                        XomButton("Accept", variant: .primary, icon: "checkmark") {
                            Haptics.light()
                            onAcceptRequest()
                        }
                        XomButton("Decline", variant: .ghost) {
                            Haptics.light()
                            onDeclineRequest()
                        }
                    }

                case .friends:
                    XomButton("Friends", variant: .secondary, icon: "checkmark") {
                        Haptics.light()
                        showRemoveDialog = true
                    }
                    .confirmationDialog(
                        "Remove friend?",
                        isPresented: $showRemoveDialog,
                        titleVisibility: .visible
                    ) {
                        Button("Remove Friend", role: .destructive) {
                            onRemoveFriend()
                        }
                        Button("Keep", role: .cancel) {}
                    }

                case .blocked:
                    XomButton("Unavailable", variant: .ghost) {}
                        .disabled(true)
                }
            }
        }
    }
}
