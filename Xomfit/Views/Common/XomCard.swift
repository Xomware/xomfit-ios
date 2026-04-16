import SwiftUI

// MARK: - XomCard Variant

enum XomCardVariant {
    /// Standard card — hairline border, surface fill, no shadow.
    case base
    /// Slightly elevated — surfaceElevated fill, hairlineStrong border.
    case elevated
    /// Full-bleed hero card — xl radius, surfaceElevated fill, hairlineStrong border.
    case hero
}

// MARK: - XomCard

struct XomCard<Content: View>: View {
    let padding: CGFloat
    let isPressable: Bool
    let variant: XomCardVariant
    @ViewBuilder let content: Content

    @State private var isPressed = false

    init(
        padding: CGFloat = Theme.Spacing.md,
        isPressable: Bool = false,
        variant: XomCardVariant = .base,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.isPressable = isPressable
        self.variant = variant
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(fillColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(borderColor, lineWidth: 0.5)
            )
            .scaleEffect(isPressable && isPressed ? 0.97 : 1)
            .animation(.xomSnappy, value: isPressed)
            .if(isPressable) { view in
                view.simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in isPressed = true }
                        .onEnded { _ in isPressed = false }
                )
            }
    }

    private var fillColor: Color {
        switch variant {
        case .base:     Theme.surface
        case .elevated: Theme.surfaceElevated
        case .hero:     Theme.surfaceElevated
        }
    }

    private var borderColor: Color {
        switch variant {
        case .base: Theme.hairline
        case .elevated, .hero: Theme.hairlineStrong
        }
    }

    private var cornerRadius: CGFloat {
        switch variant {
        case .base, .elevated: Theme.Radius.md
        case .hero: Theme.Radius.xl
        }
    }
}

private extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
