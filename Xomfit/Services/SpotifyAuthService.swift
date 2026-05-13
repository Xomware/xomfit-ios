import AuthenticationServices
import CryptoKit
import Foundation
import SwiftUI
import UIKit

/// Spotify OAuth 2.0 Authorization Code with PKCE (#347).
///
/// ## Why PKCE (no client secret)
/// Spotify's recommended flow for native apps. The client id is public; the PKCE verifier
/// stays in-process and prevents code interception. We never ship or store a client secret.
///
/// ## Storage caveat
/// Tokens are persisted via `@AppStorage` (UserDefaults) for v1 — readable by anyone with
/// device access. Migrating to Keychain is tracked separately and explicitly out of scope here.
///
/// ## Callback delivery
/// `ASWebAuthenticationSession` returns the redirect URL directly to our completion handler,
/// so no `CFBundleURLTypes` registration is required. The `XomfitApp.onOpenURL` handler is a
/// belt-and-suspenders fallback in case Safari View Controller hands the URL back to the app
/// instead of the session.
@MainActor
@Observable
final class SpotifyAuthService: NSObject {
    static let shared = SpotifyAuthService()

    // MARK: - Persisted state

    @ObservationIgnored @AppStorage("spotifyClientId") private var clientIdSetting: String = ""
    @ObservationIgnored @AppStorage("spotify.accessToken") private var accessToken: String = ""
    @ObservationIgnored @AppStorage("spotify.refreshToken") private var refreshToken: String = ""
    @ObservationIgnored @AppStorage("spotify.tokenExpiry") private var tokenExpiryEpoch: Double = 0
    @ObservationIgnored @AppStorage("spotify.displayName") private var displayNameStorage: String = ""

    // MARK: - Observable mirror

    /// Mirror of the `@AppStorage` flags above so SwiftUI views observing `SpotifyAuthService`
    /// re-render after sign-in / sign-out. `@AppStorage` doesn't notify our `@Observable` macro.
    private(set) var isAuthenticated: Bool = false
    private(set) var displayName: String = ""

    // MARK: - In-flight state

    private var pendingPKCEVerifier: String?
    private var pendingState: String?
    /// Continuation for the in-flight `signIn()`. Resumed when the deep-link callback hits.
    private var pendingSignInContinuation: CheckedContinuation<Bool, Error>?
    private var webAuthSession: ASWebAuthenticationSession?

    private override init() {
        super.init()
        // Hydrate observable mirror from persisted storage at launch.
        isAuthenticated = !accessToken.isEmpty
        displayName = displayNameStorage
    }

    // MARK: - Public API

    /// Begin the OAuth dance. Returns `true` on a successful token exchange.
    ///
    /// Throws:
    ///   - `SpotifyAuthError.missingClientId` — user hasn't pasted a client id into Settings yet
    ///   - `SpotifyAuthError.userCancelled` — user dismissed the in-app browser
    ///   - `SpotifyAuthError.callbackInvalid` — Spotify returned an error or unexpected payload
    ///   - `SpotifyAuthError.tokenExchangeFailed` — `/api/token` returned non-2xx
    @discardableResult
    func signIn() async throws -> Bool {
        guard !clientIdSetting.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw SpotifyAuthError.missingClientId
        }

        // Build PKCE pair + anti-CSRF state up front, stash for the callback.
        let verifier = Self.generatePKCEVerifier()
        let challenge = Self.codeChallenge(for: verifier)
        let state = Self.randomURLSafeString(length: 16)
        pendingPKCEVerifier = verifier
        pendingState = state

        guard let authURL = buildAuthorizeURL(challenge: challenge, state: state) else {
            throw SpotifyAuthError.callbackInvalid
        }

