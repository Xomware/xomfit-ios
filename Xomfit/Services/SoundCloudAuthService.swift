import AuthenticationServices
import CryptoKit
import Foundation
import SwiftUI
import UIKit

/// SoundCloud OAuth 2.0 Authorization Code with PKCE (#389).
///
/// ## Why PKCE (no client secret)
/// Same rationale as the Spotify integration: the client id is treated as public, the PKCE
/// verifier stays in-process and prevents code interception, and we never ship a secret.
/// Crucially, SoundCloud's developer program has been intermittently closed to new app
/// registrations — a shared baked-in client id is the only realistic path. PKCE makes that
/// distribution safe.
///
/// ## Storage caveat
/// Tokens persisted via `@AppStorage` (UserDefaults). Mirrors the Spotify service.
/// Keychain migration tracked separately.
///
/// ## Callback delivery
/// Same pattern as Spotify — `ASWebAuthenticationSession` returns the redirect URL via its
/// completion handler. `XomfitApp.onOpenURL` is a belt-and-suspenders fallback.
@MainActor
@Observable
final class SoundCloudAuthService: NSObject {
    static let shared = SoundCloudAuthService()

    // MARK: - Persisted state

    @ObservationIgnored @AppStorage("soundcloud.accessToken") private var accessToken: String = ""
    @ObservationIgnored @AppStorage("soundcloud.refreshToken") private var refreshToken: String = ""
    @ObservationIgnored @AppStorage("soundcloud.tokenExpiry") private var tokenExpiryEpoch: Double = 0
    @ObservationIgnored @AppStorage("soundcloud.displayName") private var displayNameStorage: String = ""

    // MARK: - Observable mirror

    /// Mirror of the `@AppStorage` flags above so SwiftUI views observing this service
    /// re-render after sign-in / sign-out. `@AppStorage` doesn't notify our `@Observable` macro.
    private(set) var isAuthenticated: Bool = false
    private(set) var displayName: String = ""

    // MARK: - In-flight state

    private var pendingPKCEVerifier: String?
    private var pendingState: String?
    private var webAuthSession: ASWebAuthenticationSession?

    private override init() {
        super.init()
        isAuthenticated = !accessToken.isEmpty
        displayName = displayNameStorage
    }

    // MARK: - Public API

