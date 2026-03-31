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
                    VStack(spacing: Theme.paddingLarge) {
                        // Logo / Header
                        VStack(spacing: Theme.paddingSmall) {
                            Image("XomFitBanner")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 100)

                            Text("Track. Lift. Grow.")
                                .font(Theme.fontCaption)
                                .foregroundColor(Theme.textSecondary)
                        }
                        .padding(.top, 60)
                        .padding(.bottom, Theme.paddingLarge)

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
                            .cornerRadius(Theme.cornerRadius)

                            // Google Sign In
                            Button {
                                Task {
                                    await authService.signInWithGoogle()
                                    if let error = authService.errorMessage {
                                        showToast(.error, error)
                                    }
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "g.circle.fill")
                                        .font(.system(size: 20))
                                    Text("Sign in with Google")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color.white)
                                .cornerRadius(Theme.cornerRadius)
                            }
                        }
                        .padding(.horizontal, Theme.paddingLarge)

                        // Divider
                        HStack {
                            Rectangle().fill(Theme.textSecondary.opacity(0.3)).frame(height: 1)
                            Text("or")
                                .font(Theme.fontCaption)
                                .foregroundColor(Theme.textSecondary)
                            Rectangle().fill(Theme.textSecondary.opacity(0.3)).frame(height: 1)
                        }
                        .padding(.horizontal, Theme.paddingLarge)

                        // Email Form
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