        // ASWebAuthenticationSession returns the callback URL via its completion handler.
        let callbackURL: URL = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: SpotifyConfig.callbackURLScheme
            ) { url, error in
                if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    cont.resume(throwing: SpotifyAuthError.userCancelled)
                    return
                }
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                guard let url else {
                    cont.resume(throwing: SpotifyAuthError.callbackInvalid)
                    return
                }
                cont.resume(returning: url)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.webAuthSession = session
            if !session.start() {
                cont.resume(throwing: SpotifyAuthError.callbackInvalid)
            }
        }

        let code = try parseCallback(url: callbackURL, expectedState: state)
        try await exchangeCodeForToken(code: code, verifier: verifier)
        try await refreshUserDisplayName()
        return true
    }

    /// Last-resort callback handler invoked from `XomfitApp.onOpenURL` if the OS routes the
    /// redirect through the app rather than ASWebAuthenticationSession's completion handler.
    /// Today this is a no-op success path because the in-flight session handles it; we keep it
    /// for symmetry + forward-compat if we later switch to a hosted login screen.
    func handleCallback(url: URL) {
        guard url.scheme == SpotifyConfig.callbackURLScheme,
              url.host == "spotify-callback" else { return }
        // ASWebAuthenticationSession already received this. Nothing to do — log for visibility.
        print("[SpotifyAuth] handleCallback received url (ASWebAuthSession should have handled it)")
    }

    /// Forget the tokens locally. Does not call Spotify's token-revoke endpoint (Spotify
    /// doesn't expose one for end users); the session simply stops polling.
    func signOut() {
        accessToken = ""
        refreshToken = ""
        tokenExpiryEpoch = 0
        displayNameStorage = ""
        isAuthenticated = false
        displayName = ""
    }

    /// Returns a fresh access token, refreshing via the stored refresh token if the cached
    /// one is within 60s of expiry. Returns nil when the user hasn't signed in (or the
    /// refresh attempt failed — caller treats that as silent no-op).
    func currentTokenRefreshingIfNeeded() async -> String? {
        guard !accessToken.isEmpty else { return nil }

        let now = Date().timeIntervalSince1970
        // Refresh proactively to avoid the racy "401 mid-poll" window.
        if tokenExpiryEpoch - now < 60, !refreshToken.isEmpty {
            do {
                try await refreshAccessToken()
            } catch {
                print("[SpotifyAuth] refresh failed: \(error)")
                return nil
            }
        }
        return accessToken.isEmpty ? nil : accessToken
    }

    // MARK: - URL construction

    private func buildAuthorizeURL(challenge: String, state: String) -> URL? {
        var components = URLComponents(url: SpotifyConfig.authBaseURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientIdSetting),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: SpotifyConfig.redirectURI),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "scope", value: SpotifyConfig.scopes)
        ]
        return components?.url
    }

    private func parseCallback(url: URL, expectedState: String) throws -> String {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw SpotifyAuthError.callbackInvalid
        }
        let items = components.queryItems ?? []
        if let err = items.first(where: { $0.name == "error" })?.value {
            print("[SpotifyAuth] callback error: \(err)")
            throw SpotifyAuthError.callbackInvalid
        }
        guard let returnedState = items.first(where: { $0.name == "state" })?.value,
              returnedState == expectedState else {
            throw SpotifyAuthError.callbackInvalid
        }
        guard let code = items.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
            throw SpotifyAuthError.callbackInvalid
        }
        return code
    }

    // MARK: - Token exchange

    private func exchangeCodeForToken(code: String, verifier: String) async throws {
        var request = URLRequest(url: SpotifyConfig.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = formEncoded([
            "client_id": clientIdSetting,
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": SpotifyConfig.redirectURI,
            "code_verifier": verifier
        ])
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            print("[SpotifyAuth] token exchange non-2xx — \(String(data: data, encoding: .utf8) ?? "")")
            throw SpotifyAuthError.tokenExchangeFailed
        }
        let payload = try JSONDecoder().decode(TokenResponse.self, from: data)
        storeToken(payload)
    }

    private func refreshAccessToken() async throws {
        guard !refreshToken.isEmpty else { throw SpotifyAuthError.tokenExchangeFailed }
        var request = URLRequest(url: SpotifyConfig.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = formEncoded([
            "client_id": clientIdSetting,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ])
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            print("[SpotifyAuth] refresh non-2xx — \(String(data: data, encoding: .utf8) ?? "")")
            // If Spotify rejected the refresh token (e.g. user revoked), drop local state so
            // the UI returns to the "Sign In" affordance instead of silently failing forever.
            if let http = response as? HTTPURLResponse, http.statusCode == 400 {
                signOut()
            }
            throw SpotifyAuthError.tokenExchangeFailed
        }
        let payload = try JSONDecoder().decode(TokenResponse.self, from: data)
        storeToken(payload)
    }

    private func storeToken(_ payload: TokenResponse) {
        accessToken = payload.access_token
        // Spotify may or may not rotate the refresh token. Keep the previous when omitted.
        if let new = payload.refresh_token, !new.isEmpty {
            refreshToken = new
        }
        let expiresIn = payload.expires_in ?? 3600
        tokenExpiryEpoch = Date().timeIntervalSince1970 + Double(expiresIn)
        isAuthenticated = true
    }

    // MARK: - Profile

    /// Pulls `/v1/me` once after sign-in to surface the user's display name in Settings.
    /// Failure is non-fatal — we still consider sign-in successful with an empty display.
    private func refreshUserDisplayName() async throws {
        guard let token = await currentTokenRefreshingIfNeeded() else { return }
        var request = URLRequest(url: URL(string: "https://api.spotify.com/v1/me")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return }
            let profile = try JSONDecoder().decode(SpotifyMeResponse.self, from: data)
            let resolved = profile.display_name ?? profile.id ?? ""
            displayNameStorage = resolved
            displayName = resolved
        } catch {
            print("[SpotifyAuth] /v1/me lookup failed: \(error)")
        }
    }

    // MARK: - PKCE helpers

    private static func generatePKCEVerifier() -> String {
        // Per RFC 7636: 43–128 chars from the URL-safe alphabet. 64 bytes -> 86 chars (>43).
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

    private func formEncoded(_ params: [String: String]) -> String {
        params
            .map { key, value in
                let escapedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryParamAllowed) ?? key
                let escapedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryParamAllowed) ?? value
                return "\(escapedKey)=\(escapedValue)"
            }
            .joined(separator: "&")
    }
}

