import Foundation

/// Static configuration for the SoundCloud Web API OAuth + Now-Playing integration (#389).
///
/// ## Why a shared client id (vs paste-your-own like Spotify)
/// SoundCloud's developer-app program has been intermittently closed to new registrations
/// for years — they've publicly stated they're "not currently accepting new applications"
/// at various points. Asking every user to register their own app is a non-starter.
///
/// Instead, XomFit ships a single shared client id baked into the binary. Because we use
/// the Authorization Code with PKCE grant (no client secret), the shared id is safe to
/// distribute — only the user's own OAuth verifier + redirect URI gate the token exchange.
///
/// ## Status (see `docs/features/soundcloud-389/SETUP.md`)
/// As of shipping, the `sharedClientId` is a **placeholder**. If SoundCloud is currently
/// not accepting new developer apps, sign-in will fail with a clear error and the user can
/// still finish the workout — Apple Music + Spotify capture continue working untouched.
enum SoundCloudConfig {
    /// Public SoundCloud Developer client id shared across XomFit installs. Treated as
    /// public per the PKCE flow — no client secret is needed or stored. Replace once
    /// the SoundCloud Dev Dashboard accepts new app registrations.
    static let sharedClientId: String = "PLACEHOLDER_SHARED_SOUNDCLOUD_CLIENT_ID"  // TODO replace

    /// Custom URL scheme that ASWebAuthenticationSession listens for. Must match the
    /// "Redirect URI" registered on the SoundCloud Developer Dashboard exactly.
    static let redirectURI = "xomfit://soundcloud-callback"

    /// Scope string. `non-expiring` requests a long-lived token so the user doesn't have
    /// to re-auth between workouts. See https://developers.soundcloud.com/docs/api/explorer
    static let scopes = "non-expiring"

    static let authBaseURL = URL(string: "https://api.soundcloud.com/connect")!
    static let tokenURL = URL(string: "https://api.soundcloud.com/oauth2/token")!

    /// SoundCloud's recent listening history endpoint. Unlike Spotify, SoundCloud does
    /// not expose a real-time "currently playing" — only `play-history` (most recent 50
    /// tracks). We poll and look at the LATEST entry; if it's new since last tick, we
    /// capture it. This is best-effort and may lag a few seconds behind playback.
    static let recentlyPlayedURL = URL(string: "https://api.soundcloud.com/me/play-history/tracks?limit=5")!

    /// URL scheme component of `redirectURI` — what ASWebAuthenticationSession needs separately.
    static let callbackURLScheme = "xomfit"
}