    /// Begin the OAuth dance. Returns `true` on a successful token exchange.
    ///
    /// Throws:
    ///   - `SoundCloudAuthError.userCancelled` — user dismissed the in-app browser
    ///   - `SoundCloudAuthError.callbackInvalid` — SoundCloud returned an error or unexpected payload
    ///   - `SoundCloudAuthError.tokenExchangeFailed` — `/oauth2/token` returned non-2xx
    ///   - `SoundCloudAuthError.apiClosed` — SoundCloud rejected the shared client id (very likely
    ///     while their dev program is closed to new apps)
    @discardableResult
    func signIn() async throws -> Bool {
        let verifier = Self.generatePKCEVerifier()
        let challenge = Self.codeChallenge(for: verifier)
        let state = Self.randomURLSafeString(length: 16)
        pendingPKCEVerifier = verifier
        pendingState = state

        guard let authURL = buildAuthorizeURL(challenge: challenge, state: state) else {
            throw SoundCloudAuthError.callbackInvalid
        }

        // ASWebAuthenticationSession returns the callback URL via its completion handler.
        let callbackURL: URL = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: SoundCloudConfig.callbackURLScheme
            ) { url, error in
                if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    cont.resume(throwing: SoundCloudAuthError.userCancelled)
                    return
                }
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                guard let url else {
                    cont.resume(throwing: SoundCloudAuthError.callbackInvalid)
                    return
                }
                cont.resume(returning: url)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.webAuthSession = session
            if !session.start() {
                cont.resume(throwing: SoundCloudAuthError.callbackInvalid)
            }
        }

        let code = try parseCallback(url: callbackURL, expectedState: state)
        try await exchangeCodeForToken(code: code, verifier: verifier)
        try await refreshUserDisplayName()
        return true
    }

    /// Last-resort callback handler invoked from `XomfitApp.onOpenURL` if the OS routes the
    /// redirect through the app rather than ASWebAuthenticationSession's completion handler.
    /// No-op today — kept for symmetry with `SpotifyAuthService.handleCallback`.
    func handleCallback(url: URL) {
        guard url.scheme == SoundCloudConfig.callbackURLScheme,
              url.host == "soundcloud-callback" else { return }
        print("[SoundCloudAuth] handleCallback received url (ASWebAuthSession should have handled it)")
    }

    /// Forget the tokens locally. SoundCloud's token endpoint does not document a revoke
    /// path for end users; clearing local state is sufficient.
    func signOut() {
        accessToken = ""
        refreshToken = ""
        tokenExpiryEpoch = 0
        displayNameStorage = ""
        isAuthenticated = false
        displayName = ""
    }

    /// Returns a fresh access token, refreshing via the stored refresh token if the cached
    /// one is within 60s of expiry. Returns nil when the user hasn't signed in or refresh failed.
    func currentTokenRefreshingIfNeeded() async -> String? {
        guard !accessToken.isEmpty else { return nil }

        let now = Date().timeIntervalSince1970
        // Refresh proactively to avoid the racy "401 mid-poll" window. SoundCloud's
        // `non-expiring` scope returns tokens with no expiry — in that case
        // `tokenExpiryEpoch` is 0 and this branch never fires.
        if tokenExpiryEpoch > 0, tokenExpiryEpoch - now < 60, !refreshToken.isEmpty {
            do {
                try await refreshAccessToken()
            } catch {
                print("[SoundCloudAuth] refresh failed: \(error)")
                return nil
            }
        }
        return accessToken.isEmpty ? nil : accessToken
    }

    // MARK: - URL construction

    private func buildAuthorizeURL(challenge: String, state: String) -> URL? {
        var components = URLComponents(url: SoundCloudConfig.authBaseURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: SoundCloudConfig.sharedClientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: SoundCloudConfig.redirectURI),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "scope", value: SoundCloudConfig.scopes)
        ]
        return components?.url
    }

    private func parseCallback(url: URL, expectedState: String) throws -> String {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw SoundCloudAuthError.callbackInvalid
        }
        let items = components.queryItems ?? []
        if let err = items.first(where: { $0.name == "error" })?.value {
            print("[SoundCloudAuth] callback error: \(err)")
            // `invalid_client` here almost always means SoundCloud rejected the shared
            // client id — surface a more actionable error so the user knows they're not
            // doing anything wrong; the integration is gated on SoundCloud's side.
            if err.contains("invalid_client") || err.contains("unauthorized_client") {
                throw SoundCloudAuthError.apiClosed
            }
            throw SoundCloudAuthError.callbackInvalid
        }
        guard let returnedState = items.first(where: { $0.name == "state" })?.value,
              returnedState == expectedState else {
            throw SoundCloudAuthError.callbackInvalid
        }
        guard let code = items.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
            throw SoundCloudAuthError.callbackInvalid
        }
        return code
    }

    // MARK: - Token exchange

    private func exchangeCodeForToken(code: String, verifier: String) async throws {
        // SoundCloud's `/oauth2/token` now demands `client_secret`, which we refuse to bake
        // into the IPA. We POST to xomcloud-backend's auth proxy instead — it reads the
        // secret from SSM and forwards to SoundCloud, returning the same JSON shape.
        SoundCloudConfig.warnIfAuthProxyIsPlaceholder()

        var request = URLRequest(url: SoundCloudConfig.authProxyTokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let body = TokenExchangeRequest(
            code: code,
            code_verifier: verifier,
            redirect_uri: SoundCloudConfig.redirectURI
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            print("[SoundCloudAuth] token exchange non-2xx — \(String(data: data, encoding: .utf8) ?? "")")
            // 401/403 from the proxy almost always means SoundCloud rejected the upstream
            // (either the shared client id or a quota issue) — funnel that into
            // `.apiClosed` so the UI can tell the user it's not their fault.
            if let http = response as? HTTPURLResponse, http.statusCode == 401 || http.statusCode == 403 {
                throw SoundCloudAuthError.apiClosed
            }
            throw SoundCloudAuthError.tokenExchangeFailed
        }
        let payload = try JSONDecoder().decode(TokenResponse.self, from: data)
        storeToken(payload)
    }

    private func refreshAccessToken() async throws {
        guard !refreshToken.isEmpty else { throw SoundCloudAuthError.tokenExchangeFailed }
        // See `exchangeCodeForToken` — refresh goes through the same xomcloud-backend
        // proxy (`/auth/refresh`) so the client_secret never leaves the server.
        SoundCloudConfig.warnIfAuthProxyIsPlaceholder()

        var request = URLRequest(url: SoundCloudConfig.authProxyRefreshURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let body = RefreshRequest(refresh_token: refreshToken)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            print("[SoundCloudAuth] refresh non-2xx — \(String(data: data, encoding: .utf8) ?? "")")
            // SoundCloud rejected the refresh token (revoked or expired) — drop local state
            // so the UI returns to the "Sign In" affordance.
            if let http = response as? HTTPURLResponse, http.statusCode == 400 {
                signOut()
            }
            throw SoundCloudAuthError.tokenExchangeFailed
        }
        let payload = try JSONDecoder().decode(TokenResponse.self, from: data)
        storeToken(payload)
    }

    private func storeToken(_ payload: TokenResponse) {
        accessToken = payload.access_token
        if let new = payload.refresh_token, !new.isEmpty {
            refreshToken = new
        }
        // `non-expiring` scope returns no `expires_in` — store 0 to skip refresh checks.
        if let expiresIn = payload.expires_in {
            tokenExpiryEpoch = Date().timeIntervalSince1970 + Double(expiresIn)
        } else {
            tokenExpiryEpoch = 0
        }
        isAuthenticated = true
    }

    // MARK: - Profile

    /// Pulls `/me` once after sign-in to surface the user's display name in Settings.
    /// Failure is non-fatal — we still consider sign-in successful with an empty display.
    private func refreshUserDisplayName() async throws {
        guard let token = await currentTokenRefreshingIfNeeded() else { return }
        var request = URLRequest(url: URL(string: "https://api.soundcloud.com/me")!)
        request.setValue("OAuth \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return }
            let profile = try JSONDecoder().decode(SoundCloudMeResponse.self, from: data)
            let resolved = profile.username ?? profile.permalink ?? ""
            displayNameStorage = resolved
            displayName = resolved
        } catch {
            print("[SoundCloudAuth] /me lookup failed: \(error)")
        }
    }

    // MARK: - PKCE helpers

    private static func generatePKCEVerifier() -> String {
        randomURLSafeString(length: 64)
    }

    private static func codeChallenge(for verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hashed = SHA256.hash(data: data)
        return Data(hashed).base64URLEncodedString()
    }

    private static func randomURLSafeString(length: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncodedString()
    }
}

