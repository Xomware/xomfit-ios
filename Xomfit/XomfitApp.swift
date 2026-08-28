import SwiftUI

@main
struct XomFitApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var authService = AuthService()
    @State private var workoutSession = WorkoutLoggerViewModel()

    /// Shared in-process channel for the training nudge → generator hop (#P2).
    /// The nudge toast sets `pending`; `WorkoutView` consumes it to open the
    /// generator pre-seeded with that muscle.
    @State private var generatorPreseed = GeneratorPreseed()

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

    /// DEBUG-only: id of a workout to surface in a WorkoutDetailView modal
    /// for the agent screenshot harness (#411 follow-up). Set via the
    /// `XOMFIT_OPEN_WORKOUT_DETAIL=<id>` env var; cleared when dismissed.
    @State private var debugWorkoutDetailId: String? = nil
    #endif

    /// Force-quit recovery (#399). When the user (or the OS) terminates the app
    /// mid-workout, the active session is persisted by `WorkoutLoggerViewModel`
    /// and offered back on the next launch via this alert. `pendingRestoreInfo`
    /// is non-nil only while the prompt is visible; resolved by Resume / Discard.
    @State private var pendingRestoreInfo: WorkoutRestoreInfo? = nil

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
                        .environment(generatorPreseed)
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
                            // Garmin takes the same route. `initialize` has to
                            // happen before any device work, and the URL scheme
                            // it registers is how Garmin Connect hands devices
                            // back after selection.
                            GarminSyncService.shared.start()
                            evaluateFitnessQuestionnaireGate()
                            evaluateActiveSessionRestore()
                        }
                        .onReceive(NotificationCenter.default.publisher(for: .garminActionReceived)) { note in
                            // The Garmin asks; the phone decides. Routing through
                            // a notification keeps the sync service from reaching
                            // into the view model.
                            switch note.userInfo?["action"] as? String {
                            case "doneSet":
                                // Idempotent entry point, same as the Apple
                                // Watch: Bluetooth can deliver twice.
                                workoutSession.completeFocusedSetFromWatch()
                            case "skipRest":
                                workoutSession.skipRestTimer()
                            case "logSet":
                                workoutSession.logSetFromWatch(
                                    weight: note.userInfo?["weight"] as? Int,
                                    reps: note.userInfo?["reps"] as? Int
                                )
                            case "extendRest":
                                workoutSession.extendRestTimer()
                            case "nextExercise":
                                workoutSession.focusNextExercise()
                            // The watch asks; the phone decides which state the
                            // workout ends up in, so both agree even if a
                            // message drops.
                            case "togglePause":
                                workoutSession.togglePause()
                            // The watch's plan screen picks an exercise
                            // directly. Bounds-checked on the view model, since
                            // the watch's copy of the plan can lag.
                            case "jumpToExercise":
                                if let index = note.userInfo?["index"] as? Int {
                                    workoutSession.focusExercise(at: index)
                                }
                            case "adjustSet":
                                workoutSession.adjustFocusedSetFromWatch(
                                    reps: note.userInfo?["reps"] as? Int,
                                    weight: note.userInfo?["weight"] as? Int
                                )
                            default:
                                break
                            }
                        }
                        .alert(
                            "Resume workout?",
                            isPresented: Binding(
                                get: { pendingRestoreInfo != nil },
                                set: { if !$0 { pendingRestoreInfo = nil } }
                            ),
                            presenting: pendingRestoreInfo
                        ) { info in
                            Button("Resume") {
                                Haptics.light()
                                _ = workoutSession.restoreActiveSession()
                                pendingRestoreInfo = nil
                            }
                            .accessibilityHint("Reopens the workout exactly where you left it.")
                            Button("Discard", role: .destructive) {
                                Haptics.warning()
                                WorkoutLoggerViewModel.declineRestore()
                                pendingRestoreInfo = nil
                            }
                            .accessibilityHint("Deletes the saved workout and ends the Live Activity.")
                        } message: { info in
                            Text("Your “\(info.workoutName)” workout was still running. Pick up where you left off — started \(info.startedRelative).")
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

                            // Agent screenshot helper (#411 follow-up): open
                            // a specific workout's detail view from a cold
                            // launch by setting `XOMFIT_OPEN_WORKOUT_DETAIL=<id>`.
                            // Combine with XOMFIT_AUTH_BYPASS=1 to inspect the
                            // soundtrack edit / read-only UI end-to-end.
                            if let workoutId = ProcessInfo.processInfo.environment["XOMFIT_OPEN_WORKOUT_DETAIL"],
                               !workoutId.isEmpty {
                                try? await Task.sleep(for: .milliseconds(500))
                                debugWorkoutDetailId = workoutId
                            }
                        }
                        .fullScreenCover(item: Binding(
                            get: { debugWorkoutDetailId.map { DebugWorkoutDetailRoute(id: $0) } },
                            set: { debugWorkoutDetailId = $0?.id }
                        )) { route in
                            DebugWorkoutDetailHost(workoutId: route.id)
                                .environment(authService)
                                .environment(workoutSession)
                                .preferredColorScheme(.dark)
                        }
                        #endif
                } else {
                    LoginView()
                        .environment(authService)
                }
            }
            .preferredColorScheme(.dark)
            .onOpenURL { url in
                // Garmin first, and in this handler rather than a nested one.
                //
                // Device selection sends the lifter to Garmin Connect and comes
                // back as `xomfit-garmin://device-select-resp`. That scheme
                // matches none of the `xomfit://` cases below and fell through
                // to the Supabase catch-all at the end, which swallowed it
                // inside a `try?` — Garmin Connect opened, the lifter picked a
                // watch, and nothing came back.
                //
                // There was a second `.onOpenURL` nested further in that was
                // meant to catch this. Two handlers on one scene is not a
                // contract SwiftUI guarantees, and the one that consumed the URL
                // won. One router now, ordered explicitly.
                if GarminSyncService.shared.handleOpenURL(url) {
                    return
                }
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
                // Anything left is assumed to be a Supabase auth callback.
                // Deliberately last: it accepts any URL and reports nothing, so
                // adding a scheme after this point means adding a silent hole.
                Task {
                    try? await supabase.auth.session(from: url)
                }
            }
        }
    }

    /// Force-quit recovery (#399). When the app launches and finds a persisted
    /// in-progress workout, surface the resume alert so the user can pick up
    /// where they left off. Stale (>12h) blobs are dropped silently — see
    /// `WorkoutLoggerViewModel.restoreActiveSession`'s threshold.
    @MainActor
    private func evaluateActiveSessionRestore() {
        // Don't double-prompt if a workout is already live (e.g. user navigated
        // away and back without killing the app).
        guard !workoutSession.isActive else { return }
        guard let snapshot = WorkoutLoggerViewModel.peekSavedSession() else { return }

        let age = Date().timeIntervalSince(snapshot.savedAt)
        if age > WorkoutLoggerViewModel.staleSessionAge {
            // Auto-clean stale blobs + any orphan Live Activity. Don't ask.
            WorkoutLoggerViewModel.declineRestore()
            return
        }

        // Skip under DEBUG bypass flags that seed their own workout — the
        // seeded session would otherwise conflict with the resume alert.
        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        if env["XOMFIT_AUTO_START_WORKOUT"] == "1" {
            WorkoutLoggerViewModel.declineRestore()
            return
        }
        #endif

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let startedRelative = formatter.localizedString(for: snapshot.startTime, relativeTo: Date())

        pendingRestoreInfo = WorkoutRestoreInfo(
            workoutName: snapshot.workoutName.isEmpty ? "Workout" : snapshot.workoutName,
            startedRelative: startedRelative
        )
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
    /// Seed an in-progress workout for agent screenshot flows (#387/#402).
    /// Adds real exercises and (optionally) completes the first, pairs them as
    /// a superset, enters focus mode, fires the rest timer, or pops the finish
    /// sheet so the new UI surfaces from a cold launch.
    ///
    /// Env vars:
    ///   XOMFIT_AUTO_START_WORKOUT=1     → start workout, two exercises seeded
    ///   XOMFIT_AUTO_COMPLETE_FIRST=1    → also complete every set on the first
    ///                                     exercise so the transition card shows
    ///   XOMFIT_AUTO_PRESENT_FINISH=1    → also present the finish sheet
    ///   XOMFIT_AUTO_SEED_TRACKS=1       → add demo soundtrack tracks
    ///   XOMFIT_AUTO_LONG_NAME=1         → swap second exercise for one with a
    ///                                     long name so the superset-list card
    ///                                     overflow fix can be verified (#402)
    ///   XOMFIT_AUTO_GROUP_SUPERSET=1    → group the two seeded exercises into
    ///                                     a superset so the "Superset A/B"
    ///                                     badges + alternation logic render
    ///   XOMFIT_AUTO_ENTER_FOCUS=1       → flip into focus mode on launch
    ///   XOMFIT_AUTO_START_REST_TIMER=1  → fire the rest timer immediately so
    ///                                     the fullscreen overlay renders
    ///   XOMFIT_AUTO_MINIMIZE_REST=1     → start the rest timer in its minimized
    ///                                     banner state (read by WorkoutFocusView)
    ///   XOMFIT_AUTO_FOCUS_WEIGHT=1      → auto-focus the weight TextField in
    ///                                     focus mode so the keyboard-collapse
    ///                                     compact mode (#411 bug 6) renders.
    ///                                     Read by WorkoutFocusView's onAppear.
    ///   XOMFIT_AUTO_COMPLETE_FIRST_SET=1 → mark only set 1 of the first exercise
    ///                                     complete (90×7) without firing the rest
    ///                                     timer — used to screenshot the in-session
    ///                                     "Last 90×7" caption on set 2.
    ///   XOMFIT_AUTO_PR_BANNER=1         → seed a fake PR celebration so the
    ///                                     banner can be screenshotted without
    ///                                     a live network PR check.
    ///   XOMFIT_AUTO_TIER_BANNER=<n>     → seed a tier-up celebration at
    ///                                     StrengthTier rawValue n (4 = Diamond).
    ///                                     Set alongside XOMFIT_AUTO_PR_BANNER to
    ///                                     check that one banner wins, not two.
    ///   XOMFIT_AUTO_SHOW_JUMPER=1       → auto-open the Switch Exercise sheet on
    ///                                     first appearance — used to screenshot
    ///                                     the new Add Exercise (+) toolbar button.
    @MainActor
    private func seedDebugActiveWorkout() {
        let env = ProcessInfo.processInfo.environment

        // Always clear any in-memory workout state so the seeded one is
        // deterministic across re-launches in the same simulator session.
        if workoutSession.isActive {
            workoutSession.discardWorkout()
        }

        let userId = authService.currentUser?.id.uuidString.lowercased() ?? ""
        // Long workout name so the row-2 truncation behavior can be observed.
        let name = env["XOMFIT_AUTO_LONG_NAME"] == "1"
            ? "(s)arms" : "Screenshot Workout"
        workoutSession.startWorkout(name: name, userId: userId)

        // Two exercises from ExerciseDatabase. Picked deterministically by
        // id so the seeded workout looks consistent across screenshot runs.
        // When XOMFIT_AUTO_LONG_NAME=1 we swap in the longest-named tricep
        // exercise so the superset list-card overflow is reproducible.
        let preferredIds: [String]
        if env["XOMFIT_AUTO_LONG_NAME"] == "1" {
            // Long-named exercise FIRST so the list-card overflow fix can be
            // captured at the top of the scroll view (#402).
            preferredIds = ["ex-cable-overhead-tri-ext", "ex-tricep-pushdown"]
        } else {
            preferredIds = ["ex-bench-flat", "ex-lat-pulldown"]
        }
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

        // Group the two seeded exercises as a superset so the list-card layout,
        // the focus-mode badge, and the alternation logic can all be exercised
        // from a cold launch (#402).
        if env["XOMFIT_AUTO_GROUP_SUPERSET"] == "1",
           workoutSession.exercises.count >= 2 {
            workoutSession.toggleSuperset(exerciseIndices: [0, 1])
        }

        // Optionally complete the first exercise so the transition card shows
        // immediately on launch.
        if env["XOMFIT_AUTO_COMPLETE_FIRST"] == "1",
           let first = workoutSession.exercises.first {
            for setIdx in 0..<first.sets.count {
                workoutSession.completeSet(exerciseIndex: 0, setIndex: setIdx)
            }
        }

        // Complete EVERY exercise so the transition card's all-done state
        // (Add Exercise / Finish Workout) can be screenshotted.
        if env["XOMFIT_AUTO_COMPLETE_ALL"] == "1" {
            for exIdx in workoutSession.exercises.indices {
                for setIdx in workoutSession.exercises[exIdx].sets.indices {
                    workoutSession.completeSet(exerciseIndex: exIdx, setIndex: setIdx)
                }
            }
        }

        // Screenshot helper for the "Last shows prior in-session set" change:
        // seed only set 1 of the first exercise with concrete weight/reps and
        // mark it complete via direct field writes (no side effects). Skips
        // the real `completeSet` path so the rest timer doesn't fire and the
        // cover stays mounted on ActiveWorkoutView for the agent screenshot.
        if env["XOMFIT_AUTO_COMPLETE_FIRST_SET"] == "1",
           workoutSession.exercises.first != nil,
           !workoutSession.exercises[0].sets.isEmpty {
            workoutSession.exercises[0].sets[0].weight = 90
            workoutSession.exercises[0].sets[0].reps = 7
            workoutSession.exercises[0].sets[0].completedAt = Date()
        }

        // Seed two demo soundtrack tracks so the finish-sheet section renders
        // populated for screenshots. Skip when running under the soundtrack
        // capture bypass already (we want a deterministic preview).
        if env["XOMFIT_AUTO_SEED_TRACKS"] == "1" {
            workoutSession.addManualTrack(title: "Pump Anthem", artist: "Demo Artist")
            workoutSession.addManualTrack(title: "Heavy Lift", artist: "Squat Crew")
        }

        // Flip into focus mode so the gym-floor layout is the first thing the
        // user / agent sees (#402).
        // Seed a celebration so the banner's placement and auto-dismiss can be
        // screenshotted without a live PR (which needs the network) or a real
        // tier promotion (which needs matching PR history).
        if env["XOMFIT_AUTO_PR_BANNER"] == "1" {
            let pr = PersonalRecord(
                id: "debug-pr", userId: userId, exerciseId: "ex-bench-flat",
                exerciseName: "Bench Press", weight: 245, reps: 5,
                date: Date(), previousBest: 225
            )
            workoutSession.newPR = pr
            workoutSession.present(.personalRecord(pr))
        }
        if let raw = env["XOMFIT_AUTO_TIER_BANNER"],
           let tier = StrengthTier(rawValue: Int(raw) ?? -1) {
            workoutSession.present(.tierUp(
                exerciseId: "ex-bench-flat",
                exerciseName: "Bench Press",
                tier: tier
            ))
        }
        // Present the post-workout recap without actually finishing (which
        // needs the network). Seeds one of each achievement kind.
        if env["XOMFIT_AUTO_SUMMARY"] == "1" {
            workoutSession.lastSummary = WorkoutSummary(
                workoutName: "Screenshot Workout",
                duration: 62 * 60,
                totalVolume: 24_310,
                totalSets: 18,
                exerciseCount: 5,
                beatTheClockSets: 6,
                personalRecords: [
                    PersonalRecord(
                        id: "debug-pr", userId: userId, exerciseId: "ex-bench-flat",
                        exerciseName: "Bench Press", weight: 245, reps: 5,
                        date: Date(), previousBest: 225
                    )
                ],
                tierUps: [
                    WorkoutSummary.TierUp(exerciseName: "Bench Press", tier: .diamond)
                ],
                newBadges: Array(BadgeCatalog.all.prefix(2))
            )
        }
        if env["XOMFIT_AUTO_ENTER_FOCUS"] == "1" {
            workoutSession.focusMode = true
            workoutSession.syncFocusToCurrentExercise()
        }

        // Fire the rest timer immediately. Useful for screenshotting both the
        // fullscreen rest timer overlay (focus mode) and the inline rest timer
        // card (list mode) from a cold launch (#402).
        if env["XOMFIT_AUTO_START_REST_TIMER"] == "1" {
            workoutSession.startRestTimer(for: workoutSession.focusExerciseIndex)
        }

        // Optionally seed the rest timer in its minimized banner state — the
        // VM owns this flag now (#409) so both the focus view and the header
        // chip can read/write it.
        if env["XOMFIT_AUTO_MINIMIZE_REST"] == "1" {
            workoutSession.isRestTimerMinimized = true
        }

        // Optionally jump straight into the active runner so the cover renders.
        workoutSession.isPresented = true
    }
    #endif
}

