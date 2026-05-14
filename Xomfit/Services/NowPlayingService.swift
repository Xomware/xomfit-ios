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
@Observable
final class NowPlayingService {
    @ObservationIgnored static let shared = NowPlayingService()

    /// 30s polling cadence — frequent enough to catch song changes, cheap enough to avoid wakelock pressure.
    @ObservationIgnored private let pollInterval: TimeInterval = 30

    /// Accumulated tracks for the current capture session, deduped by `dedupeKey`.
    private var captured: [WorkoutTrack] = []
    @ObservationIgnored private var seenKeys: Set<String> = []
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private var isAuthorized: Bool = false

    /// Becomes true after the user explicitly denies Apple Music access. Used to suppress
    /// repeated `MPMediaLibrary.requestAuthorization` traffic and noisy logs across multiple
    /// `startCapture()` invocations within the same app launch — see `ensureAuthorization`.
    @ObservationIgnored private var deniedNoticed: Bool = false

    // MARK: - Observable surface (Spotify capture polish)

    /// True while the poll loop is alive AND auth is granted. Drives the active-workout
    /// "Recording soundtrack" pill. Reset by `stopCapture`.
    private(set) var isCapturing: Bool = false

    /// Number of unique tracks captured in the current session.
    var capturedCount: Int { captured.count }

    /// Most recent track captured this session (or the last completed session).
    private(set) var lastCapturedTrack: WorkoutTrack?

    private init() {}

    // MARK: - Authorization

    /// Triggers the system Apple Music auth prompt the first time. Subsequent calls
    /// are cheap — they just refresh the cached `isAuthorized` flag.
    ///
    /// When the user has previously denied access, this is a silent no-op after the first
    /// observation: we log once via `deniedNoticed` and never re-poke the system. The
    /// Soundtrack section on `WorkoutDetailView` already explains the limitation + steers
    /// the user toward Spotify as the alternative.
    func ensureAuthorization() async {
        let status = MPMediaLibrary.authorizationStatus()
        switch status {
        case .authorized:
            if !isAuthorized {
                print("[NowPlayingService] authorized — polling will run")
            }
            isAuthorized = true
        case .notDetermined:
            print("[NowPlayingService] not determined — requesting authorization")
            let result = await withCheckedContinuation { (continuation: CheckedContinuation<MPMediaLibraryAuthorizationStatus, Never>) in
                MPMediaLibrary.requestAuthorization { status in
                    continuation.resume(returning: status)
                }
            }
            isAuthorized = (result == .authorized)
            print("[NowPlayingService] authorization result: \(result.rawValue), isAuthorized=\(isAuthorized)")
            if result == .denied {
                // Mark deniedNoticed so subsequent startCapture invocations skip the noisy
                // "denied/restricted" branch logging without us re-prompting the system.
                deniedNoticed = true
            }
        case .denied, .restricted:
            isAuthorized = false
            if !deniedNoticed {
                print("[NowPlayingService] access denied/restricted — Apple Music capture disabled for this session; Spotify capture (if connected) still runs")
                deniedNoticed = true
            }
        @unknown default:
            isAuthorized = false
            if !deniedNoticed {
                print("[NowPlayingService] unknown auth status \(status.rawValue) — defaulting to denied")
                deniedNoticed = true
            }
        }
    }

    // MARK: - Capture Lifecycle

    /// Begins polling. Idempotent — safe to call repeatedly. If auth was denied, this is a no-op.
    func startCapture() {
        print("[NowPlayingService] startCapture called — resetting session state")
        // Reset session state up-front so a back-to-back start clears prior captures
        captured.removeAll()
        seenKeys.removeAll()
        lastCapturedTrack = nil
        pollTask?.cancel()

        // Kick off auth check + first poll. If auth lands on denied, the polling loop
        // will simply observe the auth flag and exit — no nag, no UI.
        pollTask = Task { [weak self] in
            guard let self else { return }
            await self.ensureAuthorization()
            guard self.isAuthorized else {
                // Silent skip — deniedNoticed gates repeat logging in `ensureAuthorization`.
                self.isCapturing = false
                return
            }
            self.isCapturing = true
            print("[NowPlayingService] polling started — interval=\(self.pollInterval)s")
            // Capture immediately so a song already playing at workout start is recorded.
            self.captureCurrentTrack()

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(self.pollInterval * 1_000_000_000))
                if Task.isCancelled { return }
                self.captureCurrentTrack()
            }
            print("[NowPlayingService] polling loop exited")
        }
    }

    /// Stops polling and returns the captured list. Clears in-flight state so the next
    /// `startCapture()` begins fresh. `lastCapturedTrack` is retained across stop/start so
    /// Settings can still show the most recent capture between sessions.
    @discardableResult
    func stopCapture() -> [WorkoutTrack] {
        print("[NowPlayingService] stopCapture called — \(captured.count) track(s) captured")
        pollTask?.cancel()
        pollTask = nil
        isCapturing = false
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
        guard isAuthorized else {
            print("[NowPlayingService] captureCurrentTrack: skipped — not authorized")
            return
        }
        guard let item = MPMusicPlayerController.systemMusicPlayer.nowPlayingItem else {
            print("[NowPlayingService] captureCurrentTrack: nowPlayingItem is nil (nothing playing via Apple Music)")
            return
        }
        guard let title = item.title, !title.isEmpty else {
            print("[NowPlayingService] captureCurrentTrack: item has no title, skipping")
            return
        }

        let key = dedupeKey(title: title, artist: item.artist, persistentID: item.persistentID)
        guard !seenKeys.contains(key) else {
            print("[NowPlayingService] captureCurrentTrack: '\(title)' already captured, deduped")
            return
        }
        seenKeys.insert(key)

        let track = WorkoutTrack(
            title: title,
            artist: item.artist,
            album: item.albumTitle,
            capturedAt: Date(),
            sourceApp: "Apple Music"
        )
        captured.append(track)
        lastCapturedTrack = track
        print("[NowPlayingService] captured '\(title)' by \(item.artist ?? "unknown") — total: \(captured.count)")
    }

    private func dedupeKey(title: String, artist: String?, persistentID: MPMediaEntityPersistentID) -> String {
        // persistentID == 0 for some streamed / radio items — fall back to title+artist alone in that case.
        let pid = persistentID == 0 ? "" : String(persistentID)
        return "\(title.lowercased())|\(artist?.lowercased() ?? "")|\(pid)"
    }
}
