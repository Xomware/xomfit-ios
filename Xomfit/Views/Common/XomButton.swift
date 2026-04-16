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
            .background(backgroundLayer)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .overlay(borderOverlay)
        }
        .scaleEffect(isPressed ? 0.98 : 1)
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
        case .primary:     .black
        case .secondary:   Theme.accent
        case .destructive: .white
        case .ghost:       Theme.accent
        }
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        switch variant {
        case .primary:
            ZStack {
                Theme.accent
                LinearGradient(
                    colors: [Color.white.opacity(0.10), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        case .secondary:
            Theme.surfaceElevated
        case .destructive:
            Theme.destructive
        case .ghost:
            Color.clear
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
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        XomButton("Start Workout", variant: .primary) {}
        XomButton("Edit Profile", variant: .secondary) {}
        XomButton("Delete", variant: .destructive) {}
        XomButton("Skip", variant: .ghost) {}
        XomButton("Loading...", isLoading: true) {}
    }
    .padding()
    .background(Theme.background)
}
