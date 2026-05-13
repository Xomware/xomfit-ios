import SwiftUI

// MARK: - AppDestination
//
// Top-level navigation surfaces reachable from the hamburger drawer (#372).
// Replaces the previous 4-tab `FloatingTabBar`. Each case carries its title
// (shown in the shell top bar + drawer row) and SF Symbol icon.

enum AppDestination: String, CaseIterable, Identifiable, Hashable {
    case feed
    case workout
    case progress
    case profile
    case reports
    case tools
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .feed:     "Feed"
        case .workout:  "Workout"
        case .progress: "Progress"
        case .profile:  "Profile"
        case .reports:  "Reports"
        case .tools:    "Tools"
        case .settings: "Settings"
        }
    }

    var iconSystemName: String {
        switch self {
        case .feed:     "house.fill"
        case .workout:  "dumbbell.fill"
        case .progress: "chart.line.uptrend.xyaxis"
        case .profile:  "person.fill"
        case .reports:  "doc.text.fill"
        case .tools:    "wrench.and.screwdriver.fill"
        case .settings: "gearshape.fill"
        }
    }
}

// MARK: - AppDrawer
//
// Left-edge drawer surface presented by `MainTabView` (a.k.a. MainShell). The
// drawer renders a profile header (avatar + display name + @username), one
// tappable row per `AppDestination`, and a sign-out CTA at the bottom.
//
// All interaction is forwarded to the shell:
// - `onSelect`: user tapped a destination row.
// - `onSignOut`: user tapped Sign Out.
// - `onClose`: user tapped the header close affordance (X).

struct AppDrawer: View {
    let displayName: String
    let username: String
    let avatarURL: URL?
    let activeDestination: AppDestination
    let onSelect: (AppDestination) -> Void
    let onSignOut: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.md)

            Divider()
                .overlay(Theme.hairline)

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    ForEach(AppDestination.allCases) { destination in
                        drawerRow(for: destination)
                    }
                }
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.top, Theme.Spacing.md)
            }

            Spacer(minLength: 0)

            Divider()
                .overlay(Theme.hairline)

            signOutButton
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            Theme.surface
                .ignoresSafeArea()
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Theme.Spacing.md) {
            XomAvatar(name: displayName.isEmpty ? username : displayName, size: 56, imageURL: avatarURL)

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName.isEmpty ? username : displayName)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                if !username.isEmpty {
                    Text("@\(username)")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Button {
                Haptics.light()
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Close drawer")
        }
    }

    // MARK: - Destination Row

    private func drawerRow(for destination: AppDestination) -> some View {
        let isActive = destination == activeDestination
        return Button {
            Haptics.selection()
            onSelect(destination)
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: destination.iconSystemName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isActive ? Theme.accent : Theme.textSecondary)
                    .frame(width: 28, height: 28)

                Text(destination.title)
                    .font(.body.weight(isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? Theme.textPrimary : Theme.textPrimary.opacity(0.9))

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .frame(minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(isActive ? Theme.accentMuted : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(destination.title)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }

    // MARK: - Sign Out

    private var signOutButton: some View {
        Button {
            Haptics.medium()
            onSignOut()
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.destructive)
                    .frame(width: 28, height: 28)

                Text("Sign Out")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.destructive)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Theme.Spacing.sm)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Sign out")
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Drawer — open") {
    AppDrawer(
        displayName: "Debug User",
        username: "debug_user",
        avatarURL: nil,
        activeDestination: .feed,
        onSelect: { _ in },
        onSignOut: {},
        onClose: {}
    )
    .frame(width: 300)
    .background(Theme.background)
    .preferredColorScheme(.dark)
}
#endif
