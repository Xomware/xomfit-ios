import Foundation
import SwiftUI

/// Manages secure session lifecycle with Keychain persistence and app lifecycle handling
@MainActor
class SessionManager: NSObject, ObservableObject {
    static let shared = SessionManager()
    
    @Published var authService: AuthService
    @Published var shouldShowSplash = true
    @Published var sessionError: String?
    
    private var foregroundObserver: NSObjectProtocol?
    private var backgroundObserver: NSObjectProtocol?
    
    override init() {
        self.authService = AuthService()
        super.init()
        setupAppLifecycleObservers()
    }
    
    /// Setup observers for app lifecycle events
    private func setupAppLifecycleObservers() {
        // Handle app entering foreground
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.validateSessionOnForeground()
            }
        }
        
        // Handle app entering background
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.clearSessionError()
        }
    }
    
    /// Validate session when app returns to foreground
    private func validateSessionOnForeground() async {
        do {
            try await authService.refreshSession()
        } catch {
            // Token refresh failed - force logout
            do {
                try await authService.signOut()
                sessionError = "Session expired. Please sign in again."
            } catch {
                sessionError = "Authentication error. Please sign in."
            }
        }
    }
    
    /// Clear splash screen after auth state is initialized
    func dismissSplash() {
        withAnimation {
            shouldShowSplash = false
        }
    }
    
    /// Clear session error
    func clearSessionError() {
        sessionError = nil
    }
    
    deinit {
        if let observer = foregroundObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = backgroundObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
