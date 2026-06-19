import SwiftUI

struct NotificationInboxView: View {
    @Environment(\.dismiss) private var dismiss
    private let service = NotificationService.shared

    /// Current user id — used to fetch friend requests / feed / suggestions.
    let currentUserId: String?
    /// Invoked when the user taps a suggested-workout notification. The parent
    /// (MainTabView) dismisses the sheet, pre-seeds the generator, and switches
    /// to the Workout tab.
    let onStartSuggestion: (MuscleGroup) -> Void

    @State private var filter: NotificationFilter = .all
    @State private var route: NotifRoute?

    init(currentUserId: String?, onStartSuggestion: @escaping (MuscleGroup) -> Void) {
        self.currentUserId = currentUserId
        self.onStartSuggestion = onStartSuggestion
    }

    /// Notifications matching the active filter, newest first.
    private var visibleNotifications: [AppNotification] {
        guard filter != .all else { return service.notifications }
        return service.notifications.filter { $0.type.filter == filter }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    filterChips

                    if service.notifications.isEmpty {
                        emptyState
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if visibleNotifications.isEmpty {
                        filteredEmptyState
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(visibleNotifications) { notification in
                                Button {
                                    handleTap(notification)
                                } label: {
                                    NotificationRow(notification: notification)
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(
                                    notification.isRead ? Theme.surface : Theme.accent.opacity(0.06)
                                )
                            }
                        }
                        .listStyle(.plain)
                        .refreshable { await load() }
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationDestination(item: $route) { dest in
                switch dest {
                case .profile(let userId):
                    ProfileView(userId: userId)
                case .friends:
                    FriendsView()
                }
            }
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
            .overlay(alignment: .top) {
                if service.isRefreshing {
                    ProgressView()
                        .padding(.top, Theme.Spacing.sm)
                }
            }
        }
        .task { await load() }
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(NotificationFilter.allCases) { category in
                    let isSelected = filter == category
                    Button {
                        Haptics.selection()
                        withAnimation(.easeInOut(duration: 0.15)) { filter = category }
                    } label: {
                        HStack(spacing: 4) {
                            Text(category.title)
                            if category != .all {
                                let count = service.notifications.filter { $0.type.filter == category && !$0.isRead }.count
                                if count > 0 {
                                    Text("\(count)")
                                        .font(.caption2.weight(.black))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(isSelected ? Color.black.opacity(0.2) : Theme.accent.opacity(0.2))
                                        .clipShape(.capsule)
                                }
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? .black : Theme.textSecondary)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(isSelected ? Theme.accent : Theme.surface)
                        .clipShape(.capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(category.title) filter")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
        }
    }

    // MARK: - Empty States

    private var emptyState: some View {
        XomEmptyState(
            icon: "bell.slash",
            title: "No notifications yet",
            subtitle: "You'll see friend requests, friends' workouts, and workout suggestions here."
        )
    }

    private var filteredEmptyState: some View {
        XomEmptyState(
            icon: "line.3.horizontal.decrease.circle",
            title: "Nothing in \(filter.title)",
            subtitle: "Switch filters or pull to refresh."
        )
    }

    // MARK: - Actions

    private func load() async {
        guard let userId = currentUserId else { return }
        await service.refresh(currentUserId: userId)
    }

    private func handleTap(_ notification: AppNotification) {
        Haptics.light()
        service.markAsRead(notification.id)

        switch notification.type {
        case .suggestedWorkout:
            // targetId carries the muscle raw value — hand off to the generator.
            if let raw = notification.targetId, let muscle = MuscleGroup(rawValue: raw) {
                dismiss()
                onStartSuggestion(muscle)
            }
        case .friendRequest:
            route = .friends
        case .friendAccepted, .friendWorkout, .like, .comment, .newPR, .streakMilestone:
            if let senderId = notification.senderId {
                route = .profile(senderId)
            }
        }
    }
}

/// In-sheet navigation targets pushed from a notification tap.
private enum NotifRoute: Hashable {
    case profile(String)
    case friends
}

// MARK: - Notification Row

private struct NotificationRow: View {
    let notification: AppNotification

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: notification.type.icon)
                .font(Theme.fontBody)
                .foregroundStyle(iconColor)
                .frame(width: 36, height: 36)
                .background(iconColor.opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(notification.title)
                    .font(.subheadline.weight(notification.isRead ? .regular : .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.leading)

                if !notification.body.isEmpty {
                    Text(notification.body)
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Text(notification.createdAt.timeAgo)
                    .font(Theme.fontSmall)
                    .foregroundStyle(Theme.textTertiary)
            }

            Spacer(minLength: Theme.Spacing.sm)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.textTertiary)

            if !notification.isRead {
                Circle()
                    .fill(Theme.accent)
                    .frame(width: Theme.Spacing.sm, height: Theme.Spacing.sm)
            }
        }
        .padding(.vertical, Theme.Spacing.tight)
        .contentShape(Rectangle())
    }

    private var iconColor: Color {
        switch notification.type {
        case .friendRequest, .friendAccepted: return Theme.accent
        case .like: return Theme.destructive
        case .comment: return Theme.badgeWorkout
        case .newPR: return Theme.prGold
        case .streakMilestone: return Theme.badgeStreak
        case .friendWorkout: return Theme.badgeMilestone
        case .suggestedWorkout: return Theme.accent
        }
    }
}
