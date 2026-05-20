import Foundation

/// A user's profile "anthem" — a short audio teaser displayed on their profile
/// and on each feed item they post (#403).
///
/// Storage shape: persisted as JSON on the `profiles.anthem` column so the
/// payload travels with `ProfileRow` and we don't have to N+1 a separate
/// `profile_anthem` table at fetch time.
///
/// Playback shape: only `previewURL` is required for actual audio output. The
/// `appleMusicId` field is reserved for a future Apple Music lookup; for the
/// initial rollout we use iTunes Search to resolve previews on-demand from
/// `title` + `artist` when `previewURL` is absent (see `AnthemPlaybackService`).
struct ProfileAnthem: Codable, Hashable, Identifiable {
    /// Stable identifier — derived from title + artist when nothing else is set
    /// so SwiftUI lists can diff anthems even before the preview URL resolves.
    var id: String {
        if let url = previewURL, !url.isEmpty { return url }
        if let amid = appleMusicId, !amid.isEmpty { return "am:\(amid)" }
        return "\(title.lowercased())|\(artist.lowercased())"
    }

    var title: String
    var artist: String
    /// 30-second preview MP3 URL (typically Apple's `audio-ssl.itunes.apple.com`
    /// CDN). Nil until resolved via `AnthemPlaybackService.resolvePreviewURL`.
    var previewURL: String?
    /// Optional artwork URL for the album/track. Renders as a small thumbnail
    /// next to the play button when present.
    var artworkURL: String?
    /// Reserved for the future Apple Music lookup path (#403 follow-up).
    var appleMusicId: String?

    init(
        title: String,
        artist: String,
        previewURL: String? = nil,
        artworkURL: String? = nil,
        appleMusicId: String? = nil
    ) {
        self.title = title
        self.artist = artist
        self.previewURL = previewURL
        self.artworkURL = artworkURL
        self.appleMusicId = appleMusicId
    }

    enum CodingKeys: String, CodingKey {
        case title
        case artist
        case previewURL = "preview_url"
        case artworkURL = "artwork_url"
        case appleMusicId = "apple_music_id"
    }
}

// MARK: - Mock

extension ProfileAnthem {
    /// Deterministic mock anthem used by the `XOMFIT_AUTH_BYPASS=1` flow so
    /// agent screenshot runs see a populated anthem row without hitting iTunes.
    /// The preview URL is intentionally left nil so the live resolver path is
    /// also exercised in screenshot mode.
    static let mock = ProfileAnthem(
        title: "Power",
        artist: "Kanye West",
        previewURL: nil,
        artworkURL: nil,
        appleMusicId: nil
    )
}
