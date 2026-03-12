import SwiftUI

struct LoginView: View {
    @Environment(AuthService.self) private var authService

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showSignUp = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.paddingLarge) {
                        // Logo / Header
                        VStack(spacing: Theme.paddingSmall) {
                            Text("XOMFIT")
                                .font(.system(size: 42, weight: .black))
                                .foregroundColor(Theme.accent)
                                .tracking(4)
                            Text("Track. Lift. Grow.")
                                .font(Theme.fontCaption)
                                .foregroundColor(Theme.textSecondary)
                        }
                        .padding(.top, 60)
                        .padding(.bottom, Theme.paddingLarge)

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
                                SecureField("••••••••", text: $password)
                                    .padding(Theme.paddingMedium)
                                    .background(Theme.cardBackground)
                                    .cornerRadius(Theme.cornerRadius)
                                    .foregroundColor(Theme.textPrimary)
                            }

                            if let error = authService.errorMessage {
                                Text(error)
                                    .font(Theme.fontCaption)
                                    .foregroundColor(Theme.destructive)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, Theme.paddingSmall)
                            }

                            Button {
                                signIn()
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: Theme.cornerRadius)
                                        .fill(Theme.accent)
                                    if isLoading {
                                        ProgressView()
                                            .tint(.black)
                                    } else {
                                        Text("Sign In")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.black)
                                    }
                                }
                                .frame(height: 52)
                            }
                            .disabled(isLoading || email.isEmpty || password.isEmpty)
                            .opacity((isLoading || email.isEmpty || password.isEmpty) ? 0.6 : 1)
                            .padding(.top, Theme.paddingSmall)
                        }
                        .padding(.horizontal, Theme.paddingLarge)

                        // Sign up link
                        HStack(spacing: 4) {
                            Text("Don't have an account?")
                                .foregroundColor(Theme.textSecondary)
                                .font(Theme.fontCaption)
                            NavigationLink(destination: SignUpView()) {
                                Text("Sign Up")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Theme.accent)
                            }
                        }
                        .padding(.top, Theme.paddingSmall)

                        Spacer()
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }

    private func signIn() {
        isLoading = true
        Task {
            do {
                try await authService.signIn(email: email, password: password)
            } catch {
                authService.errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
