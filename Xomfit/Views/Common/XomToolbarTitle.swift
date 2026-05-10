import SwiftUI

/// Optional helper for a consistent inline-title + subtitle treatment.
/// Use in detail views that want a two-line nav title.
///
/// Usage:
/// ```swift
/// .toolbar {
///     ToolbarItem(placement: .principal) {
///         XomToolbarTitle(title: "Bench Press", subtitle: "Personal Records")
///     }
/// }
/// ```
struct XomToolbarTitle: View {
    let title: String
    let subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(spacing: 1) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)

            if let subtitle {
                Text(subtitle)
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .multilineTextAlignment(.center)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        Color(Theme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    XomToolbarTitle("Bench Press", subtitle: "Personal Records")
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
