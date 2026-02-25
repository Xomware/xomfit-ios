import Foundation
import AuthenticationServices

@MainActor
class AuthService: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var authStateTask: Task<Void, Never>?
    
    override init() {
        super.init()
        setupAuthStateListener()
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
    
    /// Sign in with Apple using ASAuthorizationController
    func signInWithApple() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
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
                isLoading = true
                errorMessage = nil
                
                let session = try await supabase.auth.signInWithIdToken(
                    credentials: .init(provider: .apple, idToken: tokenString)
                )
                
                // Update user metadata if we have a name
                if let fullName = appleIDCredential.fullName {
                    let displayName = [fullName.givenName, fullName.familyName]
                        .compactMap { $0 }
                        .joined(separator: " ")
                    
                    try? await supabase.auth.update(
                        user: UserAttributes(data: [
                            "display_name": displayName
                        ])
                    )
                }
                
                // Auth state listener will handle updating the UI
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
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
