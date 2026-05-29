import Foundation

/// Polls SoundCloud's `/me/play-history/tracks` endpoint during an active workout (#389) and
/// accumulates the tracks for attachment to the saved `Workout`.
///
/// ## Why play-history (not currently-playing)
/// SoundCloud's Web API does NOT expose a real-time "currently playing" endpoint the way
/// Spotify does. The only window into a user's listening is `/me/play-history/tracks`,
/// which returns the most recently played tracks (up to 50). We request the latest 5, then
/// look at the very first entry — if it's new since the last poll, we capture it.
///
/// This is best-effort: a track has to finish (or be skipped past a play-count threshold)
/// before SoundCloud writes it to history, so capture may lag the actual playback by a few
/// seconds to a couple of minutes. Acceptable for a workout soundtrack.
///
/// ## Same shape as the other capture services
/// `isCapturing` / `capturedCount` / `lastCapturedTrack` / `startCapture()` /
/// `stopCapture() -> [WorkoutTrack]` mirror `NowPlayingService` and `SpotifyNowPlayingService`
/// so `WorkoutLoggerViewModel` can merge them at finish time without special-casing.
///
/// ## Silent when not authenticated
/// If `SoundCloudAuthService.shared.currentTokenRefreshingIfNeeded()` returns nil (user
/// never signed in, or token revoked), the polling loop no-ops on each tick. No prompts,
/// no errors.
@MainActor
@Observable
final class SoundCloudNowPlayingService {
    @ObservationIgnored static let shared = SoundCloudNowPlayingService()

    /// 30s cadence — matches the other capture services and stays well under SoundCloud's
    /// (loosely documented) rate limits.
    @ObservationIgnored private let pollInterval: TimeInterval = 30

    private var captured: [WorkoutTrack] = []
    @ObservationIgnored private var seenKeys: Set<String> = []
    @ObservationIgnored private var pollTask: Task<Void, Never>?

    // MARK: - Observable surface

    /// True while the poll loop is alive. Drives the "Recording" indicator in
    /// `SoundCloudConnectionView`. Reset by `stopCapture`.
    private(set) var isCapturing: Bool = false

    /// Number of unique tracks captured in the current session — surfaced wherever the
    /// other services' counts are.
    var capturedCount: Int { captured.count }

    /// Most recent track added in this session, if any. Surfaced in
    /// `SoundCloudConnectionView` so the user can confirm capture is working.
    private(set) var lastCapturedTrack: WorkoutTrack?

    /// Read-only copy of the currently captured tracks for this session. Used by the
    /// finish-workout sheet (#387) to preview what will be saved without yet stopping
    /// the capture loop. Does NOT mutate state — call `stopCapture()` to actually drain.
    func capturedTracksSnapshot() -> [WorkoutTrack] {
        captured
    }

    private init() {}

    // MARK: - Capture lifecycle

