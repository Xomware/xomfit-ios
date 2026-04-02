import SwiftUI

struct NotificationInboxView: View {
    @Environment(\.dismiss) private var dismiss
    private let service = NotificationService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                if service.notifications.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(service.notifications) { notification in
                            NotificationRow(notification: notification)
                                .onTapGesture {
                                    service.markAsRead(notification.id)
                                }
                                .listRowBackground(
                                    notification.isRead ? Theme.surface : Theme.accent.opacity(0.06)
                                )
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
                ToolbarItem(placement: .primaryAction) {
                    if !service.notifications.isEmpty {
                        Menu {
                            Button {
                                service.markAllAsRead()
                            } label: {
                                Label("Mark All as Read", systemImage: "checkmark.circle")
                            }
                            Button(role: .destructive) {
                                service.clearAll()
                            } label: {
                                Label("Clear All", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "bell.slash")
                .font(.system(size: 40))
                .foregroundStyle(Theme.textSecondary)
            Text("No notifications yet")
                .font(Theme.fontHeadline)
                .foregroundStyle(Theme.textPrimary)
            Text("You'll see likes, comments, friend requests, and more here.")
                .font(Theme.fontBody)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Theme.Spacing.lg)
    }
}

// MARK: - Notification Row

private struct NotificationRow: View {
    let notification: AppNotification

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: notification.type.icon)
                .font(.body)
                .foregroundStyle(iconColor)
                .frame(width: 36, height: 36)
                .background(iconColor.opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(notification.title)
                    .font(.subheadline.weight(notification.isRead ? .regular : .semibold))
                    .foregroundStyle(Theme.textPrimary)

                if !notification.body.isEmpty {
                    Text(notification.body)
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                }

                Text(notification.createdAt.timeAgo)
                    .font(Theme.fontSmall)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            if !notification.isRead {
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 4)
    }

    private var iconColor: Color {
        switch notification.type {
        case .friendRequest, .friendAccepted: return Theme.accent
        case .like: return Theme.destructive
        case .comment: return Theme.badgeWorkout
        case .newPR: return Theme.prGold
        case .streakMilestone: return Theme.badgeStreak
        case .friendWorkout: return Theme.badgeMilestone
        }
    }
}
