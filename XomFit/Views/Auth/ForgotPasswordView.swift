import SwiftUI

struct ForgotPasswordView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var showSuccessMessage = false
    @FocusState private var emailFocused: Bool
    
    var isEmailValid: Bool {
        let emailRegex = "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return predicate.evaluate(with: email)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 40))
                            .foregroundColor(Theme.accent)
                        Text("Reset Password")
                            .font(Theme.fontTitle)
                            .foregroundColor(Theme.textPrimary)
                        Text("Enter your email to receive a password reset link")
                            .font(Theme.fontBody)
                            .foregroundColor(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, Theme.paddingLarge)
                    .padding(.horizontal, Theme.paddingLarge)
                    
                    // Success Message
                    if showSuccessMessage {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.green)
                            Text("Check your email")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Theme.textPrimary)
                            Text("We've sent a password reset link to \(email)")
                                .font(Theme.fontCaption)
                                .foregroundColor(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(Theme.cornerRadius)
                        .padding(.horizontal, Theme.paddingLarge)
                    }
                    
                    // Error Message
                    if let errorMessage = authService.errorMessage {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Theme.destructive)
                            Text(errorMessage)
                                .font(Theme.fontCaption)
                                .foregroundColor(Theme.destructive)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.destructive.opacity(0.1))
                        .cornerRadius(Theme.cornerRadius)
                        .padding(.horizontal, Theme.paddingLarge)
                    }
                    
                    // Email Field
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Email Address", text: $email)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                            .submitLabel(.return)
                            .focused($emailFocused)
                            .padding()
                            .background(Theme.cardBackground)
                            .cornerRadius(Theme.cornerRadius)
                            .foregroundColor(Theme.textPrimary)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                                    .stroke(
                                        emailFocused ? Theme.accent : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                    }
                    .padding(.horizontal, Theme.paddingLarge)
                    
                    // Send Reset Link Button
                    Button(action: {
                        Task {
                            do {
                                try await authService.resetPassword(email: email)
                                withAnimation {
                                    showSuccessMessage = true
                                }
                                // Auto-dismiss after 3 seconds
                                try await Task.sleep(nanoseconds: 3_000_000_000)
                                dismiss()
                            } catch {
                                // Error message already displayed
                            }
                        }
                    }) {
                        if authService.isLoading {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Text("Send Reset Link")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isEmailValid && !authService.isLoading ? Theme.accent : Theme.accent.opacity(0.3))
                    .cornerRadius(Theme.cornerRadius)
                    .disabled(!isEmailValid || authService.isLoading)
                    .padding(.horizontal, Theme.paddingLarge)
                    
                    Spacer()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.accent)
                }
            }
            .onAppear {
                emailFocused = true
            }
        }
    }
}

#Preview {
    ForgotPasswordView()
        .environmentObject(AuthService())
}