    /// Idempotent. Resets per-session state and starts polling. Safe to call when not
    /// authenticated — the loop checks on each tick.
    func startCapture() {
        print("[SoundCloudNowPlayingService] startCapture called — resetting session state")
        captured.removeAll()
        seenKeys.removeAll()
        lastCapturedTrack = nil
        pollTask?.cancel()

        #if DEBUG
        // Agent screenshot bypass — skip the poll loop so the active-workout
        // cover renders cleanly in screenshots (#387).
        if ProcessInfo.processInfo.environment["XOMFIT_AUTH_BYPASS"] == "1" {
            isCapturing = false
            return
        }
        #endif

        isCapturing = true

        // Snapshot what's already in play-history so we don't backfill tracks the user
        // played BEFORE starting the workout. The first capture call records the most
        // recent pre-workout track in `seenKeys` without appending — anything new on the
        // next tick is "during the workout".
        pollTask = Task { [weak self] in
            guard let self else { return }
            print("[SoundCloudNowPlayingService] polling started — interval=\(self.pollInterval)s")
            await self.snapshotPriorHistory()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(self.pollInterval * 1_000_000_000))
                if Task.isCancelled { return }
                await self.captureLatestTrack()
            }
            print("[SoundCloudNowPlayingService] polling loop exited")
        }
    }

    /// Stop polling and return the captured tracks. Clears the live state but keeps
    /// `lastCapturedTrack` so Settings can still display the most recent capture between
    /// sessions.
    @discardableResult
    func stopCapture() -> [WorkoutTrack] {
        print("[SoundCloudNowPlayingService] stopCapture called — \(captured.count) track(s) captured")
        pollTask?.cancel()
        pollTask = nil
        isCapturing = false
        let result = captured
        captured.removeAll()
        seenKeys.removeAll()
        return result
    }

    // MARK: - Polling

    /// Read play-history at workout start and seed `seenKeys` so the immediately-prior
    /// track doesn't get incorrectly attributed to this workout. Does NOT append to
    /// `captured`.
    private func snapshotPriorHistory() async {
        guard let entries = await fetchHistory() else { return }
        for entry in entries {
            seenKeys.insert(dedupeKey(for: entry))
        }
        print("[SoundCloudNowPlayingService] snapshot complete — \(seenKeys.count) prior entry/entries skipped")
    }

    /// Poll once and capture only the LATEST track activity if it's new since last tick.
    /// Looking at just the head is intentional — if the user plays 3 tracks in quick
    /// succession we'll catch the most recent on this tick and the others on prior /
    /// subsequent ticks (the 30s cadence vs typical 3-4 minute song length leaves plenty
    /// of margin in practice).
    ///
    /// NOTE: We filter for "track" type activities to only capture direct plays, not
    /// reposts or playlist activities (#432).
    private func captureLatestTrack() async {
        guard let entries = await fetchHistory() else { return }

        // Filter for track-type activities only (not reposts)
        let trackActivities = entries.filter { entry in
            // Accept "track" type or entries with no type (legacy play-history format)
            entry.type == "track" || entry.type == nil
        }
        guard let latest = trackActivities.first else { return }

        let resolvedTrack = latest.resolvedTrack
        let title = resolvedTrack?.title ?? ""
        guard !title.isEmpty else { return }

        let key = dedupeKey(for: latest)
        guard !seenKeys.contains(key) else {
            print("[SoundCloudNowPlayingService] '\(title)' already captured/snapshotted, deduped")
            return
        }
        seenKeys.insert(key)

        // SoundCloud puts the uploader's display name on `user.username` — closest analogue
        // to a primary artist. Real "artist" metadata is rarely populated on SC uploads.
        let artist = resolvedTrack?.user?.username
        // Carry the permalink so the feed expanded view can deep-link straight
        // back into SoundCloud (#410). Nil-safe fallback handled by the
        // deep-link resolver — empty permalink degrades to a SoundCloud search.
        let track = WorkoutTrack(
            title: title,
            artist: (artist?.isEmpty == false) ? artist : nil,
            album: nil,
            capturedAt: Date(),
            sourceApp: "SoundCloud",
            url: resolvedTrack?.permalink_url
        )
        captured.append(track)
        lastCapturedTrack = track
        print("[SoundCloudNowPlayingService] captured '\(title)' by \(artist ?? "unknown") — total: \(captured.count)")
    }

    /// Returns the parsed play-history entries, or nil on any failure. Silent for
    /// non-authed / rate-limited / network-error cases — the next tick will retry.
    private func fetchHistory() async -> [SoundCloudHistoryEntry]? {
        guard let token = await SoundCloudAuthService.shared.currentTokenRefreshingIfNeeded() else {
            return nil
        }

        var request = URLRequest(url: SoundCloudConfig.recentlyPlayedURL)
        // SoundCloud accepts both `OAuth <token>` (legacy) and `Bearer <token>` — using
        // the documented modern form.
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return nil }
            switch http.statusCode {
            case 200:
                break
            case 401:
                print("[SoundCloudNowPlayingService] 401 from /activities — token rejected")
                return nil
            case 429:
                print("[SoundCloudNowPlayingService] rate-limited (429) — skipping this tick")
                return nil
            default:
                print("[SoundCloudNowPlayingService] unexpected status \(http.statusCode)")
                return nil
            }

            // SoundCloud wraps history entries in a `collection` envelope.
            guard let payload = try? JSONDecoder().decode(SoundCloudHistoryResponse.self, from: data) else {
                return nil
            }
            return payload.collection
        } catch {
            print("[SoundCloudNowPlayingService] poll error: \(error)")
            return nil
        }
    }

    private func dedupeKey(for entry: SoundCloudHistoryEntry) -> String {
        // Prefer the track id (stable, numeric), then the permalink, then a (title + created_at)
        // fallback. Including the timestamp in the fallback prevents the same song played twice
        // from being deduped against itself.
        let track = entry.resolvedTrack
        if let id = track?.id { return "id|\(id)" }
        if let permalink = track?.permalink_url, !permalink.isEmpty { return "permalink|\(permalink)" }
        let title = track?.title ?? ""
        // Use created_at (activities) or played_at (legacy) as the timestamp component
        let timestamp = entry.created_at ?? String(entry.played_at ?? 0)
        return "title|\(title.lowercased())|\(timestamp)"
    }
}

// MARK: - SoundCloud payload shapes
//
// NOTE: SoundCloud's `/me/activities/tracks` returns activity objects, not raw
// play-history. Each activity has a `type` (e.g. "track", "track-repost") and
// an `origin` containing the track details. We only capture activities where
// type == "track" (direct plays), ignoring reposts. (#432)

private struct SoundCloudHistoryResponse: Decodable {
    let collection: [SoundCloudHistoryEntry]
}

private struct SoundCloudHistoryEntry: Decodable {
    /// Activity type: "track", "track-repost", "playlist", "playlist-repost", etc.
    let type: String?
    /// ISO 8601 timestamp of when the activity occurred.
    let created_at: String?
    /// The track object (for track-type activities).
    let origin: SoundCloudTrack?

    // Legacy fields for backwards compatibility if play-history ever returns
    let played_at: Int64?
    let track: SoundCloudTrack?

    /// Returns the track, preferring `origin` (activities format) over `track` (legacy).
    var resolvedTrack: SoundCloudTrack? {
        origin ?? track
    }
}

private struct SoundCloudTrack: Decodable {
    let id: Int64?
    let title: String?
    let permalink_url: String?
    let user: SoundCloudUser?
}

private struct SoundCloudUser: Decodable {
    let username: String?
}
