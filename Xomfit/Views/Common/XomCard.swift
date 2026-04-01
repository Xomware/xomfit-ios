import SwiftUI

struct XomCard<Content: View>: View {
    let padding: CGFloat
    let isPressable: Bool
    @ViewBuilder let content: Content

    @State private var isPressed = false

    init(
        padding: CGFloat = Theme.Spacing.md,
        isPressable: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.isPressable = isPressable
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .fill(Theme.glassFill)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.cornerRadius)
                            .fill(Theme.surface)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .strokeBorder(Theme.glassBorder, lineWidth: 0.5)
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
