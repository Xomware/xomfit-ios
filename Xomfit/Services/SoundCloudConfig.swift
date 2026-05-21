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
    /// Public Xomcloud SoundCloud Developer App client id, shared across XomFit installs.
    /// Treated as public per the PKCE flow — no client secret is needed or stored.
    static let sharedClientId: String = "FdZcMJaQOlOuQVK54FFgoR2L8CMmQvfF"

    /// SoundCloud only allows one redirect URI per app, and the Xomcloud web app already
    /// owns this one. The xomcloud-frontend `CallbackComponent` inspects the OAuth `state`
    /// query param — when it starts with `xomfit-` it JS-redirects to
    /// `xomfit://soundcloud-callback?<original params>`, which `ASWebAuthenticationSession`
    /// then intercepts via `callbackURLScheme = "xomfit"`. SoundCloud verifies this URI
    /// during the code → token exchange, so it MUST match the dashboard value exactly.
    static let redirectURI = "https://xomcloud.xomware.com/callback"

    /// SoundCloud rejects `non-expiring` for newly-registered shared apps with
    /// `403 — "Requesting non-expiring tokens is not allowed. Set scope=''."`
    /// An empty scope yields a standard expiring access token + refresh token,
    /// which `SoundCloudAuthService` already knows how to refresh.
    static let scopes = ""

    static let authBaseURL = URL(string: "https://api.soundcloud.com/connect")!
    static let tokenURL = URL(string: "https://api.soundcloud.com/oauth2/token")!

    /// SoundCloud's recent listening history endpoint. Unlike Spotify, SoundCloud does
    /// not expose a real-time "currently playing" — only `play-history` (most recent 50
    /// tracks). We poll and look at the LATEST entry; if it's new since last tick, we
    /// capture it. This is best-effort and may lag a few seconds behind playback.
    static let recentlyPlayedURL = URL(string: "https://api.soundcloud.com/me/play-history/tracks?limit=5")!

    /// URL scheme component of `redirectURI` — what ASWebAuthenticationSession needs separately.
    static let callbackURLScheme = "xomfit"

    // MARK: - xomcloud-backend Auth Proxy
    //
    // SoundCloud's token endpoint now requires `client_secret`, which we refuse to ship in
    // the IPA. Instead, we POST to a tiny proxy on xomcloud-backend (`/auth/token` and
    // `/auth/refresh`) that reads the secret out of SSM and forwards to SoundCloud. The
    // proxy returns SoundCloud's JSON response unchanged.

    /// Base URL of the xomcloud-backend SoundCloud auth proxy.
    ///
    /// Resolves to `https://api.xomcloud.xomware.com/auth` — the API Gateway custom domain
    /// configured in `xomcloud-infrastructure/terraform/locals.tf` (`api_domain_name =
    /// "api.${app_name}${domain_suffix}"` = `api.xomcloud.xomware.com`). The `/auth` prefix
    /// matches the API Gateway resource path the backend agent is wiring up.
    ///
    /// TODO: if the backend's path prefix lands as something other than `/auth` (e.g.
    /// `/soundcloud/auth`), update this constant before merging the corresponding backend PR.
    static let authProxyBaseURL = URL(string: "https://api.xomcloud.xomware.com/auth")!

    /// `true` while `authProxyBaseURL` still points at the placeholder host. Mirrors the
    /// resolver pattern in `SpotifyConfig.resolvedClientId()` so failed proxy calls log a
    /// clearly-labeled warning instead of failing silently.
    static var authProxyIsPlaceholder: Bool {
        // The URL is hard-coded above. As soon as someone replaces the host with the
        // real custom-domain or `<apiId>.execute-api.us-east-1.amazonaws.com/dev` URL,
        // this returns false. The check is intentionally string-based so we don't need
        // to plumb a separate "isPlaceholder" flag through Config.swift.
        let host = authProxyBaseURL.host ?? ""
        return host.contains("PLACEHOLDER") || host.isEmpty
    }

    /// Token-exchange endpoint on the xomcloud-backend proxy (`POST /auth/token`).
    static var authProxyTokenURL: URL { authProxyBaseURL.appendingPathComponent("token") }

    /// Refresh endpoint on the xomcloud-backend proxy (`POST /auth/refresh`).
    static var authProxyRefreshURL: URL { authProxyBaseURL.appendingPathComponent("refresh") }

    /// Logs a one-shot console warning when the proxy base URL is still the placeholder.
    /// Call sites: `exchangeCodeForToken` and `refreshAccessToken` — mirror the
    /// `SpotifyConfig.resolvedClientId()` pattern.
    static func warnIfAuthProxyIsPlaceholder() {
        guard authProxyIsPlaceholder else { return }
        print("[SoundCloudConfig] WARNING: SoundCloud auth proxy base URL is still a " +
              "placeholder — token exchange will fail until SoundCloudConfig.authProxyBaseURL " +
              "is replaced with the real xomcloud-backend custom domain.")
    }
}
