import AuthenticationServices
import CryptoKit
import Foundation
import Supabase

@MainActor
@Observable
final class AuthService {
    var isAuthenticated = false
    var currentSession: Session?
    var currentUser: User?
    var isLoading = true
    var errorMessage: String?

    // Apple Sign In state
    private var currentNonce: String?

    init() {
        Task { await listenForAuthChanges() }
    }

    private func listenForAuthChanges() async {
        for await (event, session) in supabase.auth.authStateChanges {
            self.currentSession = session
            self.currentUser = session?.user
            self.isAuthenticated = session != nil
            if event == .initialSession {
                self.isLoading = false
            }
        }
    }

    // MARK: - Email Auth

    func signIn(email: String, password: String) async throws {
        errorMessage = nil
        let session = try await supabase.auth.signIn(
            email: email,
            password: password
        )
        self.currentSession = session
        self.currentUser = session.user
        self.isAuthenticated = true
    }

    func signUp(email: String, password: String, firstName: String, lastName: String, username: String) async throws {
        errorMessage = nil
        let displayName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        let response = try await supabase.auth.signUp(
            email: email,
            password: password,
            data: [
                "display_name": .string(displayName),
                "first_name": .string(firstName),
                "last_name": .string(lastName),
                "username": .string(username)
            ]
        )
        if let session = response.session {
            self.currentSession = session
            self.currentUser = session.user
            self.isAuthenticated = true
        }
    }

    // MARK: - Apple Sign In

    /// Generate nonce and return ASAuthorizationAppleIDRequest
    func prepareAppleSignIn() -> ASAuthorizationAppleIDRequest {
        let nonce = randomNonce()
        currentNonce = nonce
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        return request
    }

    /// Handle the Apple Sign In result
    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        errorMessage = nil
        switch result {
        case .success(let authorization):
            guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityTokenData = appleCredential.identityToken,
                  let identityToken = String(data: identityTokenData, encoding: .utf8),
                  let nonce = currentNonce else {
                errorMessage = "Failed to get Apple credentials"
                return
            }

            do {
                let session = try await supabase.auth.signInWithIdToken(
                    credentials: .init(
                        provider: .apple,
                        idToken: identityToken,
                        nonce: nonce
                    )
                )
                self.currentSession = session
                self.currentUser = session.user
                self.isAuthenticated = true
            } catch {
                errorMessage = error.localizedDescription
            }

        case .failure(let error):
            // User cancelled is not an error worth showing
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Google Sign In (OAuth via Supabase)

    func signInWithGoogle() async {
        errorMessage = nil
        do {
            try await supabase.auth.signInWithOAuth(
                provider: .google,
                redirectTo: URL(string: Config.oauthCallbackURL)
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Sign Out

    func signOut() async {
        errorMessage = nil
        do {
            try await supabase.auth.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
        self.currentSession = nil
        self.currentUser = nil
        self.isAuthenticated = false
    }

    // MARK: - Nonce Helpers

    private func randomNonce(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}
