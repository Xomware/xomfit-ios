import SwiftUI

struct OnboardingView: View {
    @Environment(AuthService.self) private var authService
    @State private var currentPage = 0
    @State private var selectedGoals: Set<TrainingGoal> = []

    private let totalPages = 4

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.background.ignoresSafeArea()

            // Subtle gradient accent at top
            RadialGradient(
                colors: [Theme.accent.opacity(0.04), .clear],
                center: .top,
                startRadius: 50,
                endRadius: 600
            )
            .ignoresSafeArea()

            TabView(selection: $currentPage) {
                OnboardingWelcomeScreen(onContinue: { advance() })
                    .tag(0)

                OnboardingGoalsScreen(
                    selectedGoals: $selectedGoals,
                    onContinue: { advance() }
                )
                .tag(1)

                OnboardingFriendsScreen(onFinish: { advance() })
                    .tag(2)

                OnboardingPermissionsScreen(onContinue: { finish() })
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.xomChill, value: currentPage)

            OnboardingBottomBar(
                currentPage: currentPage,
                totalPages: totalPages,
                onSkip: { advance() }
            )
        }
        .preferredColorScheme(.dark)
    }

    private func advance() {
        Haptics.light()
        if currentPage < totalPages - 1 {
            withAnimation(.xomChill) {
                currentPage += 1
            }
        } else {
            finish()
        }
    }

    private func finish() {
        // Save training goals (fire-and-forget)
        if !selectedGoals.isEmpty,
           let userId = authService.currentUser?.id.uuidString.lowercased() {
            Task {
                try? await ProfileService.shared.updateTrainingGoals(
                    userId: userId,
                    goals: Array(selectedGoals)
                )
            }
        }

        authService.onboardingCompleted()
    }
}
