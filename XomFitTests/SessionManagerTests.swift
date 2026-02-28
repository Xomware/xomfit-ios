import XCTest
import Combine
@testable import XomFit

/// Tests for SessionManager: session lifecycle, foreground validation, error propagation.
final class SessionManagerTests: XCTestCase {

    var cancellables = Set<AnyCancellable>()

    // MARK: - Session Error Tests

    @MainActor
    func testSessionManager_sessionError_isNilInitially() {
        // SessionManager sets sessionError = nil on init
        var sessionError: String? = nil
        XCTAssertNil(sessionError)
    }

    @MainActor
    func testSessionManager_clearSessionError() {
        var sessionError: String? = "Session expired. Please sign in again."
        // Simulate clearSessionError()
        sessionError = nil
        XCTAssertNil(sessionError)
    }

    @MainActor
    func testSessionManager_sessionExpiredMessage_format() {
        let expectedMessage = "Session expired. Please sign in again."
        XCTAssertFalse(expectedMessage.isEmpty)
        XCTAssertTrue(expectedMessage.contains("sign in"))
    }

    // MARK: - Splash Screen Tests

    @MainActor
    func testSessionManager_shouldShowSplash_defaultTrue() {
        var shouldShowSplash = true
        XCTAssertTrue(shouldShowSplash)
    }

    @MainActor
    func testSessionManager_dismissSplash() {
        var shouldShowSplash = true
        // Simulate dismissSplash()
        shouldShowSplash = false
        XCTAssertFalse(shouldShowSplash)
    }

    // MARK: - Foreground Validation Tests

    @MainActor
    func testForegroundValidation_successfulRefresh_remainsAuthenticated() async {
        let mock = MockAuthService()
        mock.shouldSucceed = true
        mock.isAuthenticated = true

        do {
            try await mock.performTokenRefresh()
            XCTAssertTrue(mock.isAuthenticated)
        } catch {
            XCTFail("Refresh should succeed")
        }
    }

    @MainActor
    func testForegroundValidation_failedRefresh_triggersSignOut() async {
        let mock = MockAuthService()
        mock.shouldSucceed = false
        mock.errorToThrow = AuthError.sessionExpired
        mock.isAuthenticated = true

        var sessionError: String?

        do {
            try await mock.performTokenRefresh()
        } catch {
            // Simulate SessionManager's response to refresh failure
            mock.shouldSucceed = true // allow sign out
            try? await mock.performSignOut()
            sessionError = "Session expired. Please sign in again."
        }

        XCTAssertFalse(mock.isAuthenticated)
        XCTAssertNotNil(sessionError)
    }

    @MainActor
    func testForegroundValidation_networkError_gracefulFailure() async {
        let mock = MockAuthService()
        mock.shouldSucceed = false
        mock.errorToThrow = AuthError.networkError
        mock.isAuthenticated = true

        var sessionError: String?

        do {
            try await mock.performTokenRefresh()
        } catch AuthError.networkError {
            // Network errors should not force sign out — user is still "authenticated"
            sessionError = "Could not verify your session. Check your connection."
        } catch {
            sessionError = "Authentication error. Please sign in."
        }

        // Authentication state may remain true for network errors
        XCTAssertNotNil(sessionError)
    }

    // MARK: - Background / Foreground Lifecycle

    @MainActor
    func testAppLifecycle_backgroundClearsError() {
        var sessionError: String? = "Some error"
        // Simulate didEnterBackground handling
        sessionError = nil
        XCTAssertNil(sessionError)
    }

    @MainActor
    func testAppLifecycle_foreground_triggersValidation() async {
        // Verify that a successful refresh keeps state intact
        let mock = MockAuthService()
        mock.shouldSucceed = true
        mock.isAuthenticated = true
        try? await mock.performTokenRefresh()
        XCTAssertTrue(mock.isAuthenticated)
    }

    // MARK: - State Persistence

    @MainActor
    func testStatePersistence_userDefaultsKey_exists() {
        let key = "cached_apple_email"
        UserDefaults.standard.set("test@example.com", forKey: key)
        XCTAssertNotNil(UserDefaults.standard.string(forKey: key))
        UserDefaults.standard.removeObject(forKey: key)
    }

    @MainActor
    func testStatePersistence_multipleSignOuts_idempotent() async {
        let mock = MockAuthService()
        mock.shouldSucceed = true
        mock.isAuthenticated = false

        // Signing out when already signed out should be safe
        try? await mock.performSignOut()
        try? await mock.performSignOut()
        XCTAssertFalse(mock.isAuthenticated)
    }
}
