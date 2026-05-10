import SwiftUI

struct OnboardingWelcomeScreen: View {
    let onContinue: () -> Void

    private let features: [(icon: String, text: String)] = [
        ("dumbbell.fill", "Track every set, rep, and PR"),
        ("person.2.fill", "Train with friends, compete on leaderboards"),
        ("chart.line.uptrend.xyaxis", "Watch your progress over time")
    ]

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            // App banner
            Image("XomFitBanner")
                .resizable()
                .scaledToFit()
                .frame(height: 80)
                .staggeredAppear(index: 0)

            // Headline
            Text("Your lifting, social.")
                .font(Theme.fontLargeTitle)
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .staggeredAppear(index: 1)

            // Feature rows
            VStack(spacing: Theme.Spacing.md) {
                ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                    featureRow(icon: feature.icon, text: feature.text)
                        .staggeredAppear(index: index + 2)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.md)

            Spacer()

            // CTA
            XomButton("Let's Get Started", action: onContinue)
                .padding(.horizontal, Theme.Spacing.lg)
                .staggeredAppear(index: 5)
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(Theme.fontTitle3)
                .foregroundStyle(Theme.accent)
                .frame(width: 44, height: 44)
                .background(Theme.accent.opacity(0.12))
                .clipShape(Circle())

            Text(text)
                .font(Theme.fontBody)
                .foregroundStyle(Theme.textPrimary)

            Spacer()
        }
    }
}
