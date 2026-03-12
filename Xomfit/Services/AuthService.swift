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

    func signUp(email: String, password: String) async throws {
        errorMessage = nil
        let response = try await supabase.auth.signUp(
            email: email,
            password: password
        )
        if let session = response.session {
            self.currentSession = session
            self.currentUser = session.user
            self.isAuthenticated = true
        }
    }

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
}
