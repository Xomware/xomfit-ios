import SwiftUI

/// SoundCloud connection block embedded in `SettingsView` -> Music Sources (#389).
///
/// Mirrors `SpotifyConnectionView`'s shape and visual language. Two differences from Spotify:
///
///   1. No client-id paste field. XomFit ships a shared client id, so the user only has
///      to tap "Sign In with SoundCloud".
///   2. SoundCloud's developer program has been intermittently closed to new apps. If the
///      shared client id is rejected we surface a clear `apiClosed` error inline so the
///      user knows it's not their fault and capture from Apple Music / Spotify keeps working.
struct SoundCloudConnectionView: View {
    @State private var soundCloudAuth = SoundCloudAuthService.shared

    @State private var isSigningIn: Bool = false
    @State private var errorMessage: String? = nil

    /// Observable mirror of the SoundCloud capture loop. Drives the "last captured track"
    /// line + the active-polling pulse indicator on the header.
    @State private var soundCloudCapture = SoundCloudNowPlayingService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            header

            // Surface the most recent capture, if any, so the user can confirm capture is
            // working without opening an active workout.
            if soundCloudAuth.isAuthenticated, let last = soundCloudCapture.lastCapturedTrack {
                lastCapturedRow(track: last)
            }

            actionButton

            if let errorMessage {
                Text(errorMessage)
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.destructive)
                    .accessibilityLabel("SoundCloud error: \(errorMessage)")
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    // MARK: - Subviews

    private var header: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "cloud.fill")
                .frame(width: Theme.Spacing.lg)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("SoundCloud")
                    .foregroundStyle(Theme.textPrimary)
                Text(soundCloudAuth.isAuthenticated
                     ? "Connected\(soundCloudAuth.displayName.isEmpty ? "" : " as \(soundCloudAuth.displayName)")"
                     : "Not connected")
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textTertiary)
                    .accessibilityLabel(soundCloudAuth.isAuthenticated ? "SoundCloud connected" : "SoundCloud not connected")
            }
            Spacer()
            // Live polling indicator. Visible only while a workout is in progress AND the
            // poll loop is alive.
            if soundCloudCapture.isCapturing {
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
            .accessibilityLabel("SoundCloud capture in progress")
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

    @ViewBuilder
    private var actionButton: some View {
        if soundCloudAuth.isAuthenticated {
            Button(role: .destructive) {
                Haptics.selection()
                soundCloudAuth.signOut()
            } label: {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .frame(width: Theme.Spacing.lg)
                        .foregroundStyle(Theme.destructive)
                    Text("Disconnect SoundCloud")
                        .foregroundStyle(Theme.destructive)
                }
            }
            .accessibilityHint("Removes SoundCloud access and stops capturing tracks")
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
                    Text(isSigningIn ? "Connecting..." : "Sign In with SoundCloud")
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            .disabled(isSigningIn)
            .accessibilityHint("Opens the SoundCloud login web view")
        }
    }

    // MARK: - Actions

    private func signIn() async {
        guard !isSigningIn else { return }
        isSigningIn = true
        errorMessage = nil
        defer { isSigningIn = false }
        do {
            _ = try await soundCloudAuth.signIn()
            Haptics.selection()
        } catch let err as SoundCloudAuthError {
            errorMessage = err.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
