import SwiftUI

/// The ONE hairline rule — 0.5pt, `Theme.hairline` opacity.
/// Use this everywhere a visual separator is needed instead of SwiftUI's `Divider()`.
struct XomDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(height: 0.5)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        Text("Above")
            .foregroundStyle(Theme.textPrimary)
            .padding()
        XomDivider()
        Text("Below")
            .foregroundStyle(Theme.textPrimary)
            .padding()
    }
    .background(Theme.surface)
}
