import Foundation

/// Polls Spotify's `currently-playing` endpoint during an active workout (#347) and accumulates
/// the tracks for attachment to the saved `Workout`.
///
/// ## Why this exists alongside `NowPlayingService`
/// iOS does NOT expose other apps' Now Playing metadata to third-party apps. Apple Music is the
/// only system-level source we can read. Spotify offers its own Web API that we hit explicitly
/// with the user's OAuth token. Same shape (`startCapture` / `stopCapture -> [WorkoutTrack]`)
/// as `NowPlayingService` so `WorkoutLoggerViewModel` can merge them at finish time.
///
/// ## Silent when not authenticated
/// If `SpotifyAuthService.shared.currentTokenRefreshingIfNeeded()` returns nil (user never signed
/// in, or token revoked) the polling loop simply no-ops on each tick. No prompts, no errors.
@MainActor
final class SpotifyNowPlayingService {
    static let shared = SpotifyNowPlayingService()

    /// 30s cadence — matches `NowPlayingService` and stays well under Spotify's rate limit.
    private let pollInterval: TimeInterval = 30

    private var captured: [WorkoutTrack] = []
    private var seenKeys: Set<String> = []
    private var pollTask: Task<Void, Never>?

    private init() {}

    // MARK: - Capture lifecycle

    /// Idempotent. Resets per-session state and starts polling. Safe to call when not
    /// authenticated — the loop checks on each tick.
    func startCapture() {
        print("[SpotifyNowPlayingService] startCapture called — resetting session state")
        captured.removeAll()
        seenKeys.removeAll()
        pollTask?.cancel()

        pollTask = Task { [weak self] in
            guard let self else { return }
            print("[SpotifyNowPlayingService] polling started — interval=\(self.pollInterval)s")
            // Capture immediately so a song already playing at workout start is recorded.
            await self.captureCurrentTrack()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(self.pollInterval * 1_000_000_000))
                if Task.isCancelled { return }
                await self.captureCurrentTrack()
            }
            print("[SpotifyNowPlayingService] polling loop exited")
        }
    }

    /// Stop polling and return the captured tracks. Clears state for the next session.
    @discardableResult
    func stopCapture() -> [WorkoutTrack] {
        print("[SpotifyNowPlayingService] stopCapture called — \(captured.count) track(s) captured")
        pollTask?.cancel()
        pollTask = nil
        let result = captured
        captured.removeAll()
        seenKeys.removeAll()
        return result
    }

    // MARK: - Polling

    private func captureCurrentTrack() async {
        guard let token = await SpotifyAuthService.shared.currentTokenRefreshingIfNeeded() else {
            // Not signed in (or refresh failed). Silent no-op — see class doc.
            return
        }

        var request = URLRequest(url: SpotifyConfig.nowPlayingURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        // The endpoint can take a few hundred ms; 10s is a generous upper bound that still
        // bails fast enough to not stack tasks at 30s intervals.
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return }
            switch http.statusCode {
            case 204:
                // Spotify returns 204 when nothing is playing — common during rest sets.
                return
            case 200:
                break
            case 401:
                // Token rejected mid-session. Refresh path handles renewal; if this persists
                // the user can re-auth from Settings. Don't sign them out automatically.
                print("[SpotifyNowPlayingService] 401 from /currently-playing")
                return
            case 429:
                print("[SpotifyNowPlayingService] rate-limited (429) — skipping this tick")
                return
            default:
                print("[SpotifyNowPlayingService] unexpected status \(http.statusCode)")
                return
            }

            guard let payload = try? JSONDecoder().decode(SpotifyNowPlayingResponse.self, from: data),
                  let item = payload.item else {
                return
            }
            // `is_playing` can be false during transient pauses — still record the track
            // if it has metadata, since the user clearly had it queued during the workout.
            let title = item.name
            guard !title.isEmpty else { return }

            let key = dedupeKey(uri: item.uri, id: item.id, title: title)
            guard !seenKeys.contains(key) else {
                print("[SpotifyNowPlayingService] '\(title)' already captured, deduped")
                return
            }
            seenKeys.insert(key)

            let artist = item.artists?.compactMap { $0.name }.joined(separator: ", ")
            let track = WorkoutTrack(
                title: title,
                artist: (artist?.isEmpty == false) ? artist : nil,
                album: item.album?.name,
                capturedAt: Date(),
                sourceApp: "Spotify"
            )
            captured.append(track)
            print("[SpotifyNowPlayingService] captured '\(title)' by \(artist ?? "unknown") — total: \(captured.count)")
        } catch {
            // Network blips happen — log and continue. Polling will retry on the next tick.
            print("[SpotifyNowPlayingService] poll error: \(error)")
        }
    }

    private func dedupeKey(uri: String?, id: String?, title: String) -> String {
        // Prefer the canonical URI, then the bare id, then a title fallback for unusual
        // edge cases (local tracks have neither uri nor id populated reliably).
        if let uri, !uri.isEmpty { return "uri|\(uri)" }
        if let id, !id.isEmpty { return "id|\(id)" }
        return "title|\(title.lowercased())"
    }
}

// MARK: - Spotify payload shapes

/// Trimmed to only the fields we actually consume. Spotify returns far more
/// (progress_ms, device, context, currently_playing_type, ...) — easy to extend later.
private struct SpotifyNowPlayingResponse: Decodable {
    let is_playing: Bool?
    let item: SpotifyItem?
}

private struct SpotifyItem: Decodable {
    let id: String?
    let uri: String?
    let name: String
    let artists: [SpotifyArtist]?
    let album: SpotifyAlbum?
}

private struct SpotifyArtist: Decodable {
    let name: String?
}

private struct SpotifyAlbum: Decodable {
    let name: String?
}
