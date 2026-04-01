import SwiftUI

struct XomEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String
    let ctaLabel: String?
    let ctaAction: (() -> Void)?

    init(
        icon: String = "tray",
        title: String,
        subtitle: String,
        ctaLabel: String? = nil,
        ctaAction: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.ctaLabel = ctaLabel
        self.ctaAction = ctaAction
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(Theme.textSecondary.opacity(0.5))

            VStack(spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(Theme.fontHeadline)
                    .foregroundStyle(Theme.textPrimary)

                Text(subtitle)
                    .font(Theme.fontBody)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let ctaLabel, let ctaAction {
                XomButton(ctaLabel, action: ctaAction)
                    .frame(maxWidth: 200)
            }
        }
        .padding(Theme.Spacing.xl)
    }
}
