import SwiftUI

struct XomEmptyState: View {
    /// Single-icon API (legacy / simple usage).
    let icon: String
    /// Optional stack of SF Symbol names layered for a richer illustration.
    /// When provided, overrides `icon` display.
    let symbolStack: [String]
    let title: String
    let subtitle: String
    let ctaLabel: String?
    let ctaAction: (() -> Void)?
    /// When true, applies a subtle floating loop to the symbol illustration.
    let floatingLoop: Bool

    @State private var floatOffset: CGFloat = 0

    init(
        icon: String = "tray",
        symbolStack: [String] = [],
        title: String,
        subtitle: String,
        ctaLabel: String? = nil,
        ctaAction: (() -> Void)? = nil,
        floatingLoop: Bool = false
    ) {
        self.icon = icon
        self.symbolStack = symbolStack
        self.title = title
        self.subtitle = subtitle
        self.ctaLabel = ctaLabel
        self.ctaAction = ctaAction
        self.floatingLoop = floatingLoop
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            illustrationView
                .offset(y: floatOffset)
                .onAppear {
                    guard floatingLoop else { return }
                    withAnimation(
                        .easeInOut(duration: 2.4)
                        .repeatForever(autoreverses: true)
                    ) {
                        floatOffset = -8
                    }
                }

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

    @ViewBuilder
    private var illustrationView: some View {
        if symbolStack.isEmpty {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(Theme.textSecondary.opacity(0.4))
        } else {
            ZStack {
                ForEach(Array(symbolStack.enumerated()), id: \.offset) { index, symbol in
                    Image(systemName: symbol)
                        .font(.system(size: 48 - CGFloat(index) * 10))
                        .foregroundStyle(Theme.textSecondary.opacity(0.4 - Double(index) * 0.1))
                        .offset(
                            x: CGFloat(index) * 6,
                            y: CGFloat(index) * -6
                        )
                }
            }
            .frame(width: 80, height: 80)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        XomEmptyState(
            icon: "dumbbell",
            title: "No Workouts Yet",
            subtitle: "Log your first workout to get started.",
            ctaLabel: "Start Workout",
            ctaAction: {}
        )

        XomEmptyState(
            symbolStack: ["dumbbell.fill", "figure.strengthtraining.traditional"],
            title: "No Exercises Added",
            subtitle: "Add exercises to your workout.",
            floatingLoop: true
        )
    }
    .background(Theme.background)
}
