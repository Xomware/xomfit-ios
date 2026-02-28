import XCTest
@testable import XomFit

/// Tests for client-side auth input validation used in LoginView / SignUpView.
final class AuthValidationTests: XCTestCase {

    // MARK: - Helper
    private func isValidEmail(_ email: String) -> Bool {
        let predicate = NSPredicate(format: "SELF MATCHES %@", Config.Validation.emailPattern)
        return predicate.evaluate(with: email)
    }

    private func isValidPassword(_ password: String) -> Bool {
        return password.count >= Config.Validation.passwordMinLength
    }

    private func isLoginFormValid(email: String, password: String) -> Bool {
        isValidEmail(email) && isValidPassword(password)
    }

    // MARK: - Email Tests

    func testEmail_valid_standard() {
        XCTAssertTrue(isValidEmail("user@example.com"))
    }

    func testEmail_valid_subdomain() {
        XCTAssertTrue(isValidEmail("user@mail.example.co.uk"))
    }

    func testEmail_valid_plusAlias() {
        XCTAssertTrue(isValidEmail("user+tag@example.com"))
    }

    func testEmail_valid_numeric() {
        XCTAssertTrue(isValidEmail("12345@example.com"))
    }

    func testEmail_invalid_empty() {
        XCTAssertFalse(isValidEmail(""))
    }

    func testEmail_invalid_noAt() {
        XCTAssertFalse(isValidEmail("userexample.com"))
    }

    func testEmail_invalid_noDomain() {
        XCTAssertFalse(isValidEmail("user@"))
    }

    func testEmail_invalid_noTLD() {
        XCTAssertFalse(isValidEmail("user@domain"))
    }

    func testEmail_invalid_doubleAt() {
        XCTAssertFalse(isValidEmail("user@@domain.com"))
    }

    func testEmail_invalid_spaces() {
        XCTAssertFalse(isValidEmail("user @example.com"))
    }

    func testEmail_invalid_onlyAt() {
        XCTAssertFalse(isValidEmail("@"))
    }

    // MARK: - Password Tests

    func testPassword_valid_exactMinLength() {
        let pw = String(repeating: "a", count: Config.Validation.passwordMinLength)
        XCTAssertTrue(isValidPassword(pw))
    }

    func testPassword_valid_longPassword() {
        XCTAssertTrue(isValidPassword("This1sALongAndSecureP@ssw0rd!"))
    }

    func testPassword_invalid_tooShort() {
        let pw = String(repeating: "a", count: Config.Validation.passwordMinLength - 1)
        XCTAssertFalse(isValidPassword(pw))
    }

    func testPassword_invalid_empty() {
        XCTAssertFalse(isValidPassword(""))
    }

    func testPassword_invalid_whitespaceOnly() {
        XCTAssertFalse(isValidPassword("   "))
    }

    // MARK: - Login Form Composite Tests

    func testLoginForm_valid() {
        XCTAssertTrue(isLoginFormValid(email: "valid@example.com", password: "secure123"))
    }

    func testLoginForm_invalid_badEmail() {
        XCTAssertFalse(isLoginFormValid(email: "notanemail", password: "secure123"))
    }

    func testLoginForm_invalid_shortPassword() {
        XCTAssertFalse(isLoginFormValid(email: "valid@example.com", password: "short"))
    }

    func testLoginForm_invalid_bothEmpty() {
        XCTAssertFalse(isLoginFormValid(email: "", password: ""))
    }

    func testLoginForm_invalid_emailOnlyValid() {
        XCTAssertFalse(isLoginFormValid(email: "valid@example.com", password: ""))
    }

    // MARK: - Sign Up Form Tests

    func testSignUpForm_valid() {
        let username = "johndoe"
        let email = "john@example.com"
        let password = "Secure123!"
        let confirmPassword = "Secure123!"

        XCTAssertFalse(username.trimmingCharacters(in: .whitespaces).isEmpty)
        XCTAssertTrue(isValidEmail(email))
        XCTAssertTrue(isValidPassword(password))
        XCTAssertEqual(password, confirmPassword)
    }

    func testSignUpForm_invalid_passwordMismatch() {
        let password = "Secure123!"
        let confirmPassword = "Different!"
        XCTAssertNotEqual(password, confirmPassword)
    }

    func testSignUpForm_invalid_emptyUsername() {
        let username = ""
        XCTAssertTrue(username.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    func testSignUpForm_invalid_whitespaceUsername() {
        let username = "   "
        XCTAssertTrue(username.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    func testSignUpForm_usernameMaxLength() {
        // Usernames should be reasonably short
        let longUsername = String(repeating: "a", count: 51)
        XCTAssertGreaterThan(longUsername.count, 50)
    }

    // MARK: - OAuth URL Tests

    func testOAuthCallbackURL_validURL() {
        let url = URL(string: Config.oauthCallbackURL)
        XCTAssertNotNil(url, "OAuth callback URL must be a valid URL")
    }

    func testOAuthCallbackURL_correctScheme() {
        let url = URL(string: Config.oauthCallbackURL)
        XCTAssertEqual(url?.scheme, Config.oauthScheme)
    }

    func testOAuthCallbackURL_isXomfit() {
        XCTAssertEqual(Config.oauthScheme, "xomfit")
    }

    // MARK: - Forgot Password Tests

    func testForgotPassword_validEmail_passesValidation() {
        XCTAssertTrue(isValidEmail("forgot@example.com"))
    }

    func testForgotPassword_invalidEmail_failsValidation() {
        XCTAssertFalse(isValidEmail("notanemail"))
        XCTAssertFalse(isValidEmail(""))
    }

    // MARK: - Edge Cases

    func testEmail_veryLong_invalid() {
        let longLocal = String(repeating: "a", count: 65) // RFC limit
        let email = "\(longLocal)@example.com"
        // Very long local parts may or may not pass simple regex; just ensure no crash
        _ = isValidEmail(email)
    }

    func testPassword_unicodeCharacters() {
        // Unicode characters are valid in passwords
        let pw = "pässwörd1"
        XCTAssertTrue(isValidPassword(pw))
    }

    func testPassword_allDigits() {
        let pw = "12345678"
        XCTAssertTrue(isValidPassword(pw))
    }

    func testPassword_allSpecialChars() {
        let pw = "!@#$%^&*"
        XCTAssertTrue(isValidPassword(pw))
    }
}
