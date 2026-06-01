import Foundation

/// A single audio track captured during an active workout via Now Playing polling.
///
/// Platform limitation: iOS does NOT expose other apps' Now Playing metadata to third-party
/// apps. `MPNowPlayingInfoCenter.default()` is only readable by the OWNING audio app, and
/// `MPMusicPlayerController.systemMusicPlayer` only reflects Apple Music / iTunes Match content.
/// As a result, Spotify / Xomify / podcast players will NOT appear in this list — that's a
/// hard iOS restriction with no public API workaround.
struct WorkoutTrack: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var title: String
    var artist: String?
    var album: String?
    var capturedAt: Date
    /// Source application that surfaced the track (e.g. "Apple Music"). Hard-coded for v1
    /// because Apple Music is the only legal capture target.
    var sourceApp: String
    /// Canonical URL or URI of the track on its source service. Used to power
    /// per-track deep links in the feed expanded view (#410). Optional and
    /// backward-compatible — older cached / decoded payloads decode as `nil`.
    ///
    /// Examples:
    /// - Spotify: `spotify:track:<id>` or `https://open.spotify.com/track/<id>`
    /// - Apple Music: `https://music.apple.com/...`
    /// - SoundCloud: track permalink URL
    var url: String? = nil
    /// Number of times this track was played during the workout session. Incremented when
    /// a previously captured track reappears after playing a different song (i.e., the user
    /// repeated the song). Defaults to 1 for backward compatibility with older payloads.
    var playCount: Int = 1

    enum CodingKeys: String, CodingKey {
        case id, title, artist, album, capturedAt, sourceApp, url, playCount
    }

    init(
        id: UUID = UUID(),
        title: String,
        artist: String? = nil,
        album: String? = nil,
        capturedAt: Date,
        sourceApp: String,
        url: String? = nil,
        playCount: Int = 1
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.capturedAt = capturedAt
        self.sourceApp = sourceApp
        self.url = url
        self.playCount = playCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        artist = try container.decodeIfPresent(String.self, forKey: .artist)
        album = try container.decodeIfPresent(String.self, forKey: .album)
        capturedAt = try container.decode(Date.self, forKey: .capturedAt)
        sourceApp = try container.decode(String.self, forKey: .sourceApp)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        // Backward compat: older payloads won't have playCount, default to 1
        playCount = try container.decodeIfPresent(Int.self, forKey: .playCount) ?? 1
    }
}