// MARK: - Presentation context

extension SpotifyAuthService: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Walk to the foreground scene's key window. UIKit on the main actor — bounce off.
        MainActor.assumeIsolated {
            let scene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first(where: { $0.activationState == .foregroundActive })
                ?? UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .first
            if let key = scene?.keyWindow { return key }
            // Fallback: construct a transient window in the resolved scene rather than calling
            // the now-deprecated `ASPresentationAnchor()` initializer. Practically unreachable —
            // logged in case we ever hit it during sign-in.
            if let scene { return UIWindow(windowScene: scene) }
            return UIWindow()
        }
    }
}

// MARK: - Errors + payloads

enum SpotifyAuthError: LocalizedError {
    case missingClientId
    case userCancelled
    case callbackInvalid
    case tokenExchangeFailed

    var errorDescription: String? {
        switch self {
        case .missingClientId:
            return "Paste your Spotify Client ID in Settings -> Music Sources before signing in."
        case .userCancelled:
            return "Spotify sign-in was cancelled."
        case .callbackInvalid:
            return "Spotify returned an invalid response."
        case .tokenExchangeFailed:
            return "Couldn't exchange the Spotify auth code. Try signing in again."
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

private struct SpotifyMeResponse: Decodable {
    let id: String?
    let display_name: String?
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

private extension CharacterSet {
    /// Strict `application/x-www-form-urlencoded` allowed set. `.urlQueryAllowed` accepts
    /// `+` and `=` which Spotify's token endpoint mis-parses as the literal characters.
    static let urlQueryParamAllowed: CharacterSet = {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return allowed
    }()
}
