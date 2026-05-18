import SwiftUI

/// Spotify connection block embedded in `SettingsView` -> Music Sources (#347, #390).
///
/// Renders one of two modes:
///   - Signed out: a single "Sign In with Spotify" CTA — the Client ID is shipped with the app
///     so most users never need to think about it (#390).
///   - Signed in: connected display name + Disconnect button.
///
/// Power users can still bring their own Spotify Developer App by expanding the
/// "Advanced (override Client ID)" disclosure at the bottom.
///
/// Kept as its own view so `SettingsView` doesn't grow another 80 lines of music-source logic.
struct SpotifyConnectionView: View {
    @State private var spotifyAuth = SpotifyAuthService.shared

    /// Per-user override for the shared Client ID baked into `SpotifyConfig.sharedClientId`. The
    /// resolution rule lives in `SpotifyConfig.resolvedClientId()`; this binding only owns the
    /// text-field state. Most users leave this empty and it stays out of sight under Advanced.
    @AppStorage("spotifyClientId") private var clientIdOverride: String = ""

    /// Local UI state — whether the Advanced disclosure is expanded. Defaults to collapsed so the
    /// signed-out view stays a single-CTA experience.
    @State private var showAdvanced: Bool = false

    @State private var isSigningIn: Bool = false
    @State private var errorMessage: String? = nil

    /// Observable mirror of the Spotify capture loop. Drives the "last captured track"
    /// line + the active-polling pulse indicator on the header (Spotify capture polish).
    @State private var spotifyCapture = SpotifyNowPlayingService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            header

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

            // Advanced override lives at the bottom, collapsed by default. Keeps the main row a
            // single Sign In CTA for the 99% case (#390).
            advancedDisclosure
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

    /// Advanced (override Client ID) — collapsed by default. Power users who want to swap in
    /// their own Spotify Developer App can paste a Client ID here; an empty value falls back to
    /// the shared id baked into the app via `SpotifyConfig.resolvedClientId()` (#390).
    private var advancedDisclosure: some View {
        DisclosureGroup(isExpanded: $showAdvanced) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "key.fill")
                        .frame(width: Theme.Spacing.lg)
                        .foregroundStyle(Theme.accent)
                    SecureField("Override Spotify Client ID", text: $clientIdOverride)
                        .foregroundStyle(Theme.textPrimary)
                        .font(Theme.fontBody)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityLabel("Spotify Client ID override")
                        .accessibilityHint("Optional. Paste a Spotify Developer App client id to override the one shipped with XomFit.")
                }
                Text("Leave empty to use the Spotify app shipped with XomFit. Paste your own Client ID here to point sign-in at your personal Spotify Developer App.")
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.top, Theme.Spacing.xs)
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "wrench.adjustable")
                    .frame(width: Theme.Spacing.lg)
                    .foregroundStyle(Theme.textTertiary)
                Text("Advanced (override Client ID)")
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .accessibilityHint("Power users only. Override the Spotify Client ID that ships with XomFit.")
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
            // Primary CTA. Always enabled after #390 — the shared Client ID is baked into the
            // app so sign-in works out of the box; the override field (under Advanced) is
            // purely optional.
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
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            .disabled(isSigningIn)
            .accessibilityHint("Opens the Spotify login web view")
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
