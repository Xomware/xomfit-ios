import SwiftUI
import UserNotifications
import MediaPlayer
import UIKit

/// Onboarding screen that requests Notifications + Apple Music permissions.
///
/// Both permissions are optional — users can re-enable them later from Settings.
/// The screen shows the live status (allowed / denied / not determined) so a
/// returning user who already granted one of these doesn't see a stale "Allow"
/// button.
struct OnboardingPermissionsScreen: View {
    let onContinue: () -> Void

    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var musicStatus: MPMediaLibraryAuthorizationStatus = .notDetermined
    @State private var isRequestingNotifications = false
    @State private var isRequestingMusic = false

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer().frame(height: Theme.Spacing.xl)

            // Header
            VStack(spacing: Theme.Spacing.sm) {
                Text("Get the most out of XomFit")
                    .font(Theme.fontTitle)
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Two quick permissions unlock the best parts of your workout.")
                    .font(Theme.fontSubheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.lg)
            }
            .staggeredAppear(index: 0)

            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    permissionCard(
                        icon: "bell.badge.fill",
                        title: "Notifications",
                        description: "Get a heads-up when your rest timer ends so you never miss a working set.",
                        status: notificationDisplayStatus,
                        isRequesting: isRequestingNotifications,
                        actionTitle: "Allow notifications",
                        onTap: requestNotifications
                    )
                    .staggeredAppear(index: 1)

                    permissionCard(
                        icon: "music.note",
                        title: "Apple Music",
                        description: "Capture the songs that played during your workout so you can revisit your soundtrack.",
                        status: musicDisplayStatus,
                        isRequesting: isRequestingMusic,
                        actionTitle: "Allow Apple Music",
                        onTap: requestMusic
                    )
                    .staggeredAppear(index: 2)
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }

            // CTA — proceeds whether or not permissions were granted.
            XomButton("Continue", action: onContinue)
                .padding(.horizontal, Theme.Spacing.lg)
                .staggeredAppear(index: 3)
        }
        .task {
            await refreshNotificationStatus()
            refreshMusicStatus()
        }
    }

    // MARK: - Status mapping

    private enum DisplayStatus {
        case notDetermined
        case allowed
        case denied
    }

    private var notificationDisplayStatus: DisplayStatus {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral: return .allowed
        case .denied: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    private var musicDisplayStatus: DisplayStatus {
        switch musicStatus {
        case .authorized: return .allowed
        case .denied, .restricted: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    // MARK: - Card

    @ViewBuilder
    private func permissionCard(
        icon: String,
        title: String,
        description: String,
        status: DisplayStatus,
        isRequesting: Bool,
        actionTitle: String,
        onTap: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 44, height: 44)
                    .background(Theme.accent.opacity(0.12))
                    .clipShape(Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)

                    Text(description)
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            statusActionView(
                status: status,
                isRequesting: isRequesting,
                actionTitle: actionTitle,
                onTap: onTap
            )
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .strokeBorder(Theme.hairline, lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private func statusActionView(
        status: DisplayStatus,
        isRequesting: Bool,
        actionTitle: String,
        onTap: @escaping () -> Void
    ) -> some View {
        switch status {
        case .notDetermined:
            XomButton(
                actionTitle,
                variant: .secondary,
                isLoading: isRequesting,
                action: onTap
            )

        case .allowed:
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.accent)
                Text("Allowed")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
            }
            .padding(.vertical, Theme.Spacing.sm)
            .padding(.horizontal, Theme.Spacing.md)
            .background(Theme.accent.opacity(0.12))
            .clipShape(.rect(cornerRadius: Theme.Radius.sm))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Allowed")

        case .denied:
            Button(action: openSettings) {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.alert)
                    Text("Denied — open Settings")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.vertical, Theme.Spacing.sm)
                .padding(.horizontal, Theme.Spacing.md)
                .background(Theme.alert.opacity(0.12))
                .clipShape(.rect(cornerRadius: Theme.Radius.sm))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Denied. Open Settings to enable.")
        }
    }

    // MARK: - Actions

    private func requestNotifications() {
        guard !isRequestingNotifications else { return }
        Haptics.light()
        isRequestingNotifications = true
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, _ in
            Task { @MainActor in
                isRequestingNotifications = false
                if granted {
                    notificationStatus = .authorized
                    Haptics.success()
                    UIApplication.shared.registerForRemoteNotifications()
                } else {
                    // Re-fetch the real status — the system may have shown the
                    // prompt and recorded a denial, or the prompt may have been
                    // skipped if the user previously denied.
                    await refreshNotificationStatus()
                }
            }
        }
    }

    private func requestMusic() {
        guard !isRequestingMusic else { return }
        Haptics.light()
        isRequestingMusic = true
        MPMediaLibrary.requestAuthorization { status in
            Task { @MainActor in
                isRequestingMusic = false
                musicStatus = status
                if status == .authorized {
                    Haptics.success()
                }
            }
        }
    }

    private func openSettings() {
        Haptics.light()
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Status refresh

    private func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationStatus = settings.authorizationStatus
    }

    private func refreshMusicStatus() {
        musicStatus = MPMediaLibrary.authorizationStatus()
    }
}

#Preview {
    OnboardingPermissionsScreen(onContinue: {})
        .background(Theme.background)
        .preferredColorScheme(.dark)
}
