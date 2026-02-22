import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    
    var isValid: Bool {
        !username.isEmpty && !email.isEmpty && !password.isEmpty && password == confirmPassword
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "dumbbell.fill")
                                .font(.system(size: 40))
                                .foregroundColor(Theme.accent)
                            Text("Create Account")
                                .font(Theme.fontTitle)
                                .foregroundColor(Theme.textPrimary)
                            Text("Join the XomFit community")
                                .font(Theme.fontBody)
                                .foregroundColor(Theme.textSecondary)
                        }
                        .padding(.top, Theme.paddingLarge)
                        
                        // Fields
                        VStack(spacing: 16) {
                            TextField("Username", text: $username)
                                .autocapitalization(.none)
                                .padding()
                                .background(Theme.cardBackground)
                                .cornerRadius(Theme.cornerRadius)
                                .foregroundColor(Theme.textPrimary)
                            
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
                            
                            SecureField("Confirm Password", text: $confirmPassword)
                                .padding()
                                .background(Theme.cardBackground)
                                .cornerRadius(Theme.cornerRadius)
                                .foregroundColor(Theme.textPrimary)
                        }
                        .padding(.horizontal, Theme.paddingLarge)
                        
                        // Sign Up Button
                        Button(action: {
                            authService.signUp(username: username, email: email, password: password)
                            dismiss()
                        }) {
                            Text("Create Account")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(isValid ? Theme.accent : Theme.accent.opacity(0.3))
                                .cornerRadius(Theme.cornerRadius)
                        }
                        .disabled(!isValid)
                        .padding(.horizontal, Theme.paddingLarge)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
    }
}
