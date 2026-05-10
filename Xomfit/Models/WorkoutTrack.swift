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
}
