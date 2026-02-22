import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @State private var email = ""
    @State private var password = ""
    @State private var showingSignUp = false
    
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
                
                // Input Fields
                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .padding()
                        .background(Theme.cardBackground)
                        .cornerRadius(Theme.cornerRadius)
                        .foregroundColor(Theme.textPrimary)
                    
                    SecureField("Password", text: $password)
                        .padding()
                        .background(Theme.cardBackground)
                        .cornerRadius(Theme.cornerRadius)
                        .foregroundColor(Theme.textPrimary)
                }
                .padding(.horizontal, Theme.paddingLarge)
                
                // Sign In Button
                Button(action: { authService.signIn(email: email, password: password) }) {
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
                .background(Theme.accent)
                .cornerRadius(Theme.cornerRadius)
                .padding(.horizontal, Theme.paddingLarge)
                
                // Apple Sign In
                Button(action: { authService.signInWithApple() }) {
                    HStack {
                        Image(systemName: "apple.logo")
                        Text("Sign in with Apple")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(Theme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.cardBackground)
                    .cornerRadius(Theme.cornerRadius)
                }
                .padding(.horizontal, Theme.paddingLarge)
                
                // Sign Up Link
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
                
                Spacer()
            }
        }
        .sheet(isPresented: $showingSignUp) {
            SignUpView()
                .environmentObject(authService)
        }
    }
}
