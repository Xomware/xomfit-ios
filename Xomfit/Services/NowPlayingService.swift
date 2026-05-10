import Foundation
import MediaPlayer

/// Polls `MPMusicPlayerController.systemMusicPlayer` during an active workout to capture
/// the songs the user listens to and attaches them to the saved `Workout`.
///
/// ## iOS platform limitation (read this before extending)
///
/// iOS does NOT expose other apps' Now Playing metadata to third-party apps:
/// - `MPNowPlayingInfoCenter.default()` is only readable by the OWNING audio app.
/// - `MPRemoteCommandCenter` notifications carry no cross-app metadata.
/// - `MPMusicPlayerController.systemMusicPlayer` only reflects Apple Music / iTunes Match.
///
/// The only legal capture target is therefore Apple Music. Spotify, Xomify, podcast apps,
/// and YouTube Music will NOT appear in captured tracks. That's a hard iOS restriction —
/// the only workarounds are (a) being the audio app yourself, or (b) private API
/// (rejected at App Review). v1 ships the Apple Music capture only.
@MainActor
final class NowPlayingService {
    static let shared = NowPlayingService()

    /// 30s polling cadence — frequent enough to catch song changes, cheap enough to avoid wakelock pressure.
    private let pollInterval: TimeInterval = 30

    /// Accumulated tracks for the current capture session, deduped by `dedupeKey`.
    private var captured: [WorkoutTrack] = []
    private var seenKeys: Set<String> = []
    private var pollTask: Task<Void, Never>?
    private var isAuthorized: Bool = false

    private init() {}

    // MARK: - Authorization

    /// Triggers the system Apple Music auth prompt the first time. Subsequent calls
    /// are cheap — they just refresh the cached `isAuthorized` flag.
    func ensureAuthorization() async {
        let status = MPMediaLibrary.authorizationStatus()
        switch status {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            let result = await withCheckedContinuation { (continuation: CheckedContinuation<MPMediaLibraryAuthorizationStatus, Never>) in
                MPMediaLibrary.requestAuthorization { status in
                    continuation.resume(returning: status)
                }
            }
            isAuthorized = (result == .authorized)
        case .denied, .restricted:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }
    }

    // MARK: - Capture Lifecycle

    /// Begins polling. Idempotent — safe to call repeatedly. If auth was denied, this is a no-op.
    func startCapture() {
        // Reset session state up-front so a back-to-back start clears prior captures
        captured.removeAll()
        seenKeys.removeAll()
        pollTask?.cancel()

        // Kick off auth check + first poll. If auth lands on denied, the polling loop
        // will simply observe the auth flag and exit — no nag, no UI.
        pollTask = Task { [weak self] in
            guard let self else { return }
            await self.ensureAuthorization()
            // Capture immediately so a song already playing at workout start is recorded.
            self.captureCurrentTrack()

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(self.pollInterval * 1_000_000_000))
                if Task.isCancelled { return }
                self.captureCurrentTrack()
            }
        }
    }

    /// Stops polling and returns the captured list. Clears internal state so the next
    /// `startCapture()` begins fresh.
    @discardableResult
    func stopCapture() -> [WorkoutTrack] {
        pollTask?.cancel()
        pollTask = nil
        let result = captured
        captured.removeAll()
        seenKeys.removeAll()
        return result
    }

    // MARK: - Polling

    /// Reads `systemMusicPlayer.nowPlayingItem` once. No-op when:
    ///   - Apple Music auth is denied
    ///   - Nothing is playing via Apple Music (Spotify/podcasts/etc. won't surface here)
    ///   - The current track was already captured (deduped by title+artist+persistentID)
    private func captureCurrentTrack() {
        guard isAuthorized else { return }
        guard let item = MPMusicPlayerController.systemMusicPlayer.nowPlayingItem else { return }
        guard let title = item.title, !title.isEmpty else { return }

        let key = dedupeKey(title: title, artist: item.artist, persistentID: item.persistentID)
        guard !seenKeys.contains(key) else { return }
        seenKeys.insert(key)

        let track = WorkoutTrack(
            title: title,
            artist: item.artist,
            album: item.albumTitle,
            capturedAt: Date(),
            sourceApp: "Apple Music"
        )
        captured.append(track)
    }

    private func dedupeKey(title: String, artist: String?, persistentID: MPMediaEntityPersistentID) -> String {
        // persistentID == 0 for some streamed / radio items — fall back to title+artist alone in that case.
        let pid = persistentID == 0 ? "" : String(persistentID)
        return "\(title.lowercased())|\(artist?.lowercased() ?? "")|\(pid)"
    }
}
