import SwiftUI

/// Shared primitive for PR / Milestone / Streak content cards with a leading color stripe.
/// Replaces tinted-background panels.
struct ActivityStripeCard<Content: View>: View {
    let stripeColor: Color
    let icon: String
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 0) {
            // Leading 3pt color stripe
            Rectangle()
                .fill(stripeColor)
                .frame(width: 3)
                .clipShape(.rect(topLeadingRadius: 3, bottomLeadingRadius: 3))

            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(stripeColor)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    content
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.sm)
        }
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.Radius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .strokeBorder(Theme.hairline, lineWidth: 0.5)
        )
    }
}
