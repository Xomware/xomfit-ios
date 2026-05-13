import AuthenticationServices
import CryptoKit
import Foundation
import Supabase

@MainActor
@Observable
final class AuthService {
    var isAuthenticated = false
    var needsProfileCompletion = false
    var needsOnboarding = false
    var currentSession: Session?
    var currentUser: User?
    var isLoading = true
    var errorMessage: String?

    // Apple Sign In state
    private var currentNonce: String?

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.environment["XOMFIT_AUTH_BYPASS"] == "1" {
            // Inject a mock signed-in user. Never hits Supabase. See #353.
            // Hydrates WorkoutService + TemplateService caches so screenshot
            // flows have data to render.
            let mockUser = User.mockDebug
            self.currentUser = mockUser
            self.currentSession = nil
            self.isAuthenticated = true
            self.needsProfileCompletion = false
            self.needsOnboarding = false
            self.isLoading = false

            WorkoutService.shared.seedDebugFixtures(userId: mockUser.id.uuidString)
            TemplateService.shared.seedDebugFixtures()

            // Mark fitness questionnaire as completed so bypass agents land in
            // the main app, not the onboarding gate.
            var profile = UserFitnessProfile.current
            if profile.completedAt == nil {
                profile.primaryGoal = .buildMuscle
                profile.experience = .intermediate
                profile.workoutsPerWeek = .four
                profile.preferredSplit = .upperLower
                profile.sessionLength = .sixty
                profile.completedAt = Date()
                UserFitnessProfile.current = profile
            }
            UserDefaults.standard.set(true, forKey: "onboardingSkipped")
            // Mark the first-workout tutorial seen so it doesn't overlay screenshots.
            UserDefaults.standard.set(true, forKey: "xomfit_first_workout_tutorial_seen")
            UserDefaults.standard.set(true, forKey: "xomfit_first_rest_timer_seen")

            print("[AuthService] DEBUG bypass active — using mock user \(mockUser.id.uuidString)")
            return
        }
        #endif
        Task { await listenForAuthChanges() }
    }

    private func listenForAuthChanges() async {
        for await (event, session) in supabase.auth.authStateChanges {
            self.currentSession = session
            self.currentUser = session?.user
            self.isAuthenticated = session != nil
            if session != nil {
                await checkProfileCompleteness()
            }
            if event == .initialSession {
                self.isLoading = false
            }
        }
    }

    // MARK: - Profile Completion

    func checkProfileCompleteness() async {
        guard let userId = currentUser?.id.uuidString else { return }
        do {
            let profile = try await ProfileService.shared.fetchProfile(userId: userId)
            let email = currentUser?.email ?? ""
            let emailPrefix = email.components(separatedBy: "@").first ?? ""
            needsProfileCompletion = profile.username.isEmpty
                || profile.username == profile.id
                || profile.username == emailPrefix

            if !needsProfileCompletion {
                needsOnboarding = !hasCompletedOnboarding()
            }
        } catch {
            needsProfileCompletion = true
        }
    }

    func profileCompleted() {
        needsProfileCompletion = false
        needsOnboarding = !hasCompletedOnboarding()
    }

    // MARK: - Onboarding

    func onboardingCompleted() {
        needsOnboarding = false
        markOnboardingComplete()
    }

    private var onboardingKey: String {
        "xomfit_onboarding_completed_\(currentUser?.id.uuidString.lowercased() ?? "")"
    }

    private func hasCompletedOnboarding() -> Bool {
        UserDefaults.standard.bool(forKey: onboardingKey)
    }

    private func markOnboardingComplete() {
        UserDefaults.standard.set(true, forKey: onboardingKey)
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

    func signUp(email: String, password: String, firstName: String, lastName: String, username: String = "") async throws {
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

    func prepareAppleSignIn() -> ASAuthorizationAppleIDRequest {
        let nonce = randomNonce()
        currentNonce = nonce
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        return request
    }

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

    // MARK: - Delete Account

    /// Permanently deletes the user's account. Calls a Supabase RPC named
    /// `delete_my_account` that is expected to handle row deletion + auth
    /// user removal server-side. Signs the user out locally on success.
    ///
    /// TODO: Confirm the `delete_my_account` Postgres function exists and
    /// is granted to `authenticated`. If it doesn't, surface the error to
    /// the user (we never silently no-op an account deletion).
    func deleteAccount() async throws {
        errorMessage = nil
        do {
            try await supabase.rpc("delete_my_account").execute()
        } catch {
            errorMessage = "Could not delete account: \(error.localizedDescription)"
            throw error
        }
        await signOut()
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

// MARK: - Debug Mock User (#353)
#if DEBUG
extension User {
    /// Mock Supabase auth user used by the `XOMFIT_AUTH_BYPASS=1` flow.
    /// All fields are placeholders — never hit any Supabase row.
    static let mockDebug = User(
        id: UUID(uuidString: "00000000-0000-0000-0000-00000000DEB6") ?? UUID(),
        appMetadata: [:],
        userMetadata: [
            "display_name": .string("Debug User"),
            "first_name": .string("Debug"),
            "last_name": .string("User"),
            "username": .string("debug_user")
        ],
        aud: "authenticated",
        email: "debug@xomfit.local",
        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
        updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
}

extension AppUser {
    /// Profile-shaped mock paired with `User.mockDebug` for views that consume
    /// `AppUser` rather than the Supabase auth `User`. Mirrors the debug user's id.
    static let mockDebug = AppUser(
        id: "00000000-0000-0000-0000-00000000DEB6",
        username: "debug_user",
        displayName: "Debug User",
        avatarURL: nil,
        bio: "Debug bypass — used by agent UI verification (#353)",
        stats: UserStats(
            totalWorkouts: 4,
            totalVolume: 25_400,
            totalPRs: 3,
            currentStreak: 2,
            longestStreak: 12,
            favoriteExercise: "Bench Press"
        ),
        isPrivate: false,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
}
#endif
