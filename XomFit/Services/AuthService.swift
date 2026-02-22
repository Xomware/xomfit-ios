import Foundation

@MainActor
class AuthService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func signIn(email: String, password: String) {
        isLoading = true
        errorMessage = nil
        
        // Mock auth — replace with real API
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.currentUser = .mock
            self?.isAuthenticated = true
            self?.isLoading = false
        }
    }
    
    func signUp(username: String, email: String, password: String) {
        isLoading = true
        errorMessage = nil
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.currentUser = .mock
            self?.isAuthenticated = true
            self?.isLoading = false
        }
    }
    
    func signInWithApple() {
        // TODO: Implement Apple Sign In
        signIn(email: "demo@xomfit.com", password: "demo")
    }
    
    func signOut() {
        currentUser = nil
        isAuthenticated = false
    }
}
