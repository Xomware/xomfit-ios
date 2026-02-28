import SwiftUI

// MARK: - Auth Loading Overlay
/// Full-screen translucent overlay shown during auth operations.
struct AuthLoadingOverlay: View {
    let message: String

    init(message: String = "Signing in…") {
        self.message = message
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.accent))
                    .scaleEffect(1.4)

                Text(message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(28)
            .background(Theme.cardBackground)
            .cornerRadius(16)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(message)
        .accessibilityAddTraits(.updatesFrequently)
        .transition(.opacity)
    }
}

// MARK: - Auth Error Banner
/// Animated error banner shown at top of auth screens.
struct AuthErrorBanner: View {
    let message: String
    var onDismiss: (() -> Void)?

    @State private var appeared = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(Theme.destructive)
                .font(.system(size: 16))
                .accessibilityHidden(true)

            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            if let dismiss = onDismiss {
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                }
                .accessibilityLabel("Dismiss error")
            }
        }
        .padding(12)
        .background(Theme.destructive.opacity(0.12))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .stroke(Theme.destructive.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(Theme.cornerRadius)
        .padding(.horizontal, Theme.paddingLarge)
        .offset(y: appeared ? 0 : -20)
        .opacity(appeared ? 1 : 0)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: appeared)
        .onAppear { appeared = true }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(message)")
        .accessibilityAddTraits(.isStaticText)
    }
}

// MARK: - Auth Input Field
/// Styled text field matching XomFit design system with accessibility support.
struct AuthInputField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType?
    var submitLabel: SubmitLabel = .next
    var isFocused: Bool = false
    var onSubmit: (() -> Void)? = nil
    var accessibilityIdentifier: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
                .accessibilityHidden(true)

            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                        .submitLabel(submitLabel)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .autocapitalization(keyboardType == .emailAddress ? .none : .sentences)
                        .submitLabel(submitLabel)
                }
            }
            .textContentType(textContentType)
            .padding()
            .background(Theme.cardBackground)
            .cornerRadius(Theme.cornerRadius)
            .foregroundColor(Theme.textPrimary)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .stroke(isFocused ? Theme.accent : Color.clear, lineWidth: 2)
                    .animation(.easeInOut(duration: 0.2), value: isFocused)
            )
            .accessibilityLabel(label)
            .accessibilityIdentifier(accessibilityIdentifier ?? label.lowercased().replacingOccurrences(of: " ", with: "-") + "-field")
            .onSubmit { onSubmit?() }
        }
    }
}

// MARK: - Auth Primary Button
/// Full-width primary action button for auth screens.
struct AuthPrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        .scaleEffect(0.9)
                } else {
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isEnabled && !isLoading ? Theme.accent : Theme.accent.opacity(0.35))
            .cornerRadius(Theme.cornerRadius)
            .animation(.easeInOut(duration: 0.2), value: isEnabled)
            .animation(.easeInOut(duration: 0.2), value: isLoading)
        }
        .disabled(!isEnabled || isLoading)
        .padding(.horizontal, Theme.paddingLarge)
        .accessibilityLabel(isLoading ? "Loading" : title)
        .accessibilityAddTraits(isEnabled && !isLoading ? .isButton : [.isButton, .isNotEnabled])
        .accessibilityIdentifier(title.lowercased().replacingOccurrences(of: " ", with: "-") + "-button")
    }
}

// MARK: - Password Strength Indicator
/// Animated strength bar for the sign-up form.
struct PasswordStrengthBar: View {
    enum Strength { case empty, weak, medium, strong }

    let strength: Strength

    var color: Color {
        switch strength {
        case .empty:  return Theme.cardBackground
        case .weak:   return .red
        case .medium: return .orange
        case .strong: return .green
        }
    }

    var label: String {
        switch strength {
        case .empty:  return ""
        case .weak:   return "Weak"
        case .medium: return "Medium"
        case .strong: return "Strong"
        }
    }

    var progress: CGFloat {
        switch strength {
        case .empty:  return 0
        case .weak:   return 0.33
        case .medium: return 0.66
        case .strong: return 1.0
        }
    }

    var body: some View {
        if strength != .empty {
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Theme.cardBackground)
                            .frame(height: 4)
                        Capsule()
                            .fill(color)
                            .frame(width: geo.size.width * progress, height: 4)
                            .animation(.spring(response: 0.45, dampingFraction: 0.7), value: progress)
                    }
                }
                .frame(height: 4)

                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(color)
                    .animation(.easeInOut, value: label)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Password strength: \(label)")
        }
    }
}

// MARK: - Success Checkmark Animation
/// Animated checkmark shown after successful operations (e.g., password reset email sent).
struct SuccessCheckmark: View {
    @State private var appeared = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.green.opacity(0.15))
                .frame(width: 80, height: 80)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)
                .scaleEffect(appeared ? 1 : 0.5)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.65), value: appeared)
        }
        .onAppear { appeared = true }
        .accessibilityLabel("Success")
        .accessibilityAddTraits(.isImage)
    }
}

// MARK: - Auth Divider
struct AuthDivider: View {
    let label: String
    init(label: String = "or continue with") { self.label = label }
    var body: some View {
        HStack {
            VStack { Divider().background(Theme.textSecondary.opacity(0.3)) }
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
            VStack { Divider().background(Theme.textSecondary.opacity(0.3)) }
        }
        .padding(.horizontal, Theme.paddingLarge)
        .accessibilityHidden(true)
    }
}
