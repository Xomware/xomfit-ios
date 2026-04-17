import SwiftUI

struct PrivateProfileView: View {
    let displayName: String
    let username: String
    let initials: String
    let relation: FriendshipRelation
    let onAddFriend: () -> Void
    let onCancelRequest: () -> Void
    let onAcceptRequest: () -> Void
    let onDeclineRequest: () -> Void

    @State private var showCancelDialog = false

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

            // Action button — direction-aware
            switch relation {
            case .none:
                XomButton("Send Friend Request", variant: .primary, icon: "person.badge.plus") {
                    Haptics.light()
                    onAddFriend()
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .accessibilityLabel("Send friend request to \(displayName)")

            case .outgoingPending:
                XomButton("Request Sent", variant: .ghost) {
                    Haptics.light()
                    showCancelDialog = true
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .confirmationDialog(
                    "Cancel friend request?",
                    isPresented: $showCancelDialog,
                    titleVisibility: .visible
                ) {
                    Button("Cancel Request", role: .destructive) { onCancelRequest() }
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
                .padding(.horizontal, Theme.Spacing.lg)

            case .friends:
                // Shouldn't be reachable (private gate passes if friends) — defensive
                XomButton("Friends", variant: .secondary, icon: "checkmark") {}
                    .disabled(true)
                    .padding(.horizontal, Theme.Spacing.lg)

            case .blocked:
                XomButton("Unavailable", variant: .ghost) {}
                    .disabled(true)
                    .padding(.horizontal, Theme.Spacing.lg)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
