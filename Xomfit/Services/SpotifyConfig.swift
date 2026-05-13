import Foundation

/// Static configuration for the Spotify Web API OAuth + Now-Playing integration (#347).
///
/// We use the Authorization Code with PKCE grant — no client secret required, which is
/// exactly why the `clientId` can ship empty here and be pasted in by the user via
/// `Settings -> Music Sources -> Spotify Client ID` (read off `@AppStorage("spotifyClientId")`).
/// Spotify treats the client id as public; only the redirect URI + PKCE verifier protect
/// the code exchange.
///
/// See `docs/features/spotify-347/SETUP.md` for the full Developer App walkthrough.
enum SpotifyConfig {
    /// Public Spotify Developer client id. Empty by default — the user pastes their
    /// own value via Settings, persisted under `@AppStorage("spotifyClientId")`. Reading
    /// the live value is the responsibility of `SpotifyAuthService` so a paste-in takes
    /// effect on the very next sign-in attempt without an app restart.
    static let clientId = ""

    /// Custom URL scheme that ASWebAuthenticationSession listens for. Must match the
    /// "Redirect URI" registered on the Spotify Developer Dashboard exactly.
    static let redirectURI = "xomfit://spotify-callback"

    /// Space-delimited scope list. Only what we actually need:
    /// `user-read-currently-playing` covers the polling endpoint, `user-read-playback-state`
    /// keeps us forward-compatible with adding "now-playing context" (device, shuffle, etc.).
    static let scopes = "user-read-currently-playing user-read-playback-state"

    static let authBaseURL = URL(string: "https://accounts.spotify.com/authorize")!
    static let tokenURL = URL(string: "https://accounts.spotify.com/api/token")!
    static let nowPlayingURL = URL(string: "https://api.spotify.com/v1/me/player/currently-playing")!

    /// URL scheme component of `redirectURI` — what ASWebAuthenticationSession needs separately.
    static let callbackURLScheme = "xomfit"
}
