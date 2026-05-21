import Foundation

/// Resolves a deep link URL for a captured `WorkoutTrack` so the feed expanded
/// view can punt the user out to Spotify / Apple Music / SoundCloud. (#410)
///
/// Each service has a preferred form:
/// - Spotify: `spotify:track:<id>` if we captured a URI, else a https web URL,
///   else a search URL by title+artist.
/// - Apple Music: the captured track URL when present, else a search URL.
/// - SoundCloud: the captured permalink URL when present, else a search URL.
///
/// `WorkoutTrack.url` is filled in by the per-source capture services starting
/// in #410 — older captured tracks (no `url`) fall through to the search-URL
/// branch so the deep link still gets the user to roughly the right place.
enum WorkoutTrackDeepLink {
    /// Returns the best deep link `URL` for the given track, or `nil` if we
    /// can't build one (title empty + unknown source).
    static func url(for track: WorkoutTrack) -> URL? {
        let source = track.sourceApp.lowercased()
        switch source {
        case "spotify":
            return spotifyURL(for: track)
        case "apple music":
            return appleMusicURL(for: track)
        case "soundcloud":
            return soundCloudURL(for: track)
        default:
            // Manual / unknown — fall back to a generic Apple Music search so
            // the button still does *something* useful for the user.
            return appleMusicSearchURL(for: track)
        }
    }

    /// Human-readable label for the deep-link button. Mirrors the source so the
    /// VoiceOver string + visible chevron stay aligned.
    static func label(for sourceApp: String) -> String {
        switch sourceApp.lowercased() {
        case "spotify":     return "Open in Spotify"
        case "apple music": return "Open in Apple Music"
        case "soundcloud":  return "Open in SoundCloud"
        case "manual":      return "Search this track"
        default:            return "Open track"
        }
    }

    // MARK: - Private builders

    private static func spotifyURL(for track: WorkoutTrack) -> URL? {
        if let raw = track.url, !raw.isEmpty, let url = URL(string: raw) {
            return url
        }
        // No captured uri — punt to web search.
        let q = encodedQuery(title: track.title, artist: track.artist)
        return URL(string: "https://open.spotify.com/search/\(q)")
    }

    private static func appleMusicURL(for track: WorkoutTrack) -> URL? {
        if let raw = track.url, !raw.isEmpty, let url = URL(string: raw) {
            return url
        }
        return appleMusicSearchURL(for: track)
    }

    private static func appleMusicSearchURL(for track: WorkoutTrack) -> URL? {
        let q = encodedQuery(title: track.title, artist: track.artist)
        return URL(string: "https://music.apple.com/us/search?term=\(q)")
    }

    private static func soundCloudURL(for track: WorkoutTrack) -> URL? {
        if let raw = track.url, !raw.isEmpty, let url = URL(string: raw) {
            return url
        }
        let q = encodedQuery(title: track.title, artist: track.artist)
        return URL(string: "https://soundcloud.com/search?q=\(q)")
    }

    /// URL-encodes "title artist" with `+` separators. Empty artist is fine.
    private static func encodedQuery(title: String, artist: String?) -> String {
        var raw = title
        if let artist, !artist.isEmpty {
            raw += " " + artist
        }
        let allowed = CharacterSet.urlQueryAllowed
        return raw.addingPercentEncoding(withAllowedCharacters: allowed) ?? raw
    }
}
