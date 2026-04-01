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
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.2))
                    .frame(width: 70, height: 70)
                Text(initials)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Theme.accent)
            }

            // Name
            VStack(spacing: 4) {
                if !displayName.isEmpty {
                    Text(displayName)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                }
                if !username.isEmpty {
                    Text("@\(username)")
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            // Lock icon + message
            VStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "lock.fill")
                    .font(.title)
                    .foregroundStyle(Theme.textSecondary)

                Text("This account is private")
                    .font(Theme.fontBody)
                    .foregroundStyle(Theme.textSecondary)

                Text("Send a friend request to see their activity.")
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Action button
            if friendshipStatus == .none {
                Button(action: onSendRequest) {
                    Text("Send Friend Request")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.background)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Theme.accent)
                        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .accessibilityLabel("Send friend request to \(displayName)")
            } else if friendshipStatus == .pending {
                Text("Friend Request Sent")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Theme.surface)
                    .clipShape(.rect(cornerRadius: Theme.cornerRadius))
                    .padding(.horizontal, Theme.Spacing.lg)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
