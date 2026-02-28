import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @FocusState private var focusedField: FocusField?
    
    enum FocusField {
        case username
        case email
        case password
        case confirmPassword
    }
    
    var passwordStrength: PasswordStrength {
        let strength: PasswordStrength
        
        if password.isEmpty {
            strength = .weak
        } else if password.count < 8 {
            strength = .weak
        } else if password.count < 12 {
            let hasNumber = password.contains(where: { $0.isNumber })
            let hasSpecial = password.contains(where: { !$0.isLetter && !$0.isNumber && !$0.isWhitespace })
            strength = (hasNumber || hasSpecial) ? .medium : .weak
        } else {
            let hasNumber = password.contains(where: { $0.isNumber })
            let hasSpecial = password.contains(where: { !$0.isLetter && !$0.isNumber && !$0.isWhitespace })
            strength = (hasNumber && hasSpecial) ? .strong : .medium
        }
        
        return strength
    }
    
    enum PasswordStrength {
        case weak
        case medium
        case strong
        
        var color: Color {
            switch self {
            case .weak: return .red
            case .medium: return .orange
            case .strong: return .green
            }
        }
        
        var label: String {
            switch self {
            case .weak: return "Weak"
            case .medium: return "Medium"
            case .strong: return "Strong"
            }
        }
    }
    
    var isEmailValid: Bool {
        let emailRegex = "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return predicate.evaluate(with: email)
    }
    
    var passwordsMatch: Bool {
        password.isEmpty || password == confirmPassword
    }
    
    var isValid: Bool {
        !username.isEmpty && 
        isEmailValid && 
        password.count >= 8 &&
        password.contains(where: { $0.isNumber }) &&
        passwordsMatch
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
                            // Username
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Username")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Theme.textSecondary)
                                
                                TextField("johndoe", text: $username)
                                    .autocapitalization(.none)
                                    .submitLabel(.next)
                                    .focused($focusedField, equals: .username)
                                    .padding()
                                    .background(Theme.cardBackground)
                                    .cornerRadius(Theme.cornerRadius)
                                    .foregroundColor(Theme.textPrimary)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Theme.cornerRadius)
                                            .stroke(
                                                focusedField == .username ? Theme.accent : Color.clear,
                                                lineWidth: 2
                                            )
                                    )
                            }
                            
                            // Email
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
                                                focusedField == .email ? Theme.accent : 
                                                (!email.isEmpty && !isEmailValid) ? Theme.destructive : Color.clear,
                                                lineWidth: 2
                                            )
                                    )
                                
                                if !email.isEmpty && !isEmailValid {
                                    Text("Please enter a valid email")
                                        .font(.system(size: 11))
                                        .foregroundColor(Theme.destructive)
                                }
                            }
                            
                            // Password
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Theme.textSecondary)
                                
                                SecureField("••••••••", text: $password)
                                    .submitLabel(.next)
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
                                
                                // Password Requirements
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 8) {
                                        Image(systemName: password.count >= 8 ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 12))
                                            .foregroundColor(password.count >= 8 ? .green : Theme.textSecondary)
                                        Text("At least 8 characters")
                                            .font(.system(size: 11))
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                    
                                    HStack(spacing: 8) {
                                        Image(systemName: password.contains(where: { $0.isNumber }) ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 12))
                                            .foregroundColor(password.contains(where: { $0.isNumber }) ? .green : Theme.textSecondary)
                                        Text("At least one number")
                                            .font(.system(size: 11))
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                }
                                .padding(.top, 4)
                                
                                // Password Strength Indicator
                                if !password.isEmpty {
                                    HStack(spacing: 6) {
                                        ForEach(0..<3, id: \.self) { index in
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(
                                                    index < (passwordStrength == .weak ? 1 : passwordStrength == .medium ? 2 : 3) 
                                                        ? passwordStrength.color 
                                                        : Theme.textSecondary.opacity(0.2)
                                                )
                                                .frame(height: 4)
                                        }
                                        Text(passwordStrength.label)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(passwordStrength.color)
                                    }
                                    .padding(.top, 8)
                                }
                            }
                            
                            // Confirm Password
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Confirm Password")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Theme.textSecondary)
                                
                                SecureField("••••••••", text: $confirmPassword)
                                    .submitLabel(.go)
                                    .focused($focusedField, equals: .confirmPassword)
                                    .padding()
                                    .background(Theme.cardBackground)
                                    .cornerRadius(Theme.cornerRadius)
                                    .foregroundColor(Theme.textPrimary)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Theme.cornerRadius)
                                            .stroke(
                                                focusedField == .confirmPassword ? Theme.accent :
                                                (!confirmPassword.isEmpty && !passwordsMatch) ? Theme.destructive : Color.clear,
                                                lineWidth: 2
                                            )
                                    )
                                
                                if !confirmPassword.isEmpty && !passwordsMatch {
                                    Text("Passwords do not match")
                                        .font(.system(size: 11))
                                        .foregroundColor(Theme.destructive)
                                }
                            }
                        }
                        .padding(.horizontal, Theme.paddingLarge)
                        
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
                        
                        // Sign Up Button
                        Button(action: {
                            Task {
                                do {
                                    try await authService.signUp(username: username, email: email, password: password)
                                    dismiss()
                                } catch {
                                    // Error is already displayed in authService.errorMessage
                                }
                            }
                        }) {
                            if authService.isLoading {
                                ProgressView()
                                    .tint(.black)
                            } else {
                                Text("Create Account")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.black)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isValid && !authService.isLoading ? Theme.accent : Theme.accent.opacity(0.3))
                        .cornerRadius(Theme.cornerRadius)
                        .disabled(!isValid || authService.isLoading)
                        .padding(.horizontal, Theme.paddingLarge)
                        .padding(.bottom, Theme.paddingLarge)
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
