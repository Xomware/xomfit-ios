import AuthenticationServices
import SwiftUI

struct LoginView: View {
    @Environment(AuthService.self) private var authService

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var toast: Toast?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                RadialGradient(
                    colors: [Theme.accent.opacity(0.06), .clear],
                    center: .top,
                    startRadius: 50,
                    endRadius: 500
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        // Logo / Header
                        VStack(spacing: Theme.Spacing.sm) {
                            Image("XomFitBanner")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 100)

                            Text("Track. Lift. Grow.")
                                .font(Theme.fontCaption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .padding(.top, 60)
                        .padding(.bottom, Theme.Spacing.lg)

                        // Social Sign In Buttons
                        VStack(spacing: 12) {
                            // Apple Sign In
                            SignInWithAppleButton(.signIn) { request in
                                let appleRequest = authService.prepareAppleSignIn()
                                request.requestedScopes = appleRequest.requestedScopes
                                request.nonce = appleRequest.nonce
                            } onCompletion: { result in
                                Task {
                                    await authService.handleAppleSignIn(result)
                                    if let error = authService.errorMessage {
                                        showToast(.error, error)
                                    }
                                }
                            }
                            .signInWithAppleButtonStyle(.white)
                            .frame(height: 52)
                            .clipShape(.rect(cornerRadius: Theme.cornerRadius))

                            // Google Sign In
                            Button {
                                Task {
                                    await authService.signInWithGoogle()
                                    if let error = authService.errorMessage {
                                        showToast(.error, error)
                                    }
                                }
                            } label: {
                                HStack(spacing: Theme.Spacing.sm) {
                                    Image(systemName: "g.circle.fill")
                                        .font(Theme.fontTitle3)
                                    Text("Sign in with Google")
                                        .font(Theme.fontBodyEmphasized)
                                }
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color.white)
                                .clipShape(.rect(cornerRadius: Theme.cornerRadius))
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.lg)

                        // Divider
                        HStack {
                            Rectangle().fill(Theme.hairline).frame(height: 0.5)
                            Text("or")
                                .font(Theme.fontCaption)
                                .foregroundStyle(Theme.textTertiary)
                            Rectangle().fill(Theme.hairline).frame(height: 0.5)
                        }
                        .padding(.horizontal, Theme.Spacing.lg)

                        // Email Form
                        VStack(spacing: Theme.Spacing.md) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Email")
                                    .font(Theme.fontCaption)
                                    .foregroundStyle(Theme.textSecondary)
                                TextField("you@example.com", text: $email)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
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

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Password")
                                    .font(Theme.fontCaption)
                                    .foregroundStyle(Theme.textSecondary)
                                SecureField("••••••••", text: $password)
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
                                signIn()
                            } label: {
                                if isLoading {
                                    ProgressView()
                                        .tint(.black)
                                } else {
                                    Text("Sign In")
                                }
                            }
                            .buttonStyle(AccentButtonStyle())
                            .disabled(isLoading || email.isEmpty || password.isEmpty)
                            .opacity((isLoading || email.isEmpty || password.isEmpty) ? 0.6 : 1)
                        }
                        .padding(.horizontal, Theme.Spacing.lg)

                        // Sign up link
                        HStack(spacing: Theme.Spacing.tight) {
                            Text("Don't have an account?")
                                .foregroundStyle(Theme.textSecondary)
                                .font(Theme.fontCaption)
                            NavigationLink(destination: SignUpView()) {
                                Text("Sign Up")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                        .padding(.top, Theme.Spacing.sm)

                        Spacer()
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .toast($toast)
    }

    private func signIn() {
        isLoading = true
        Task {
            do {
                try await authService.signIn(email: email, password: password)
                showToast(.success, "Welcome back!")
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
