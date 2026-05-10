import SwiftUI

struct SignUpView: View {
    @Environment(AuthService.self) private var authService
    @Environment(\.dismiss) private var dismiss

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var toast: Toast?

    private var formValid: Bool {
        !firstName.isEmpty && !lastName.isEmpty &&
        !email.isEmpty && !password.isEmpty && !confirmPassword.isEmpty
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    // Header
                    VStack(spacing: Theme.Spacing.sm) {
                        Text("Create Account")
                            .font(Theme.fontTitle)
                            .foregroundStyle(Theme.textPrimary)
                        Text("Start your fitness journey")
                            .font(Theme.fontCaption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.top, Theme.Spacing.xxl)
                    .padding(.bottom, Theme.Spacing.md)

                    // Form
                    VStack(spacing: 14) {
                        // Name row
                        HStack(spacing: 12) {
                            formField("First Name", text: $firstName)
                            formField("Last Name", text: $lastName)
                        }

                        formField("Email", text: $email, keyboard: .emailAddress, autocap: false)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Password")
                                .font(Theme.fontCaption)
                                .foregroundStyle(Theme.textSecondary)
                            SecureField("Min 8 characters", text: $password)
                                .padding(Theme.Spacing.md)
                                .background(Theme.surface)
                                .clipShape(.rect(cornerRadius: Theme.cornerRadius))
                                .foregroundStyle(Theme.textPrimary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.cornerRadius)
                                        .strokeBorder(Theme.hairline, lineWidth: 0.5)
                                )
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Confirm Password")
                                .font(Theme.fontCaption)
                                .foregroundStyle(Theme.textSecondary)
                            SecureField("Repeat password", text: $confirmPassword)
                                .padding(Theme.Spacing.md)
                                .background(Theme.surface)
                                .clipShape(.rect(cornerRadius: Theme.cornerRadius))
                                .foregroundStyle(Theme.textPrimary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.cornerRadius)
                                        .strokeBorder(Theme.hairline, lineWidth: 0.5)
                                )
                        }

                        Button {
                            signUp()
                        } label: {
                            if isLoading {
                                ProgressView()
                                    .tint(.black)
                            } else {
                                Text("Create Account")
                            }
                        }
                        .buttonStyle(AccentButtonStyle())
                        .disabled(isLoading || !formValid)
                        .opacity((isLoading || !formValid) ? 0.6 : 1)
                        .padding(.top, Theme.Spacing.sm)
                    }
                    .padding(.horizontal, Theme.Spacing.lg)

                    // Back to login
                    HStack(spacing: Theme.Spacing.tight) {
                        Text("Already have an account?")
                            .foregroundStyle(Theme.textSecondary)
                            .font(Theme.fontCaption)
                        Button {
                            dismiss()
                        } label: {
                            Text("Sign In")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.accent)
                        }
                    }
                    .padding(.top, Theme.Spacing.sm)

                    Spacer()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toast($toast)
    }

    // MARK: - Reusable Field

    private func formField(
        _ label: String,
        text: Binding<String>,
        keyboard: UIKeyboardType = .default,
        autocap: Bool = true
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(Theme.fontCaption)
                .foregroundStyle(Theme.textSecondary)
            TextField(label, text: text)
                .keyboardType(keyboard)
                .autocapitalization(autocap ? .words : .none)
                .autocorrectionDisabled()
                .padding(Theme.Spacing.md)
                .background(Theme.surface)
                .clipShape(.rect(cornerRadius: Theme.cornerRadius))
                .foregroundStyle(Theme.textPrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerRadius)
                        .strokeBorder(Theme.hairline, lineWidth: 0.5)
                )
        }
    }

    // MARK: - Sign Up

    private func signUp() {
        guard password.count >= Config.Validation.passwordMinLength else {
            showToast(.error, "Password must be at least \(Config.Validation.passwordMinLength) characters.")
            return
        }
        guard password == confirmPassword else {
            showToast(.error, "Passwords do not match.")
            return
        }

        isLoading = true
        Task {
            do {
                try await authService.signUp(
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password,
                    firstName: firstName.trimmingCharacters(in: .whitespaces),
                    lastName: lastName.trimmingCharacters(in: .whitespaces)
                )
                showToast(.success, "Account created! Check your email to confirm.")
            } catch {
                showToast(.error, error.localizedDescription)
            }
            isLoading = false
        }
    }

    private func showToast(_ style: Toast.Style, _ message: String) {
        withAnimation {
            toast = Toast(style: style, message: message)
        }
    }
}
