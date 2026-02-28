import Foundation
import AuthenticationServices
import CryptoKit

@MainActor
class AuthService: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isInitialized = false
    
    private var authStateTask: Task<Void, Never>?
    private var currentNonce: String? // Store nonce for Apple Sign In validation
    
    override init() {
        super.init()
        setupAuthStateListener()
        validateCurrentSession()
    }
    
    /// Validate current session on app launch
    private func validateCurrentSession() {
        Task {
            do {
                let session = try await supabase.auth.session
                // Session is valid, auth state listener will handle the rest
                await MainActor.run {
                    isInitialized = true
                }
            } catch {
                // No valid session or session expired
                await MainActor.run {
                    isAuthenticated = false
                    currentUser = nil
                    isInitialized = true
                }
            }
        }
    }
    
    /// Set up listener for auth state changes
    private func setupAuthStateListener() {
        authStateTask = Task {
            for await state in supabase.auth.authStateChanges {
                await MainActor.run {
                    switch state {
                    case .signedIn(let session):
                        self.isAuthenticated = true
                        // Create User from session metadata
                        self.currentUser = User(
                            id: session.user.id.uuidString,
                            username: session.user.userMetadata?["username"] as? String ?? "",
                            displayName: session.user.userMetadata?["display_name"] as? String ?? session.user.email ?? "",
                            avatarURL: session.user.userMetadata?["avatar_url"] as? String,
                            bio: session.user.userMetadata?["bio"] as? String ?? "",
                            stats: User.UserStats(
                                totalWorkouts: 0,
                                totalVolume: 0,
                                totalPRs: 0,
                                currentStreak: 0,
                                longestStreak: 0,
                                favoriteExercise: nil
                            ),
                            isPrivate: false,
                            createdAt: session.user.createdAt ?? Date()
                        )
                    case .signedOut:
                        self.isAuthenticated = false
                        self.currentUser = nil
                    @unknown default:
                        break
                    }
                }
            }
        }
    }
    
    /// Sign in with email and password
    func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            let session = try await supabase.auth.signIn(email: email, password: password)
            // Auth state listener will handle updating the UI
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            throw error
        }
    }
    
    /// Sign up with username, email, and password
    func signUp(username: String, email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            let session = try await supabase.auth.signUp(email: email, password: password)
            
            // Update user metadata with username
            try await supabase.auth.update(
                user: UserAttributes(data: [
                    "username": username,
                    "display_name": username
                ])
            )
            
            // Auth state listener will handle updating the UI
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            throw error
        }
    }
    
    /// Sign in with Apple using ASAuthorizationController with proper nonce
    func signInWithApple() {
        isLoading = true
        errorMessage = nil
        
        let nonce = generateNonce()
        let hashedNonce = sha256(nonce)
        
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = hashedNonce // Critical: Apple security requirement
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }
    
    /// Sign in with Google using web-based OAuth flow
    func signInWithGoogle() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Use Supabase's built-in OAuth flow for Google
                let session = try await supabase.auth.signInWithOAuth(provider: .google)
                // Auth state listener will handle updating the UI
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
    
    /// Sign out
    func signOut() async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            try await supabase.auth.signOut()
            // Auth state listener will handle updating the UI
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            throw error
        }
    }
    
    /// Handle OAuth redirect from deep link
    func handleOAuthRedirect(_ url: URL) async {
        do {
            let session = try await supabase.auth.session(from: url)
            // Auth state listener will handle updating the UI
            print("OAuth redirect handled successfully")
        } catch {
            await MainActor.run {
                errorMessage = "Failed to complete sign-in: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
    
    /// Reset password for a given email
    func resetPassword(email: String) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            try await supabase.auth.resetPasswordForEmail(email)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            throw error
        }
    }
    
    /// Force refresh current session
    func refreshSession() async throws {
        let session = try await supabase.auth.session
        // Auth state listener will handle updating the UI
    }
    
    // MARK: - Nonce Generation for Apple Sign In
    /// Generate a SHA256 hash nonce for Apple Sign In (security requirement)
    private func generateNonce() -> String {
        let nonce = UUID().uuidString
        self.currentNonce = nonce
        return nonce
    }
    
    /// SHA256 hash a string (required by Apple Sign In)
    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
    
    deinit {
        authStateTask?.cancel()
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension AuthService: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            errorMessage = "Failed to retrieve Apple ID credential"
            isLoading = false
            return
        }
        
        guard let identityToken = appleIDCredential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            errorMessage = "Failed to retrieve identity token"
            isLoading = false
            return
        }
        
        Task {
            do {
                let session = try await supabase.auth.signInWithIdToken(
                    credentials: .init(provider: .apple, idToken: tokenString)
                )
                
                // Update user metadata if we have a name or email
                var metadata: [String: Any] = [:]
                
                if let fullName = appleIDCredential.fullName,
                   let givenName = fullName.givenName,
                   let familyName = fullName.familyName {
                    let displayName = "\(givenName) \(familyName)"
                    metadata["display_name"] = displayName
                    metadata["first_name"] = givenName
                    metadata["last_name"] = familyName
                }
                
                // Cache email if provided (Apple only provides this once)
                if let email = appleIDCredential.email {
                    metadata["email"] = email
                    UserDefaults.standard.set(email, forKey: "cached_apple_email")
                }
                
                // Update metadata if we have any
                if !metadata.isEmpty {
                    try? await supabase.auth.update(
                        user: UserAttributes(data: metadata)
                    )
                }
                
                await MainActor.run {
                    isLoading = false
                }
                // Auth state listener will handle updating the UI
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
    
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        errorMessage = error.localizedDescription
        isLoading = false
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension AuthService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        return windowScene?.windows.first ?? ASPresentationAnchor()
    }
}
