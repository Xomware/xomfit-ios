import SwiftUI

// MARK: - Elevation Modifiers

extension View {
    /// Wraps the view with a hairline-bordered, rounded surface.
    /// Use instead of drop shadows for an elevation signal.
    func hairline(_ radius: CGFloat = Theme.Radius.md) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: radius)
                .strokeBorder(Theme.hairline, lineWidth: 0.5)
        )
    }

    /// Applies a top-to-bottom gradient overlay that mimics ambient light from above.
    /// Use on hero cards and primary CTAs to give subtle depth without a shadow.
    func heroGradient(accent: Color = Theme.accent) -> some View {
        self.overlay(
            LinearGradient(
                colors: [accent.opacity(0.12), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
