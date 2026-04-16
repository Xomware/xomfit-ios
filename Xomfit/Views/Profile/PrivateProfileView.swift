import SwiftUI

struct PrivateProfileView: View {
    let displayName: String
    let username: String
    let initials: String
    let friendshipStatus: ProfileFriendshipStatus
    let onSendRequest: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            // Avatar
            XomAvatar(name: displayName.isEmpty ? username : initials, size: 80)

            // Name
            VStack(spacing: 4) {
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
            }

            // Lock icon + message
            VStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)

                Text("This account is private")
                    .font(Theme.fontHeadline)
                    .foregroundStyle(Theme.textPrimary)

                Text("Send a friend request to see their activity.")
                    .font(Theme.fontBody)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Action button
            if friendshipStatus == .none {
                XomButton("Send Friend Request", variant: .primary, icon: "person.badge.plus") {
                    onSendRequest()
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .accessibilityLabel("Send friend request to \(displayName)")
            } else if friendshipStatus == .pending {
                XomButton("Request Sent", variant: .ghost) {}
                    .disabled(true)
                    .padding(.horizontal, Theme.Spacing.lg)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