/// Lightweight value type passed to the resume alert (#399). Carries only the
/// strings the prompt needs so we don't have to plumb the full `PersistedSession`
/// through `@State` and `Binding` machinery.
private struct WorkoutRestoreInfo: Identifiable {
    let id = UUID()
    let workoutName: String
    let startedRelative: String
}

#if DEBUG
// MARK: - Debug Workout Detail Host (#411 follow-up)

/// `Identifiable` wrapper so `fullScreenCover(item:)` can drive presentation
/// from the `XOMFIT_OPEN_WORKOUT_DETAIL=<id>` env var.
private struct DebugWorkoutDetailRoute: Identifiable {
    let id: String
}

/// Loads a workout from `WorkoutService` and pushes `WorkoutDetailView` inside
/// a NavigationStack. Used only by the agent screenshot harness so the
/// soundtrack edit UI can be inspected from a cold launch.
private struct DebugWorkoutDetailHost: View {
    let workoutId: String
    @State private var workout: Workout?
    @State private var didError = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                if let workout {
                    WorkoutDetailView(workout: workout)
                        .navigationBarBackButtonHidden(false)
                } else if didError {
                    Text("Workout not found")
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    ProgressView()
                        .tint(Theme.accent)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task {
            let fetched = await WorkoutService.shared.fetchWorkout(id: workoutId)
            if let fetched {
                workout = fetched
            } else {
                didError = true
            }
        }
    }
}
#endif
