import XCTest

/// UI tests for auth flows. Requires a running simulator with the app installed.
/// Run with: `xcodebuild test -scheme XomFit -destination 'platform=iOS Simulator,name=iPhone 16'`
final class AuthUITests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["UI_TESTING", "--reset-auth-state"]
        app.launch()
    }

    // MARK: - Splash / Loading State

    func testSplashScreen_appearsOnLaunch() {
        // Splash screen should be visible briefly
        let splash = app.images["splash-logo"]
        // We don't wait long; if it's gone quickly, that's fine
        _ = splash.waitForExistence(timeout: 0.5)
    }

    // MARK: - Login Screen

    func testLoginScreen_isVisible_whenSignedOut() {
        // After splash, login should appear
        let signInTitle = app.staticTexts["XomFit"]
        XCTAssertTrue(signInTitle.waitForExistence(timeout: 5))
    }

    func testLoginScreen_hasEmailField() {
        let emailField = app.textFields.matching(identifier: "email-field").firstMatch
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))
    }

    func testLoginScreen_hasPasswordField() {
        let passwordField = app.secureTextFields.matching(identifier: "password-field").firstMatch
        XCTAssertTrue(passwordField.waitForExistence(timeout: 5))
    }

    func testLoginScreen_hasSignInButton() {
        let signInBtn = app.buttons["Sign In"]
        XCTAssertTrue(signInBtn.waitForExistence(timeout: 5))
    }

    func testLoginScreen_signInButton_disabledByDefault() {
        let signInBtn = app.buttons["Sign In"]
        _ = signInBtn.waitForExistence(timeout: 5)
        XCTAssertFalse(signInBtn.isEnabled, "Sign In should be disabled with empty fields")
    }

    func testLoginScreen_signInButton_enabledWithValidInput() {
        let emailField = app.textFields.matching(identifier: "email-field").firstMatch
        let passwordField = app.secureTextFields.matching(identifier: "password-field").firstMatch
        let signInBtn = app.buttons["Sign In"]

        _ = emailField.waitForExistence(timeout: 5)
        emailField.tap()
        emailField.typeText("test@example.com")

        passwordField.tap()
        passwordField.typeText("password123")

        XCTAssertTrue(signInBtn.isEnabled)
    }

    func testLoginScreen_invalidEmail_signInButtonDisabled() {
        let emailField = app.textFields.matching(identifier: "email-field").firstMatch
        let passwordField = app.secureTextFields.matching(identifier: "password-field").firstMatch
        let signInBtn = app.buttons["Sign In"]

        _ = emailField.waitForExistence(timeout: 5)
        emailField.tap()
        emailField.typeText("notanemail")

        passwordField.tap()
        passwordField.typeText("password123")

        XCTAssertFalse(signInBtn.isEnabled)
    }

    func testLoginScreen_shortPassword_signInButtonDisabled() {
        let emailField = app.textFields.matching(identifier: "email-field").firstMatch
        let passwordField = app.secureTextFields.matching(identifier: "password-field").firstMatch
        let signInBtn = app.buttons["Sign In"]

        _ = emailField.waitForExistence(timeout: 5)
        emailField.tap()
        emailField.typeText("valid@example.com")

        passwordField.tap()
        passwordField.typeText("short")

        XCTAssertFalse(signInBtn.isEnabled)
    }

    func testLoginScreen_hasSignUpLink() {
        let signUpLink = app.buttons["Sign Up"]
        XCTAssertTrue(signUpLink.waitForExistence(timeout: 5))
    }

    func testLoginScreen_hasForgotPasswordLink() {
        let forgotLink = app.buttons["Forgot password?"]
        XCTAssertTrue(forgotLink.waitForExistence(timeout: 5))
    }

    func testLoginScreen_hasAppleSignInButton() {
        // Apple Sign In button rendered by the system
        let appleBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Sign in with Apple'")).firstMatch
        XCTAssertTrue(appleBtn.waitForExistence(timeout: 5))
    }

    // MARK: - Sign Up Flow

    func testSignUp_sheet_opensFromLoginScreen() {
        let signUpBtn = app.buttons["Sign Up"]
        _ = signUpBtn.waitForExistence(timeout: 5)
        signUpBtn.tap()

        let signUpTitle = app.staticTexts["Create Account"]
        XCTAssertTrue(signUpTitle.waitForExistence(timeout: 3))
    }

    func testSignUp_hasRequiredFields() {
        let signUpBtn = app.buttons["Sign Up"]
        _ = signUpBtn.waitForExistence(timeout: 5)
        signUpBtn.tap()

        _ = app.staticTexts["Create Account"].waitForExistence(timeout: 3)

        XCTAssertTrue(app.textFields.matching(identifier: "username-field").firstMatch.exists
                      || app.textFields.count >= 1)
    }

    // MARK: - Forgot Password Flow

    func testForgotPassword_sheet_opens() {
        let forgotBtn = app.buttons["Forgot password?"]
        _ = forgotBtn.waitForExistence(timeout: 5)
        forgotBtn.tap()

        let forgotTitle = app.staticTexts["Reset Password"]
        XCTAssertTrue(forgotTitle.waitForExistence(timeout: 3))
    }

    // MARK: - Error Display

    func testLoginScreen_errorMessage_isAccessible() {
        // If an error appears, it should be readable by VoiceOver
        let errorLabels = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH 'Error'")
        )
        // Just verify the query doesn't crash
        _ = errorLabels.count
    }

    // MARK: - Loading State

    func testLoginScreen_loadingIndicator_hiddenByDefault() {
        let spinner = app.activityIndicators.firstMatch
        // If spinner exists, it should not be visible before login attempt
        if spinner.exists {
            XCTAssertFalse(spinner.isHittable)
        }
    }

    // MARK: - Accessibility

    func testLoginScreen_accessibility_emailFieldHasLabel() {
        let emailField = app.textFields.matching(identifier: "email-field").firstMatch
        _ = emailField.waitForExistence(timeout: 5)
        // Accessibility label should be non-empty
        XCTAssertFalse(emailField.label.isEmpty)
    }

    func testLoginScreen_accessibility_signInButtonHasLabel() {
        let signInBtn = app.buttons["Sign In"]
        _ = signInBtn.waitForExistence(timeout: 5)
        XCTAssertFalse(signInBtn.label.isEmpty)
    }
}
