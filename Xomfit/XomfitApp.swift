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

    /// DEBUG-only: `xomfit://coach` opens AI Coach in a sheet so agents can
    /// screenshot it without navigating the drawer (#371).
    #if DEBUG
    @State private var showCoachSheet = false
    #endif

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
                            #if DEBUG
                            // Skip permission prompts under auth-bypass so agents can
                            // drive the UI without dismissing modal dialogs.
                            if ProcessInfo.processInfo.environment["XOMFIT_AUTH_BYPASS"] != "1" {
                                await NotificationService.shared.requestPermission()
                            }
                            #else
                            await NotificationService.shared.requestPermission()
                            #endif
                            WatchSyncService.shared.activate()
                            // Route the watch's "Done Set" button into the
                            // active workout session. Uses weak capture so
                            // the closure can't keep the view model alive
                            // past app teardown.
                            WatchSyncService.shared.onDoneSetReceived = { [weak workoutSession] in
                                workoutSession?.completeFocusedSetFromWatch()
                            }
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
                        #if DEBUG
                        .sheet(isPresented: $showCoachSheet) {
                            NavigationStack {
                                AICoachView()
                            }
                            .environment(authService)
                            .environment(workoutSession)
                            .preferredColorScheme(.dark)
                        }
                        .task {
                            // Agent screenshot helper: auto-open Coach sheet
                            // when `XOMFIT_OPEN_COACH=1`. Combine with
                            // XOMFIT_AUTH_BYPASS=1 to land directly on the
                            // Coach empty-state from a cold launch (#371).
                            if ProcessInfo.processInfo.environment["XOMFIT_OPEN_COACH"] == "1" {
                                showCoachSheet = true
                            }

                            // Agent screenshot helper for #387 finish-flow polish:
                            // seed an in-progress workout with two exercises so the
                            // active runner + transition card + finish sheet can be
                            // screenshotted from a cold launch without taps.
                            //
                            //   XOMFIT_AUTO_START_WORKOUT=1  → start workout, two exercises seeded
                            //   XOMFIT_AUTO_COMPLETE_FIRST=1 → also complete every set on the first
                            //                                  exercise so the transition card shows
                            //   XOMFIT_AUTO_PRESENT_FINISH=1 → also present the finish sheet
                            if ProcessInfo.processInfo.environment["XOMFIT_AUTO_START_WORKOUT"] == "1" {
                                // Small delay so MainTabView's `.fullScreenCover`
                                // is fully mounted before we flip its binding —
                                // SwiftUI can otherwise race-reset it to false.
                                try? await Task.sleep(for: .milliseconds(500))
                                seedDebugActiveWorkout()
                            }
                        }
                        #endif
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
                if url.scheme == "xomfit", url.host == "spotify-callback" {
                    // Belt-and-suspenders: ASWebAuthenticationSession's completion handler
                    // normally consumes this. Forward anyway in case the OS routes it here.
                    SpotifyAuthService.shared.handleCallback(url: url)
                    return
                }
                if url.scheme == "xomfit", url.host == "soundcloud-callback" {
                    // Same belt-and-suspenders pattern as Spotify (#389).
                    SoundCloudAuthService.shared.handleCallback(url: url)
                    return
                }
                #if DEBUG
                if url.scheme == "xomfit", url.host == "coach" {
                    if authService.isAuthenticated {
                        showCoachSheet = true
                    }
                    return
                }
                #endif
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

    #if DEBUG
    /// Seed an in-progress workout for agent screenshot flows (#387). Adds two
    /// real exercises and (optionally) completes the first or pops the finish
    /// sheet so the new UI surfaces from a cold launch.
    @MainActor
    private func seedDebugActiveWorkout() {
        let env = ProcessInfo.processInfo.environment

        // Always clear any in-memory workout state so the seeded one is
        // deterministic across re-launches in the same simulator session.
        if workoutSession.isActive {
            workoutSession.discardWorkout()
        }

        let userId = authService.currentUser?.id.uuidString.lowercased() ?? ""
        workoutSession.startWorkout(name: "Screenshot Workout", userId: userId)

        // Two safe exercises from ExerciseDatabase. Picked deterministically by
        // id so the seeded workout looks consistent across screenshot runs.
        let preferredIds = ["ex-bench-flat", "ex-lat-pulldown"]
        var chosen: [Exercise] = []
        for id in preferredIds {
            if let match = ExerciseDatabase.all.first(where: { $0.id == id }) {
                chosen.append(match)
            }
        }
        if chosen.isEmpty {
            chosen = Array(ExerciseDatabase.all.prefix(2))
        }
        for ex in chosen {
            workoutSession.addExercise(ex)
        }

        // Optionally complete the first exercise so the transition card shows
        // immediately on launch.
        if env["XOMFIT_AUTO_COMPLETE_FIRST"] == "1",
           let first = workoutSession.exercises.first {
            for setIdx in 0..<first.sets.count {
                workoutSession.completeSet(exerciseIndex: 0, setIndex: setIdx)
            }
        }

        // Seed two demo soundtrack tracks so the finish-sheet section renders
        // populated for screenshots. Skip when running under the soundtrack
        // capture bypass already (we want a deterministic preview).
        if env["XOMFIT_AUTO_SEED_TRACKS"] == "1" {
            workoutSession.addManualTrack(title: "Pump Anthem", artist: "Demo Artist")
            workoutSession.addManualTrack(title: "Heavy Lift", artist: "Squat Crew")
        }

        // Optionally jump straight into the active runner so the cover renders.
        workoutSession.isPresented = true
    }
    #endif
}