// MARK: - Presentation context

extension SoundCloudAuthService: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first(where: { $0.activationState == .foregroundActive })
                ?? UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .first
            if let key = scene?.keyWindow { return key }
            if let scene { return UIWindow(windowScene: scene) }
            return UIWindow()
        }
    }
}

// MARK: - Errors + payloads

enum SoundCloudAuthError: LocalizedError {
    case userCancelled
    case callbackInvalid
    case tokenExchangeFailed
    case apiClosed

    var errorDescription: String? {
        switch self {
        case .userCancelled:
            return "SoundCloud sign-in was cancelled."
        case .callbackInvalid:
            return "SoundCloud returned an invalid response."
        case .tokenExchangeFailed:
            return "Couldn't exchange the SoundCloud auth code. Try signing in again."
        case .apiClosed:
            return "SoundCloud rejected XomFit's shared client id. The SoundCloud Developer program has been intermittently closed to new apps — see Settings for status."
        }
    }
}

private struct TokenResponse: Decodable {
    let access_token: String
    let token_type: String?
    let expires_in: Int?
    let refresh_token: String?
    let scope: String?
}

/// Request body for `POST <authProxyBaseURL>/token`. The backend forwards `code`,
/// `code_verifier`, and `redirect_uri` to SoundCloud's `/oauth2/token` after attaching
/// `client_id` and `client_secret` from SSM.
private struct TokenExchangeRequest: Encodable {
    let code: String
    let code_verifier: String
    let redirect_uri: String
}

/// Request body for `POST <authProxyBaseURL>/refresh`. The backend forwards
/// `refresh_token` to SoundCloud after attaching `client_id` + `client_secret`.
private struct RefreshRequest: Encodable {
    let refresh_token: String
}

private struct SoundCloudMeResponse: Decodable {
    let username: String?
    let permalink: String?
}

// MARK: - Base64URL helper

private extension Data {
    /// RFC 4648 §5 base64url, no padding — required for PKCE code_challenge.
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
