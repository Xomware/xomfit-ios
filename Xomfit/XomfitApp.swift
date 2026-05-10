import SwiftUI

@main
struct XomFitApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var authService = AuthService()
    @State private var workoutSession = WorkoutLoggerViewModel()

    /// Drives the fitness-profile questionnaire (#259). Bumped after dismissal so
    /// the cover doesn't re-present unless the user explicitly opens it again.
    @State private var showFitnessQuestionnaire = false
    @AppStorage("onboardingSkipped") private var onboardingSkipped = false

    /// Deep-link target for `xomfit://report/<id>` (#260). When set, we
    /// present the Reports list as a sheet pre-seeded with this id, so
    /// the matching detail view auto-pushes once data loads. Reset to nil
    /// when the sheet dismisses.
    @State private var pendingReportId: String? = nil
    @State private var showReportsSheet = false

    var body: some Scene {
        WindowGroup {
            Group {
                if authService.isLoading {
                    ZStack {
                        Theme.background.ignoresSafeArea()
                        VStack(spacing: Theme.Spacing.md) {
                            Image("XomFitBanner")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 80)
                            XomFitLoaderPaint(size: 60)
                        }
                    }
                } else if authService.isAuthenticated {
                    MainTabView()
                        .environment(authService)
                        .environment(workoutSession)
                        .task {
                            await NotificationService.shared.requestPermission()
                            WatchSyncService.shared.activate()
                            evaluateFitnessQuestionnaireGate()
                        }
                        .sheet(isPresented: Bindable(authService).needsProfileCompletion) {
                            ProfileCompletionView()
                                .environment(authService)
                                .interactiveDismissDisabled()
                                .onDisappear { evaluateFitnessQuestionnaireGate() }
                        }
                        .fullScreenCover(isPresented: Bindable(authService).needsOnboarding) {
                            OnboardingView()
                                .environment(authService)
                                .interactiveDismissDisabled()
                                .onDisappear { evaluateFitnessQuestionnaireGate() }
                        }
                        .fullScreenCover(isPresented: $showFitnessQuestionnaire) {
                            FitnessQuestionnaireView(mode: .onboarding) {
                                showFitnessQuestionnaire = false
                            }
                            .interactiveDismissDisabled()
                        }
                        .sheet(isPresented: $showReportsSheet, onDismiss: { pendingReportId = nil }) {
                            NavigationStack {
                                ReportsListView(deepLinkReportId: pendingReportId)
                            }
                            .preferredColorScheme(.dark)
                        }
                } else {
                    LoginView()
                        .environment(authService)
                }
            }
            .preferredColorScheme(.dark)
            .onOpenURL { url in
                if url.scheme == "xomfit", url.host == "workout" {
                    if workoutSession.isActive {
                        workoutSession.isPresented = true
                    }
                    return
                }
                if url.scheme == "xomfit", url.host == "report" {
                    // `xomfit://report/<id>` — first path component is the id.
                    let id = url.pathComponents
                        .filter { $0 != "/" }
                        .first?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if let id, !id.isEmpty {
                        pendingReportId = id
                    } else {
                        pendingReportId = nil
                    }
                    if authService.isAuthenticated {
                        showReportsSheet = true
                    }
                    return
                }
                Task {
                    try? await supabase.auth.session(from: url)
                }
            }
        }
    }

    /// Decide whether to present the fitness questionnaire on this launch.
    /// Don't re-prompt once the user finishes it OR explicitly skipped — they can
    /// always reopen it from Settings -> Fitness Goals.
    private func evaluateFitnessQuestionnaireGate() {
        guard authService.isAuthenticated else { return }
        guard !authService.needsProfileCompletion else { return }
        guard !authService.needsOnboarding else { return }
        guard UserFitnessProfile.current.completedAt == nil else { return }
        guard !onboardingSkipped else { return }
        showFitnessQuestionnaire = true
    }
}
