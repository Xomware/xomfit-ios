import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @State private var email = ""
    @State private var password = ""
    @State private var showingSignUp = false
    @State private var showingForgotPassword = false
    @FocusState private var focusedField: FocusField?
    
    enum FocusField {
        case email
        case password
    }
    
    var isEmailPasswordValid: Bool {
        let emailRegex = "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        let isEmailValid = predicate.evaluate(with: email)
        return isEmailValid && password.count >= 8
    }
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Logo
                VStack(spacing: 12) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Theme.accent)
                    
                    Text("XomFit")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    
                    Text("Train Together. Get Stronger.")
                        .font(Theme.fontBody)
                        .foregroundColor(Theme.textSecondary)
                }
                
                Spacer()
                
                // Error Message
                if let errorMessage = authService.errorMessage {
                    Text(errorMessage)
                        .font(Theme.fontCaption)
                        .foregroundColor(Theme.destructive)
                        .padding()
                        .background(Theme.destructive.opacity(0.1))
                        .cornerRadius(Theme.cornerRadius)
                        .padding(.horizontal, Theme.paddingLarge)
                }
                
                // Input Fields
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Theme.textSecondary)
                        
                        TextField("your@email.com", text: $email)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                            .submitLabel(.next)
                            .focused($focusedField, equals: .email)
                            .padding()
                            .background(Theme.cardBackground)
                            .cornerRadius(Theme.cornerRadius)
                            .foregroundColor(Theme.textPrimary)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                                    .stroke(
                                        focusedField == .email ? Theme.accent : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Theme.textSecondary)
                        
                        SecureField("••••••••", text: $password)
                            .submitLabel(.go)
                            .focused($focusedField, equals: .password)
                            .padding()
                            .background(Theme.cardBackground)
                            .cornerRadius(Theme.cornerRadius)
                            .foregroundColor(Theme.textPrimary)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                                    .stroke(
                                        focusedField == .password ? Theme.accent : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                    }
                }
                .padding(.horizontal, Theme.paddingLarge)
                
                // Forgot Password Link
                HStack {
                    Spacer()
                    Button(action: { showingForgotPassword = true }) {
                        Text("Forgot password?")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.accent)
                    }
                }
                .padding(.horizontal, Theme.paddingLarge)
                
                // Sign In Button
                Button(action: {
                    Task {
                        try? await authService.signIn(email: email, password: password)
                    }
                }) {
                    if authService.isLoading {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Text("Sign In")
                            .font(.system(size: 18, weight: .bold))
                    }
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isEmailPasswordValid && !authService.isLoading ? Theme.accent : Theme.accent.opacity(0.3))
                .cornerRadius(Theme.cornerRadius)
                .padding(.horizontal, Theme.paddingLarge)
                .disabled(!isEmailPasswordValid || authService.isLoading)
                
                // Divider
                HStack {
                    VStack {
                        Divider()
                    }
                    Text("or continue with")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                    VStack {
                        Divider()
                    }
                }
                .padding(.horizontal, Theme.paddingLarge)
                
                // Apple Sign In Button
                SignInWithAppleButton(
                    onRequest: { request in
                        request.requestedScopes = [.fullName, .email]
                    },
                    onCompletion: { result in
                        Task {
                            authService.signInWithApple()
                        }
                    }
                )
                .frame(height: 50)
                .cornerRadius(Theme.cornerRadius)
                .padding(.horizontal, Theme.paddingLarge)
                
                // Google Sign In Button
                GoogleSignInButton(action: {
                    authService.signInWithGoogle()
                })
                .padding(.horizontal, Theme.paddingLarge)
                
                // Sign Up Link
                VStack(spacing: 12) {
                    Button(action: { showingSignUp = true }) {
                        HStack(spacing: 4) {
                            Text("Don't have an account?")
                                .foregroundColor(Theme.textSecondary)
                            Text("Sign Up")
                                .foregroundColor(Theme.accent)
                                .fontWeight(.semibold)
                        }
                        .font(Theme.fontBody)
                    }
                }
                
                Spacer()
            }
        }
        .sheet(isPresented: $showingSignUp) {
            SignUpView()
                .environmentObject(authService)
        }
        .sheet(isPresented: $showingForgotPassword) {
            ForgotPasswordView()
                .environmentObject(authService)
        }
    }
}

// MARK: - Google Sign In Button
struct GoogleSignInButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "g.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.red)
                
                Text("Sign in with Google")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.cardBackground)
            .cornerRadius(Theme.cornerRadius)
        }
    }
}
