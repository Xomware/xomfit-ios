import SwiftUI

enum XomButtonVariant {
    case primary
    case secondary
    case destructive
    case ghost
}

struct XomButton: View {
    let title: String
    let variant: XomButtonVariant
    let icon: String?
    let isLoading: Bool
    let action: () -> Void

    @State private var isPressed = false

    init(
        _ title: String,
        variant: XomButtonVariant = .primary,
        icon: String? = nil,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.variant = variant
        self.icon = icon
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: {
            guard !isLoading else { return }
            action()
        }) {
            HStack(spacing: Theme.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(foregroundColor)
                } else {
                    if let icon {
                        Image(systemName: icon)
                    }
                    Text(title)
                }
            }
            .font(.body.weight(.bold))
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .overlay(borderOverlay)
            .shadow(color: shadowColor, radius: isPressed ? 4 : 8, x: 0, y: isPressed ? 2 : 4)
        }
        .scaleEffect(isPressed ? 0.94 : 1)
        .animation(.xomSnappy, value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .sensoryFeedback(.impact(weight: .medium), trigger: isPressed)
        .disabled(isLoading)
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary: .black
        case .secondary: Theme.accent
        case .destructive: .white
        case .ghost: Theme.accent
        }
    }

    private var backgroundColor: Color {
        switch variant {
        case .primary: Theme.accent
        case .secondary: Theme.glassFill
        case .destructive: Theme.destructive
        case .ghost: .clear
        }
    }

    @ViewBuilder
    private var borderOverlay: some View {
        switch variant {
        case .secondary:
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .strokeBorder(Theme.accent.opacity(0.5), lineWidth: 1)
        case .ghost:
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .strokeBorder(Theme.accent.opacity(0.3), lineWidth: 1)
        default:
            EmptyView()
        }
    }

    private var shadowColor: Color {
        switch variant {
        case .primary: Theme.accent.opacity(0.3)
        case .destructive: Theme.destructive.opacity(0.3)
        default: .clear
        }
    }
}
