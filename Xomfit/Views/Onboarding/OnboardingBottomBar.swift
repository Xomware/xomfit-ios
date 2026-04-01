import SwiftUI

struct OnboardingBottomBar: View {
    let currentPage: Int
    let totalPages: Int
    let onSkip: () -> Void

    var body: some View {
        HStack {
            // Invisible spacer to balance the skip button
            Text("Skip")
                .font(.subheadline.weight(.medium))
                .hidden()

            Spacer()

            // Progress dots
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(0..<totalPages, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? Theme.accent : Theme.glassFill)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    index == currentPage ? Theme.accent : Theme.glassBorder,
                                    lineWidth: 0.5
                                )
                        )
                        .scaleEffect(index == currentPage ? 1.2 : 1)
                        .animation(.xomPlayful, value: currentPage)
                }
            }

            Spacer()

            // Skip button (hidden on last page)
            Button(action: onSkip) {
                Text("Skip")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            .opacity(currentPage < totalPages - 1 ? 1 : 0)
            .disabled(currentPage >= totalPages - 1)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.xl)
    }
}
