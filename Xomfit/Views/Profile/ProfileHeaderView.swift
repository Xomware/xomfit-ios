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
    let onStatTapped: (ProfileTab) -> Void
    let onActionTapped: () -> Void

    var body: some View {
        VStack(spacing: Theme.paddingMedium) {
            // Top row: avatar + stats
            HStack(alignment: .center, spacing: Theme.paddingLarge) {
                avatarCircle

                Spacer()

                statColumn(value: feedItemCount, label: "Posts") {
                    onStatTapped(.feed)
                }
                statColumn(value: friendCount, label: "Friends") {
                    onStatTapped(.friends)
                }
                statColumn(value: prCount, label: "PRs") {
                    onStatTapped(.stats)
                }

                Spacer()
            }
            .padding(.horizontal, Theme.paddingSmall)

            // Name + username + bio
            VStack(alignment: .leading, spacing: 4) {
                if !displayName.isEmpty {
                    Text(displayName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                }

                if !username.isEmpty {
                    Text("@\(username)")
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)
                }

                if !bio.isEmpty {
                    Text(bio)
                        .font(Theme.fontBody)
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.top, 2)
                }

                if isPrivate && isOwnProfile {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11))
                        Text("Private Account")
                            .font(Theme.fontSmall)
                    }
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Action button
            actionButton
        }
        .padding(Theme.paddingMedium)
    }

    // MARK: - Avatar

    private var avatarCircle: some View {
        ZStack {
            Circle()
                .fill(Theme.accent.opacity(0.2))
                .frame(width: 70, height: 70)
            Text(initials)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Theme.accent)
        }
        .accessibilityLabel("Profile avatar")
    }

    // MARK: - Stat Column

    private func statColumn(value: Int, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text("\(value)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(label)
                    .font(Theme.fontSmall)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(value) \(label)")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Action Button

    private var actionButton: some View {
        Button(action: onActionTapped) {
            Text(actionButtonLabel)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(actionButtonForeground)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(actionButtonBackground)
                .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(actionButtonLabel)
    }

    private var actionButtonLabel: String {
        if isOwnProfile { return "Edit Profile" }
        switch friendshipStatus {
        case .none: return "Add Friend"
        case .pending: return "Requested"
        case .friends: return "Friends"
        }
    }

    private var actionButtonForeground: Color {
        if isOwnProfile { return Theme.textPrimary }
        switch friendshipStatus {
        case .none: return Theme.background
        case .pending: return Theme.textSecondary
        case .friends: return Theme.accent
        }
    }

    private var actionButtonBackground: some ShapeStyle {
        if isOwnProfile { return AnyShapeStyle(Theme.cardBackground) }
        switch friendshipStatus {
        case .none: return AnyShapeStyle(Theme.accent)
        case .pending: return AnyShapeStyle(Theme.cardBackground)
        case .friends: return AnyShapeStyle(Theme.accent.opacity(0.15))
        }
    }
}
