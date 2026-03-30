import SwiftUI

struct PrivateProfileView: View {
    let displayName: String
    let username: String
    let initials: String
    let friendshipStatus: ProfileFriendshipStatus
    let onSendRequest: () -> Void

    var body: some View {
        VStack(spacing: Theme.paddingLarge) {
            Spacer()

            // Avatar
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.2))
                    .frame(width: 70, height: 70)
                Text(initials)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }

            // Name
            VStack(spacing: 4) {
                if !displayName.isEmpty {
                    Text(displayName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                }
                if !username.isEmpty {
                    Text("@\(username)")
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            // Lock icon + message
            VStack(spacing: Theme.paddingSmall) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 28))
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
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.background)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Theme.accent)
                        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
                }
                .padding(.horizontal, Theme.paddingLarge)
                .accessibilityLabel("Send friend request to \(displayName)")
            } else if friendshipStatus == .pending {
                Text("Friend Request Sent")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Theme.cardBackground)
                    .clipShape(.rect(cornerRadius: Theme.cornerRadius))
                    .padding(.horizontal, Theme.paddingLarge)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
