import SwiftUI

struct SignUpView: View {
    @Environment(AuthService.self) private var authService
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var validationError: String?

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
                    VStack(spacing: Theme.paddingMedium) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Email")
                                .font(Theme.fontCaption)
                                .foregroundColor(Theme.textSecondary)
                            TextField("you@example.com", text: $email)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .padding(Theme.paddingMedium)
                                .background(Theme.cardBackground)
                                .cornerRadius(Theme.cornerRadius)
                                .foregroundColor(Theme.textPrimary)
                        }

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

                        // Validation / auth error
                        let displayError = validationError ?? authService.errorMessage
                        if let error = displayError {
                            Text(error)
                                .font(Theme.fontCaption)
                                .foregroundColor(Theme.destructive)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, Theme.paddingSmall)
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
                        .disabled(isLoading || email.isEmpty || password.isEmpty || confirmPassword.isEmpty)
                        .opacity((isLoading || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) ? 0.6 : 1)
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
    }

    private func signUp() {
        validationError = nil
        authService.errorMessage = nil

        guard password.count >= Config.Validation.passwordMinLength else {
            validationError = "Password must be at least \(Config.Validation.passwordMinLength) characters."
            return
        }
        guard password == confirmPassword else {
            validationError = "Passwords do not match."
            return
        }

        isLoading = true
        Task {
            do {
                try await authService.signUp(email: email, password: password)
            } catch {
                authService.errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
