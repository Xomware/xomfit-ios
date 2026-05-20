import AVFoundation
import Foundation

/// Plays the 30-second preview MP3 for a `ProfileAnthem` (#403).
///
/// Design choices:
/// - Uses `AVPlayer` directly. We don't want a `MPMusicPlayerController` because
///   that requires a full Apple Music subscription. The iTunes Search API returns
///   a free, 30-second preview URL for almost any commercially released track, so
///   we resolve via that endpoint when an anthem doesn't carry a pre-cached URL.
/// - Single-flight: there's only ever one anthem playing across the app. Tapping
///   play on a second card stops the first.
/// - Auto-stops at 30 seconds. We don't loop and we don't fade.
/// - All UI-touching state mutations happen on `@MainActor`. Network resolution
///   is non-isolated so it doesn't block the actor.
@MainActor
@Observable
final class AnthemPlaybackService {
    static let shared = AnthemPlaybackService()

    /// ID of the anthem currently playing, or nil when paused/stopped.
    /// Views compare against `ProfileAnthem.id` to flip their button icon.
    private(set) var currentlyPlayingID: String?

    /// True while we're resolving a preview URL or waiting for the player to
    /// start. Views render a small spinner inside the play button when this
    /// matches the anthem they own.
    private(set) var loadingID: String?

    /// Non-nil after a failed lookup or playback error. Cleared on the next
    /// successful play. Views surface this as a one-liner under the title.
    private(set) var errorMessage: String?

    /// Hard cap on preview length. iTunes previews are nominally 30s but some
    /// run shorter; we stop at whichever comes first.
    private let maxDuration: TimeInterval = 30

    private var player: AVPlayer?
    /// Made `nonisolated(unsafe)` so the deinit can clear the observer without
    /// hopping back onto the main actor. Mutation is still confined to
    /// `play()` / `stop()` which both run on `@MainActor`.
    nonisolated(unsafe) private var endObserver: NSObjectProtocol?
    private var autoStopTask: Task<Void, Never>?

    /// In-memory cache mapping `title|artist` to a resolved preview URL so we
    /// don't re-hit iTunes Search every time a card re-renders.
    private var resolvedURLCache: [String: URL] = [:]

    private let session = URLSession(configuration: .ephemeral)
    private let decoder = JSONDecoder()

    private init() {
        configureAudioSession()
    }

    // MARK: - Public API

    /// True when the given anthem is the one currently playing.
    func isPlaying(_ anthem: ProfileAnthem) -> Bool {
        currentlyPlayingID == anthem.id && player?.timeControlStatus == .playing
    }

    /// True when the given anthem is currently loading (resolving preview or
    /// buffering). Views show a spinner in this state.
    func isLoading(_ anthem: ProfileAnthem) -> Bool {
        loadingID == anthem.id
    }

    /// Toggle handler — pauses if this anthem is already playing, otherwise
    /// starts it (stopping anything else that was playing).
    func toggle(_ anthem: ProfileAnthem) async {
        if isPlaying(anthem) {
            pause()
        } else {
            await play(anthem)
        }
    }

    /// Start playback for an anthem. Resolves the preview URL via iTunes Search
    /// if the anthem doesn't carry one. Stops any other in-flight playback.
    func play(_ anthem: ProfileAnthem) async {
        // Stop any in-flight playback up front so the UI flips immediately.
        stop()

        errorMessage = nil
        loadingID = anthem.id

        let resolvedURL: URL
        if let cached = anthem.previewURL.flatMap(URL.init(string:)) {
            resolvedURL = cached
        } else if let cached = resolvedURLCache[anthem.cacheKey] {
            resolvedURL = cached
        } else {
            do {
                let url = try await resolvePreviewURL(title: anthem.title, artist: anthem.artist)
                resolvedURLCache[anthem.cacheKey] = url
                resolvedURL = url
            } catch {
                loadingID = nil
                errorMessage = "Couldn't find a preview for this track."
                return
            }
        }

        let item = AVPlayerItem(url: resolvedURL)
        let player = AVPlayer(playerItem: item)
        player.actionAtItemEnd = .pause
        self.player = player

        // Stop on natural end-of-stream.
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            // Hop to MainActor — `stop()` is main-isolated.
            Task { @MainActor [weak self] in self?.stop() }
        }

        player.play()
        currentlyPlayingID = anthem.id
        loadingID = nil

        // Hard 30s cap. We rely on this for tracks whose preview metadata is
        // longer than the spec or where end-of-stream doesn't fire promptly.
        autoStopTask?.cancel()
        autoStopTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(self?.maxDuration ?? 30))
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.stop() }
        }
    }

    /// Pause without tearing down the player. Currently we just call `stop()`
    /// — a 30s preview doesn't benefit from a resume affordance, and tearing
    /// down keeps memory clean.
    func pause() {
        stop()
    }

    /// Stop and reset. Safe to call repeatedly.
    func stop() {
        player?.pause()
        player = nil
        currentlyPlayingID = nil
        loadingID = nil
        autoStopTask?.cancel()
        autoStopTask = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
    }

    // MARK: - Preview Resolution (iTunes Search)

    /// Hits Apple's free, no-auth iTunes Search endpoint and returns the
    /// `previewUrl` for the top song result.
    ///
    /// We deliberately keep this non-isolated — the request can fly off the
    /// main actor while the UI shows its loading spinner.
    nonisolated private func resolvePreviewURL(title: String, artist: String) async throws -> URL {
        var components = URLComponents(string: "https://itunes.apple.com/search")
        components?.queryItems = [
            URLQueryItem(name: "term", value: "\(title) \(artist)"),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: "1")
        ]
        guard let url = components?.url else {
            throw AnthemError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AnthemError.httpError
        }

        let payload = try decoder.decode(ITunesSearchResponse.self, from: data)
        guard let first = payload.results.first,
              let preview = first.previewUrl,
              let parsed = URL(string: preview) else {
            throw AnthemError.notFound
        }
        return parsed
    }

    // MARK: - Audio Session

    nonisolated private func configureAudioSession() {
        // Use `.ambient` so anthem playback duck-mixes with other audio and
        // doesn't interrupt Apple Music / Spotify if the user is listening.
        // We deliberately don't activate the session here — AVPlayer will
        // activate when it begins playback.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
    }

    // MARK: - Cleanup

    deinit {
        // `endObserver` is captured here for cleanup; AVPlayer references will
        // drop naturally when the actor instance is released.
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
    }
}

// MARK: - Errors

enum AnthemError: Error {
    case invalidURL
    case httpError
    case notFound
}

// MARK: - iTunes Search Response

private struct ITunesSearchResponse: Decodable {
    let results: [Result]

    struct Result: Decodable {
        let previewUrl: String?
        let artworkUrl100: String?
        let trackName: String?
        let artistName: String?
    }
}

// MARK: - Cache Key

private extension ProfileAnthem {
    /// Case-insensitive cache key for the in-memory preview URL cache. Distinct
    /// from `id` because `id` flips once `previewURL` resolves, which would
    /// invalidate the cache entry we just wrote.
    var cacheKey: String {
        "\(title.lowercased())|\(artist.lowercased())"
    }
}
