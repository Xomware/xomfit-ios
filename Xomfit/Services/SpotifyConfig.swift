import Foundation

/// Static configuration for the Spotify Web API OAuth + Now-Playing integration (#347, #390).
///
/// We use the Authorization Code with PKCE grant — no client secret required. Spotify treats the
/// client id as a public identifier; only the redirect URI + PKCE verifier protect the code
/// exchange.
///
/// ## Shared Client ID (#390)
/// XomFit now ships a *shared* Spotify Developer App Client ID baked into the app so end users
/// don't have to register their own Developer App just to record their workout soundtrack. The
/// owner of the shared Spotify Developer App **must** have `xomfit://spotify-callback` registered
/// as a Redirect URI for sign-in to succeed.
///
/// Power users can still override the shared id by pasting their own value into Settings ->
/// Music Sources -> Spotify -> Advanced. The override is persisted under
/// `@AppStorage("spotifyClientId")` and takes precedence over `sharedClientId` on the very next
/// sign-in attempt without an app restart.
///
/// See `docs/features/spotify-347/SETUP.md` for the user-facing guide.
enum SpotifyConfig {
    /// Shared Spotify Developer App Client ID baked into the app (#390). When the user has not
    /// supplied their own override, this is what `resolvedClientId()` returns.
    ///
    /// TODO(#390): replace this placeholder with the real shared Spotify Developer App Client ID
    /// from the Xomware Spotify Developer Dashboard before shipping. The matching Developer App
    /// must have `xomfit://spotify-callback` registered under "Redirect URIs" or sign-in will
    /// fail with `INVALID_CLIENT: Invalid redirect URI`.
    static let sharedClientId: String = "1c79964c237042fe88b87da133a231fc"

    /// `@AppStorage` key the legacy per-user override is persisted under. Kept as a named
    /// constant so the View, the AuthService, and the static resolver can't drift apart.
    static let clientIdOverrideKey = "spotifyClientId"

    /// Returns the Client ID we should hand to Spotify for the next OAuth call.
    ///
    /// Resolution order:
    ///   1. Per-user override stored under `@AppStorage("spotifyClientId")` — for power users
    ///      bringing their own Spotify Developer App.
    ///   2. `sharedClientId` baked into the app.
    ///
    /// We read the override straight out of `UserDefaults.standard` rather than through
    /// `@AppStorage` so this stays callable from anywhere — `@AppStorage` is a SwiftUI property
    /// wrapper and would force `SpotifyConfig` to become a view-bound type. The on-disk storage
    /// is identical (`UserDefaults.standard`), so the resolver sees a paste-in immediately.
    ///
    /// Emits a one-line console warning if the resolved value is still the unreplaced
    /// `sharedClientId` placeholder — sign-in will fail until the project owner ships a real id.
    static func resolvedClientId() -> String {
        let override = (UserDefaults.standard.string(forKey: clientIdOverrideKey) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = override.isEmpty ? sharedClientId : override

        if resolved == sharedClientId, sharedClientId == "PLACEHOLDER_SHARED_SPOTIFY_CLIENT_ID" {
            print("[SpotifyConfig] WARNING: shared Spotify Client ID is still the placeholder — " +
                  "sign-in will fail until SpotifyConfig.sharedClientId is replaced with the " +
                  "real Xomware Spotify Developer App Client ID (#390).")
        }
        return resolved
    }

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
