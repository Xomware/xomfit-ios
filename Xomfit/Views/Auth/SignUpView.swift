import SwiftUI

struct SignUpView: View {
    @Environment(AuthService.self) private var authService
    @Environment(\.dismiss) private var dismiss

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var toast: Toast?

    private var formValid: Bool {
        !firstName.isEmpty && !lastName.isEmpty && !username.isEmpty &&
        !email.isEmpty && !password.isEmpty && !confirmPassword.isEmpty
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Theme.paddingLarge) {
                    // Header
                    VStack(spacing: Theme.paddingSmall) {
                        Text("Create Account")
                            .font(Theme.fontTitle)
                            .foregroundColor(Theme.textPrimary)
                        Text("Start your fitness journey")
                            .font(Theme.fontCaption)
                            .foregroundColor(Theme.textSecondary)
                    }
                    .padding(.top, 48)
                    .padding(.bottom, Theme.paddingMedium)

                    // Form
                    VStack(spacing: 14) {
                        // Name row
                        HStack(spacing: 12) {
                            formField("First Name", text: $firstName)
                            formField("Last Name", text: $lastName)
                        }

                        formField("Username", text: $username, keyboard: .default, autocap: false)

                        formField("Email", text: $email, keyboard: .emailAddress, autocap: false)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Password")
                                .font(Theme.fontCaption)
                                .foregroundColor(Theme.textSecondary)
                            SecureField("Min 8 characters", text: $password)
                                .padding(Theme.paddingMedium)
                                .background(Theme.cardBackground)
                                .cornerRadius(Theme.cornerRadius)
                                .foregroundColor(Theme.textPrimary)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Confirm Password")
                                .font(Theme.fontCaption)
                                .foregroundColor(Theme.textSecondary)
                            SecureField("Repeat password", text: $confirmPassword)
                                .padding(Theme.paddingMedium)
                                .background(Theme.cardBackground)
                                .cornerRadius(Theme.cornerRadius)
                                .foregroundColor(Theme.textPrimary)
                        }

                        Button {
                            signUp()
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                                    .fill(Theme.accent)
                                if isLoading {
                                    ProgressView()
                                        .tint(.black)
                                } else {
                                    Text("Create Account")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.black)
                                }
                            }
                            .frame(height: 52)
                        }
                        .disabled(isLoading || !formValid)
                        .opacity((isLoading || !formValid) ? 0.6 : 1)
                        .padding(.top, Theme.paddingSmall)
                    }
                    .padding(.horizontal, Theme.paddingLarge)

                    // Back to login
                    HStack(spacing: 4) {
                        Text("Already have an account?")
                            .foregroundColor(Theme.textSecondary)
                            .font(Theme.fontCaption)
                        Button {
                            dismiss()
                        } label: {
                            Text("Sign In")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Theme.accent)
                        }
                    }
                    .padding(.top, Theme.paddingSmall)

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
                .foregroundColor(Theme.textSecondary)
            TextField(label, text: text)
                .keyboardType(keyboard)
                .autocapitalization(autocap ? .words : .none)
                .autocorrectionDisabled()
                .padding(Theme.paddingMedium)
                .background(Theme.cardBackground)
                .cornerRadius(Theme.cornerRadius)
                .foregroundColor(Theme.textPrimary)
        }
    }

    // MARK: - Sign Up

    private func signUp() {
        let trimmedUsername = username.trimmingCharacters(in: .whitespaces).lowercased()

        guard trimmedUsername.count >= 3 else {
            showToast(.error, "Username must be at least 3 characters.")
            return
        }
        guard trimmedUsername.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else {
            showToast(.error, "Username can only contain letters, numbers, and underscores.")
            return
        }
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
                    lastName: lastName.trimmingCharacters(in: .whitespaces),
                    username: trimmedUsername
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
