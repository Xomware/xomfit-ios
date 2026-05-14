import SwiftUI

/// Spotify connection block embedded in `SettingsView` -> Music Sources (#347).
///
/// Renders one of two modes:
///   - Signed out: client-id paste field + "Sign In with Spotify" button
///   - Signed in: connected display name + Sign Out button (paste field still visible so the
///     user can swap accounts without leaving Settings)
///
/// Kept as its own view so `SettingsView` doesn't grow another 80 lines of music-source logic.
struct SpotifyConnectionView: View {
    @State private var spotifyAuth = SpotifyAuthService.shared
    @AppStorage("spotifyClientId") private var clientId: String = ""

    @State private var isSigningIn: Bool = false
    @State private var errorMessage: String? = nil

    /// Observable mirror of the Spotify capture loop. Drives the "last captured track"
    /// line + the active-polling pulse indicator on the header (Spotify capture polish).
    @State private var spotifyCapture = SpotifyNowPlayingService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            header

            clientIdField

            // Surface the most recent capture, if any, so the user can confirm capture is
            // working without opening an active workout (Spotify capture polish).
            if spotifyAuth.isAuthenticated, let last = spotifyCapture.lastCapturedTrack {
                lastCapturedRow(track: last)
            }

            actionButton

            if let errorMessage {
                Text(errorMessage)
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.destructive)
                    .accessibilityLabel("Spotify error: \(errorMessage)")
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    // MARK: - Subviews

    private var header: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "music.note")
                .frame(width: Theme.Spacing.lg)
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("Spotify")
                    .foregroundStyle(Theme.textPrimary)
                Text(spotifyAuth.isAuthenticated
                     ? "Connected\(spotifyAuth.displayName.isEmpty ? "" : " as \(spotifyAuth.displayName)")"
                     : "Not connected")
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textTertiary)
                    .accessibilityLabel(spotifyAuth.isAuthenticated ? "Spotify connected" : "Spotify not connected")
            }
            Spacer()
            // Live polling indicator (Spotify capture polish). Visible only while a
            // workout is in progress AND the Spotify poll loop is alive.
            if spotifyCapture.isCapturing {
                pollingPulse
            }
        }
    }

    /// Tiny pulsing accent dot — communicates "capture is running right now".
    private var pollingPulse: some View {
        TimelineView(.animation(minimumInterval: 1.1, paused: false)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate
            let alpha = 0.45 + 0.55 * abs(sin(phase * 1.4))
            HStack(spacing: 4) {
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 8, height: 8)
                    .opacity(alpha)
                Text("Recording")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.accent)
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Spotify capture in progress")
        }
    }

    /// One-line "Last captured: Title — Artist" display so the user can confirm capture
    /// is working without finishing the workout.
    private func lastCapturedRow(track: WorkoutTrack) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "waveform")
                .frame(width: Theme.Spacing.lg)
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Last captured")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
                Text(track.artist?.isEmpty == false
                     ? "\(track.title) — \(track.artist ?? "")"
                     : track.title)
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Last captured: \(track.title)\(track.artist.map { ", by \($0)" } ?? "")")
    }

    private var clientIdField: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "key.fill")
                .frame(width: Theme.Spacing.lg)
                .foregroundStyle(Theme.accent)
            SecureField("Spotify Client ID", text: $clientId)
                .foregroundStyle(Theme.textPrimary)
                .font(Theme.fontBody)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityLabel("Spotify Client ID")
                .accessibilityHint("Paste the client id from your Spotify Developer Dashboard")
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if spotifyAuth.isAuthenticated {
            Button(role: .destructive) {
                Haptics.selection()
                spotifyAuth.signOut()
            } label: {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .frame(width: Theme.Spacing.lg)
                        .foregroundStyle(Theme.destructive)
                    Text("Disconnect Spotify")
                        .foregroundStyle(Theme.destructive)
                }
            }
            .accessibilityHint("Removes Spotify access and stops capturing tracks")
        } else {
            Button {
                Task { await signIn() }
            } label: {
                HStack(spacing: Theme.Spacing.md) {
                    if isSigningIn {
                        ProgressView().tint(Theme.accent)
                            .frame(width: Theme.Spacing.lg)
                    } else {
                        Image(systemName: "link")
                            .frame(width: Theme.Spacing.lg)
                            .foregroundStyle(Theme.accent)
                    }
                    Text(isSigningIn ? "Connecting..." : "Sign In with Spotify")
                        .foregroundStyle(clientId.trimmingCharacters(in: .whitespaces).isEmpty ? Theme.textTertiary : Theme.textPrimary)
                }
            }
            .disabled(isSigningIn || clientId.trimmingCharacters(in: .whitespaces).isEmpty)
            .accessibilityHint(clientId.isEmpty
                               ? "Paste a Spotify client id above first"
                               : "Opens the Spotify login web view")
        }
    }

    // MARK: - Actions

    private func signIn() async {
        guard !isSigningIn else { return }
        isSigningIn = true
        errorMessage = nil
        defer { isSigningIn = false }
        do {
            _ = try await spotifyAuth.signIn()
            Haptics.selection()
        } catch let err as SpotifyAuthError {
            errorMessage = err.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
