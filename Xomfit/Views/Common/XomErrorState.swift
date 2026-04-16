import SwiftUI

/// Reusable error container — warning glyph, concise copy, optional retry CTA.
/// Replaces ad-hoc `errorView(message:)` helpers in tab roots.
struct XomErrorState: View {
    let title: String
    let message: String
    let retryLabel: String
    let retryAction: (() -> Void)?

    init(
        title: String = "Something went wrong",
        message: String,
        retryLabel: String = "Try Again",
        retryAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.retryLabel = retryLabel
        self.retryAction = retryAction
    }

    var body: some View {
        XomEmptyState(
            icon: "exclamationmark.triangle.fill",
            title: title,
            subtitle: message,
            ctaLabel: retryAction != nil ? retryLabel : nil,
            ctaAction: retryAction
        )
    }
}

// MARK: - Preview

#Preview {
    XomErrorState(
        message: "Failed to load feed. Check your connection and try again.",
        retryAction: {}
    )
    .background(Theme.background)
}
