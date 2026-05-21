import SwiftUI
import PhotosUI

struct ActiveWorkoutView: View {
    @Environment(AuthService.self) private var authService
    @Environment(WorkoutLoggerViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var showExercisePicker = false
    @State private var showDiscardAlert = false
    @State private var showFinishSheet = false
    @State private var workoutDescription = ""
    @State private var saveAsTemplate = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoImages: [UIImage] = []
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var restTimerHapticFired = false
    @State private var showStartingExercisePicker = false
    /// Mid-workout exercise jumper (#253). Reachable any time via the persistent pill.
    @State private var showExerciseJumper = false
    /// Set after `jumpToExercise` runs; consumed by the list-mode `ScrollViewReader`
    /// to scroll to the picked card, then cleared.
    @State private var pendingScrollIndex: Int?

    // Soundtrack-capture popover (Spotify capture polish). Tapping the
    // "Recording soundtrack" pill in the footer opens a small disclosure with
    // the captured-tracks-so-far count + most recently captured track per source.
    @State private var showSoundtrackPopover = false
    /// Live mirrors of the singleton capture services. Used purely to subscribe to
    /// `@Observable` changes — calls still go through `.shared`.
    @State private var spotifyCapture = SpotifyNowPlayingService.shared
    @State private var appleMusicCapture = NowPlayingService.shared

    // First-run polish (#310)
    /// Persisted flag — once dismissed, the active-workout tutorial overlay never re-shows.
    @AppStorage("xomfit_first_workout_tutorial_seen") private var firstTutorialSeen = false
    /// Persisted flag — first-ever rest timer toast across the user's history.
    @AppStorage("xomfit_first_rest_timer_seen") private var firstRestTimerSeen = false
    /// Drives the tutorial overlay. Lifted to local state so we can animate it
    /// in/out independently of the AppStorage write.
    @State private var showFirstTutorial = false
    /// Single-shot rest timer onboarding toast.
    @State private var restTimerToast: Toast?

    var body: some View {
        @Bindable var viewModel = viewModel

        // Timed-circuit workouts (#370) use a dedicated runner UI — simpler
        // exercise carousel + countdown ring, no per-set logging.
        if viewModel.kind == .timedCircuit {
            TimedCircuitView()
        } else {
            setsRepsBody
        }
    }

    @ViewBuilder
    private var setsRepsBody: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header bar — sits BELOW the Dynamic Island via explicit
                    // safe-area padding inside the header itself (#402).
                    headerBar

                    // Persistent current-exercise pill (#253). Sits below the header so it
                    // doesn't fight any other header controls (pause button, etc.).
                    if !viewModel.exercises.isEmpty {
                        currentExercisePill
                    }

                    // Rest timer config — hidden when rest timer is running (redundant with the active card)
                    if !viewModel.isRestTimerActive && !viewModel.focusMode {
                        restTimerConfig
                    }

                    if viewModel.focusMode {
                        // Focus mode — large gym-floor view
                        WorkoutFocusView(viewModel: viewModel)
                    } else {
                        // Rest timer
                        if viewModel.isRestTimerActive {
                            RestTimerView(
                                restTimeRemaining: viewModel.restTimeRemaining,
                                restDuration: viewModel.restDuration,
                                onSkip: {
                                    viewModel.skipRestTimer()
                                    restTimerHapticFired = false
                                },
                                onExtend: { viewModel.extendRestTimer() }
                            )
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, Theme.Spacing.sm)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // Exercise list
                        if viewModel.exercises.isEmpty {
                            emptyState
                        } else {
                            ScrollViewReader { proxy in
                                ScrollView {
                                    LazyVStack(spacing: Theme.Spacing.md) {
                                        ForEach(viewModel.exercises.indices, id: \.self) { exIdx in
                                            ExerciseCard(
                                                exerciseIndex: exIdx,
                                                viewModel: viewModel
                                            )
                                            .id(exIdx)
                                        }
                                    }
                                    .padding(Theme.Spacing.md)
                                }
                                // Bottom inset that just clears the soundtrack
                                // capture pill (when visible) — the Add Exercise
                                // FAB is gone (#402); add-exercise lives in the
                                // top header now. Keeping a generous 24pt so the
                                // last set rows don't kiss the home indicator.
                                .contentMargins(.bottom, Theme.Spacing.lg, for: .scrollContent)
                                .onTapGesture {
                                    UIApplication.shared.sendAction(
                                        #selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil
                                    )
                                }
                                .onChange(of: pendingScrollIndex) { _, newValue in
                                    guard let idx = newValue else { return }
                                    withAnimation(.xomChill) {
                                        proxy.scrollTo(idx, anchor: .top)
                                    }
                                    // Clear after the scroll has been kicked off.
                                    pendingScrollIndex = nil
                                }
                            }
                        }
                    }
                }
                .animation(.xomChill, value: viewModel.isRestTimerActive)
                .animation(.xomChill, value: viewModel.showExerciseTransition)
                .animation(.xomChill, value: viewModel.focusMode)

                // Soundtrack capture pill (Spotify capture polish). Visible only
                // while at least one capture loop is alive. The Add Exercise FAB
                // moved to the top header (#402) — remove it from the bottom
                // entirely. The soundtrack pill rides above the home indicator
                // via `.safeAreaInset(.bottom)` further down so it never overlaps
                // set rows OR a fullscreen rest timer's LIFT button.

                // PR Celebration Banner
                if viewModel.showPRCelebration, let pr = viewModel.newPR {
                    VStack {
                        PRCelebrationBanner(pr: pr) {
                            withAnimation { viewModel.showPRCelebration = false }
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                        Spacer()
                    }
                }

                // First-run tutorial overlay (#310). Sits above the rest of
                // the workout UI so it's the first thing the user sees on
                // their first active workout. Persisted by AppStorage so it
                // never re-shows after dismissal.
                if showFirstTutorial {
                    FirstWorkoutTutorial {
                        withAnimation(.xomConfident) {
                            showFirstTutorial = false
                        }
                        firstTutorialSeen = true
                    }
                }

                // Exercise Transition Overlay
                if viewModel.showExerciseTransition {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { withAnimation { viewModel.dismissTransition() } }

                    VStack {
                        Spacer()
                        ExerciseTransitionCard(
                            viewModel: viewModel,
                            onAddExercise: { showExercisePicker = true },
                            onFinishWorkout: {
                                Haptics.success()
                                workoutDescription = ""
                                showFinishSheet = true
                            }
                        )
                            .padding(Theme.Spacing.md)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .animation(.xomConfident, value: viewModel.showExerciseTransition)
                }
            }
            // Bottom safe-area inset (#402). When music capture is running,
            // surface the soundtrack pill anchored above the home indicator —
            // never floating over set rows or a fullscreen rest timer's LIFT
            // button. Otherwise just a hair of padding so the last row clears
            // the OS gesture area.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !viewModel.focusMode &&
                    (spotifyCapture.isCapturing || appleMusicCapture.isCapturing) {
                    soundtrackCapturePill
                        .padding(.bottom, Theme.Spacing.xs)
                } else {
                    Color.clear.frame(height: Theme.Spacing.xs)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .foregroundStyle(Theme.accent)
                }
            }
        }
        .onReceive(timer) { _ in
            viewModel.tickRestTimer()
            viewModel.tickLiveActivity()
            // Haptic fires once when rest timer crosses zero
            if viewModel.isRestTimerActive && viewModel.restTimeRemaining <= 0 && !restTimerHapticFired {
                restTimerHapticFired = true
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        }
        .onChange(of: viewModel.isRestTimerActive) { _, isActive in
            if isActive {
                restTimerHapticFired = false
                // First-time rest timer toast (#310). Surface a small explainer
                // the very first time the rest timer fires, then never again.
                if !firstRestTimerSeen {
                    firstRestTimerSeen = true
                    restTimerToast = Toast(
                        style: .info,
                        message: "Rest timer running. +30s adds time, Skip ends it, tap to minimize.",
                        duration: 5.0
                    )
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel.recalculateRestTimer()
            }
        }
        .sheet(isPresented: $showExercisePicker) {
            ExercisePickerView { exercise in
                viewModel.addExercise(exercise)
            }
        }
        .alert("Discard Workout?", isPresented: $showDiscardAlert) {
            Button("Discard", role: .destructive) {
                viewModel.discardWorkout()
                dismiss()
            }
            Button("Keep Going", role: .cancel) {}
        } message: {
            Text("All logged sets will be lost.")
        }
        .sheet(isPresented: $showFinishSheet) {
            FinishWorkoutSheet(
                viewModel: viewModel,
                description: $workoutDescription,
                location: $viewModel.location,
                rating: $viewModel.rating,
                saveAsTemplate: $saveAsTemplate,
                selectedPhotos: $selectedPhotos,
                photoImages: $photoImages,
                isSaving: viewModel.isSaving,
                onFinish: { finishWorkout() }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showExerciseJumper) {
            ExerciseJumperSheet(viewModel: viewModel) { idx in
                // Trigger list-mode scroll. In focus mode this is harmless —
                // `.id(viewModel.focusExerciseIndex)` on the focus view drives
                // the visual transition independently.
                pendingScrollIndex = idx
            }
        }
        .sheet(isPresented: $showStartingExercisePicker) {
            NavigationStack {
                List {
                    let incomplete = Array(viewModel.exercises.enumerated()).filter { _, ex in
                        ex.sets.contains { $0.completedAt == Date.distantPast }
                    }
                    if incomplete.isEmpty {
                        Text("All exercises complete!")
                            .foregroundStyle(Theme.textSecondary)
                            .font(Theme.fontBody)
                    } else {
                        ForEach(incomplete, id: \.element.id) { idx, exercise in
                            let remaining = exercise.sets.filter { $0.completedAt == Date.distantPast }.count
                            Button {
                                viewModel.focusExerciseIndex = idx
                                viewModel.focusSetIndex = 0
                                showStartingExercisePicker = false
                            } label: {
                                HStack {
                                    Text(exercise.exercise.name)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(Theme.textPrimary)
                                    Spacer()
                                    Text("\(remaining) sets left")
                                        .font(Theme.fontCaption)
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Start With")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("First") {
                            showStartingExercisePicker = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        // First-run rest timer toast (#310). Uses the existing toast pattern
        // shared with launch streak/PR badges in MainTabView.
        .toast($restTimerToast)
        .onAppear {
            // Show the active-workout tutorial overlay only on the user's
            // very first active workout. Defer slightly so it lands after
            // the cover's mount animation finishes (#310).
            if !firstTutorialSeen && !showFirstTutorial {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(450))
                    if !firstTutorialSeen {
                        withAnimation(.xomConfident) {
                            showFirstTutorial = true
                        }
                    }
                }
            }

            #if DEBUG
            // Agent screenshot helper for #387 — auto-present the finish sheet so
            // the new soundtrack / location UI surfaces from a cold launch.
            if ProcessInfo.processInfo.environment["XOMFIT_AUTO_PRESENT_FINISH"] == "1" {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(600))
                    workoutDescription = ""
                    showFinishSheet = true
                }
            }
            #endif
        }
    }

    // MARK: - Header
    //
    // Two-row layout (#399) so nothing collides with the Dynamic Island. The
    // top row only contains corner controls (Discard / Minimize / Finish) —
    // they're far enough from center that they sit cleanly to the left/right
    // of the island. The second row carries the timer + workout name +
    // pause/focus toggles, which live BELOW the island so they're never
    // occluded.
    //
    // Previous single-row design (#287/#289) tried to squeeze 6 controls into
    // one row, which on iPhone 14/15/16/17 Pro models collided with the
    // Dynamic Island and clipped the duration timer.

    /// Header bar. The parent `ZStack` already respects the top safe-area
    /// inset (only `Theme.background.ignoresSafeArea()` extends the BG to the
    /// screen edge — content lives inside the inset). So the VStack content
    /// already starts below the Dynamic Island; previous revisions stacked an
    /// additional ~62pt manual inset on top, which doubled the offset and
    /// floated the toolbar ~128pt down on iPhone 17 Pro (TestFlight 2.1.0 +
    /// 2.1.1, #409 → #411).
    ///
    /// We now apply ONLY a small breathing buffer:
    ///   - List mode: `Theme.Spacing.xs` (4pt) — anchor tight to the island.
    ///   - Focus mode: `Theme.Spacing.lg` (24pt) — wider buffer keeps the
    ///     gym-floor layout from feeling cramped under the island.
    ///
    /// The header background still extends past the safe area via
    /// `.ignoresSafeArea(edges: .top)` so the status bar / island sit on the
    /// surface color rather than the workout background.
    private var headerBar: some View {
        let extraBuffer: CGFloat = viewModel.focusMode ? Theme.Spacing.lg : Theme.Spacing.xs
        return VStack(spacing: Theme.Spacing.xs) {
            headerTopRow
            headerSecondRow
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, extraBuffer)
        .padding(.bottom, Theme.Spacing.sm)
        .frame(maxWidth: .infinity)
        .background(Theme.surface.ignoresSafeArea(edges: .top))
    }

    /// Row 1 — corner controls only. Discard sits on the leading edge; Minimize
    /// + Finish sit on the trailing edge. The center reserves a 130pt-wide gap
    /// so the Dynamic Island (≈125pt × 37pt on iPhone Pro models) never clips
    /// any interactive content (#402).
    private var headerTopRow: some View {
        HStack(spacing: Theme.Spacing.xs) {
            // Discard button — leading corner.
            Button {
                Haptics.warning()
                showDiscardAlert = true
            } label: {
                Text("Discard")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.destructive)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Discard workout")
            .accessibilityHint("Ends and deletes the in-progress workout without saving")

            // Hard-reserved center gap for the Dynamic Island. 130pt is wider
            // than the island's pill (~125pt) so corner controls can never be
            // covered (#402). Using a fixed-width Color.clear instead of a
            // Spacer guarantees the gap even when leading content grows.
            Color.clear
                .frame(width: 130, height: 1)
                .accessibilityHidden(true)

            Spacer(minLength: 0)

            // Minimize — dismiss the cover and leave the workout running in the
            // background. The persistent resume bar in MainTabView re-presents
            // it via `xomfit://workout` or a tap.
            Button {
                Haptics.light()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    viewModel.isPresented = false
                }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(Theme.textSecondary.opacity(0.15))
                    .clipShape(Circle())
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Minimize workout")
            .accessibilityHint("Hides the active workout and returns to the main app. The workout keeps running.")

            // Finish button.
            Button {
                Haptics.success()
                workoutDescription = ""
                showFinishSheet = true
            } label: {
                if viewModel.isSaving {
                    ProgressView()
                        .tint(.black)
                        .frame(width: 60, height: 28)
                        .background(Theme.accent)
                        .clipShape(.rect(cornerRadius: 8))
                } else {
                    Text("Finish")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.black)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Theme.accent)
                        .clipShape(.rect(cornerRadius: 8))
                }
            }
            .disabled(viewModel.isSaving)
            .accessibilityLabel("Finish workout")
        }
    }

    /// Row 2 — timer + name on the leading edge, pause + focus toggle + add
    /// exercise on the trailing edge. Lives below the Dynamic Island so the
    /// duration string is never clipped (#402).
    private var headerSecondRow: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // Timer cluster — total time prominent + rest timer chip when active.
            VStack(alignment: .leading, spacing: Theme.Spacing.tighter) {
                HStack(spacing: 6) {
                    HStack(spacing: 3) {
                        Image(systemName: "clock.fill")
                            .font(Theme.fontCaption2)
                        Text(viewModel.durationString)
                            .font(Theme.fontNumberMedium)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .foregroundStyle(Theme.accent)

                    if viewModel.isRestTimerActive {
                        restTimerChip
                    }
                }

                HStack(spacing: 4) {
                    if WatchSyncService.shared.isWatchAvailable {
                        Image(systemName: "applewatch")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.accent.opacity(0.8))
                            .accessibilityLabel("Apple Watch connected")
                    }
                    Text(viewModel.workoutName)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                }
            }
            .animation(.xomChill, value: viewModel.isRestTimerActive)

            Spacer(minLength: Theme.Spacing.xs)

            // Pause / Resume toggle.
            Button {
                Haptics.light()
                withAnimation(.xomChill) {
                    viewModel.togglePause()
                }
            } label: {
                Image(systemName: viewModel.isPaused ? "play.circle.fill" : "pause.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(viewModel.isPaused ? Theme.accent : Theme.textPrimary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(viewModel.isPaused ? "Resume workout" : "Pause workout")
            .accessibilityHint(viewModel.isPaused
                ? "Resumes the elapsed timer and rest countdown"
                : "Freezes the elapsed timer and rest countdown")

            // Focus mode toggle.
            Button {
                withAnimation {
                    viewModel.focusMode.toggle()
                    if viewModel.focusMode {
                        viewModel.syncFocusToCurrentExercise()
                        if viewModel.completedSets == 0 && viewModel.exercises.count > 1 {
                            showStartingExercisePicker = true
                        }
                    }
                }
            } label: {
                Image(systemName: viewModel.focusMode ? "list.bullet" : "eye")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(viewModel.focusMode ? Theme.accent : Theme.textSecondary)
                    .frame(width: Theme.Spacing.xl, height: Theme.Spacing.xl)
                    .background(viewModel.focusMode ? Theme.accent.opacity(0.15) : Theme.textSecondary.opacity(0.15))
                    .clipShape(Circle())
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(viewModel.focusMode ? "Switch to list view" : "Switch to focus view")

            // Add Exercise — promoted from a bottom FAB to a top-bar control
            // (#402). Lives in row 2 so it sits well below the Dynamic Island.
            Button {
                Haptics.selection()
                showExercisePicker = true
            } label: {
                Image(systemName: "plus")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: Theme.Spacing.xl, height: Theme.Spacing.xl)
                    .background(Theme.accent.opacity(0.15))
                    .clipShape(Circle())
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Add exercise")
            .accessibilityHint("Opens the exercise picker to add a new exercise to this workout")
        }
    }

    // MARK: - Current Exercise Pill (#253)

    /// Persistent, tappable indicator of the current exercise + set.
    /// Sits directly below the header bar (intentionally not inside the headerBar
    /// to avoid colliding with other header controls).
    private var currentExercisePill: some View {
        Button {
            Haptics.selection()
            showExerciseJumper = true
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)

                if viewModel.allExercisesComplete {
                    Text("All exercises complete")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                } else if let name = viewModel.currentExerciseName {
                    Text(name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)

                    Text("\u{2022}")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.textTertiary)

                    Text("Set \(viewModel.currentSetNumber)/\(max(viewModel.currentExerciseTotalSets, 1))")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                } else {
                    Text("—")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer(minLength: Theme.Spacing.sm)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .frame(minHeight: 44)
            .frame(maxWidth: .infinity)
            .background(Theme.surface)
            .clipShape(.capsule)
            .overlay(
                Capsule()
                    .stroke(Theme.accent.opacity(0.2), lineWidth: 1)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.xs)
        .accessibilityLabel(pillAccessibilityLabel)
        .accessibilityHint("Opens the exercise list to switch exercises")
    }

    /// Voice-over label that names the current exercise + set context.
    private var pillAccessibilityLabel: String {
        if viewModel.allExercisesComplete {
            return "All exercises complete. Tap to switch exercises."
        }
        guard let name = viewModel.currentExerciseName else {
            return "No current exercise. Tap to choose one."
        }
        let total = max(viewModel.currentExerciseTotalSets, 1)
        return "Current exercise: \(name), set \(viewModel.currentSetNumber) of \(total). Tap to switch exercises."
    }

    /// Compact rest countdown string for the header chip (matches RestTimerView format).
    private var headerRestString: String {
        let remaining = viewModel.restTimeRemaining
        let total = Int(abs(remaining))
        let mins = total / 60
        let secs = total % 60
        let prefix = remaining < 0 ? "-" : ""
        return prefix + String(format: "%d:%02d", mins, secs)
    }

    /// Header rest-timer chip. Single informational rendering across both
    /// list and focus modes (#411 bug 3) — the previous tap-to-expand variant
    /// (#409) created inconsistent visuals between list and focus mode and
    /// duplicated the expand affordance already provided by the focus-mode
    /// minimized banner. The chip is now a passive readout in both modes.
    private var restTimerChip: some View {
        let isOvertime = viewModel.restTimeRemaining <= 0
        return HStack(spacing: 3) {
            Image(systemName: "timer")
                .font(Theme.fontCaption2)
            Text(headerRestString)
                .font(Theme.fontNumberMedium)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: true, vertical: false)
        }
        .foregroundStyle(isOvertime ? Theme.destructive : Theme.textPrimary)
        .padding(.horizontal, 7)
        .padding(.vertical, Theme.Spacing.tighter)
        .background(
            Capsule()
                .fill((isOvertime ? Theme.destructive : Theme.accent).opacity(0.15))
        )
        .overlay(
            Capsule()
                .strokeBorder((isOvertime ? Theme.destructive : Theme.accent).opacity(0.35), lineWidth: 0.5)
        )
        .transition(.scale.combined(with: .opacity))
        .accessibilityLabel("Rest timer \(headerRestString) remaining")
    }

    // MARK: - Rest Timer Config

    private var restTimerConfig: some View {
        HStack {
            XomBadge(
                "Rest Timer",
                icon: "timer",
                color: viewModel.defaultRestDuration > 0 ? Theme.accent : Theme.textSecondary,
                variant: .display
            )

            Spacer()

            Menu {
                Button("Off") { viewModel.defaultRestDuration = 0 }
                Button("30s") { viewModel.defaultRestDuration = 30 }
                Button("60s") { viewModel.defaultRestDuration = 60 }
                Button("90s") { viewModel.defaultRestDuration = 90 }
                Button("120s") { viewModel.defaultRestDuration = 120 }
                Button("180s") { viewModel.defaultRestDuration = 180 }
            } label: {
                XomBadge(
                    viewModel.defaultRestDuration > 0 ? "\(Int(viewModel.defaultRestDuration))s" : "Off",
                    color: viewModel.defaultRestDuration > 0 ? Theme.accent : Theme.textSecondary,
                    variant: .interactive,
                    isActive: viewModel.defaultRestDuration > 0
                )
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
    }

    // MARK: - Soundtrack Capture Pill (Spotify capture polish)

    /// Compact, accent-tinted pill telling the user that workout music capture is running.
    /// One pill total — sources are summarized in the label and the popover. Hidden when
    /// neither service is actively polling.
    private var soundtrackCapturePill: some View {
        Button {
            Haptics.light()
            showSoundtrackPopover = true
        } label: {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "music.note")
                    .font(.caption.weight(.bold))
                Text(soundtrackPillLabel)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                if totalCapturedCount > 0 {
                    Text("\(totalCapturedCount)")
                        .font(.caption2.weight(.heavy).monospacedDigit())
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Theme.accent.opacity(0.22), in: Capsule())
                }
            }
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, 6)
            .frame(minHeight: 32)
            .background(Theme.accent.opacity(0.12), in: Capsule())
            .overlay(Capsule().stroke(Theme.accent.opacity(0.35), lineWidth: 0.5))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(soundtrackPillAccessibilityLabel)
        .accessibilityHint("Shows the songs captured so far for this workout's soundtrack")
        .popover(isPresented: $showSoundtrackPopover, attachmentAnchor: .point(.top)) {
            soundtrackPopoverContent
                .presentationCompactAdaptation(.popover)
        }
    }

    /// Pill label — composes from whichever services are currently capturing.
    private var soundtrackPillLabel: String {
        switch (spotifyCapture.isCapturing, appleMusicCapture.isCapturing) {
        case (true, true):  return "Recording soundtrack"
        case (true, false): return "Recording soundtrack via Spotify"
        case (false, true): return "Recording soundtrack via Apple Music"
        case (false, false): return "Recording soundtrack" // unreachable — pill is hidden
        }
    }

    private var soundtrackPillAccessibilityLabel: String {
        let count = totalCapturedCount
        let countSuffix = count == 0
            ? "no tracks yet"
            : "\(count) track\(count == 1 ? "" : "s") captured"
        return "\(soundtrackPillLabel), \(countSuffix)"
    }

    private var totalCapturedCount: Int {
        spotifyCapture.capturedCount + appleMusicCapture.capturedCount
    }

    /// Popover content surfacing per-source counts + last captured track so the user can
    /// confirm capture is working without finishing the workout.
    private var soundtrackPopoverContent: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "music.note.list")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                Text("Soundtrack capture")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
            }

            if spotifyCapture.isCapturing {
                soundtrackPopoverSource(
                    name: "Spotify",
                    count: spotifyCapture.capturedCount,
                    last: spotifyCapture.lastCapturedTrack
                )
            }
            if appleMusicCapture.isCapturing {
                soundtrackPopoverSource(
                    name: "Apple Music",
                    count: appleMusicCapture.capturedCount,
                    last: appleMusicCapture.lastCapturedTrack
                )
            }

            if totalCapturedCount == 0 {
                Text("Nothing captured yet — start playing music and we'll log it.")
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Theme.Spacing.md)
        .frame(minWidth: 240, maxWidth: 300)
    }

    private func soundtrackPopoverSource(name: String, count: Int, last: WorkoutTrack?) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.tighter) {
            HStack {
                Text(name)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(count) track\(count == 1 ? "" : "s")")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.textSecondary)
            }
            if let last {
                Text("Last: \(last.title)\(last.artist.map { " — \($0)" } ?? "")")
                    .font(Theme.fontSmall)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack {
            Spacer()
            XomEmptyState(
                symbolStack: ["dumbbell.fill", "figure.strengthtraining.traditional"],
                title: "No exercises yet",
                subtitle: "Tap \"Add Exercise\" to get started.",
                floatingLoop: true
            )
            Spacer()
            Spacer()
        }
    }

    // MARK: - Actions

    private func finishWorkout() {
        guard !viewModel.isSaving else { return }
        guard let user = authService.currentUser else { return }
        let userId = user.id.uuidString.lowercased()
        let notes = workoutDescription.trimmingCharacters(in: .whitespacesAndNewlines)

        // Save as template if requested
        if saveAsTemplate {
            let templateExercises = viewModel.exercises.map { ex in
                WorkoutTemplate.TemplateExercise(
                    id: UUID().uuidString,
                    exercise: ex.exercise,
                    targetSets: ex.sets.count,
                    targetReps: ex.bestSet.map { "\($0.reps)" } ?? "8",
                    notes: ex.notes,
                    restSeconds: ex.restSeconds
                )
            }
            let template = WorkoutTemplate(
                id: UUID().uuidString,
                name: viewModel.workoutName,
                description: notes.isEmpty ? "Custom template" : notes,
                exercises: templateExercises,
                estimatedDuration: Int(Date().timeIntervalSince(viewModel.startTime) / 60),
                category: .custom,
                isCustom: true
            )
            TemplateService.shared.saveCustomTemplate(template)
        }

        Task {
            // Upload photos if any were selected
            var uploadedURLs: [String]?
            if !photoImages.isEmpty {
                uploadedURLs = try? await PhotoService.shared.uploadWorkoutPhotos(
                    photoImages,
                    workoutId: UUID().uuidString,
                    userId: userId
                )
            }

            await viewModel.finishWorkout(userId: userId, notes: notes.isEmpty ? nil : notes, photoURLs: uploadedURLs)
            if viewModel.errorMessage == nil {
                showFinishSheet = false
                dismiss()
            }
        }
    }
}

// MARK: - PR Celebration Banner

private struct PRCelebrationBanner: View {
    let pr: PersonalRecord
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "trophy.fill")
                .font(Theme.fontTitle3)
                .foregroundStyle(.black)

            VStack(alignment: .leading, spacing: Theme.Spacing.tighter) {
                Text("New Personal Record!")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(.black)
                Text("\(pr.exerciseName) — \(pr.weight.formattedWeight) lbs × \(pr.reps)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.black.opacity(0.75))
            }

            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.black.opacity(0.6))
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Dismiss new PR banner")
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.md)
        .background(Theme.prGold)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.sm)
        .shadow(color: Theme.prGold.opacity(0.5), radius: 8, x: 0, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("New personal record: \(pr.exerciseName), \(pr.weight.formattedWeight) lbs for \(pr.reps) reps")
    }
}

// MARK: - Exercise Card

private struct ExerciseCard: View {
    let exerciseIndex: Int
    let viewModel: WorkoutLoggerViewModel

    @State private var showDetails = false
    @State private var showSupersetActionSheet = false
    /// Driven by the visible link-icon button in the header. Distinct from
    /// `showSupersetActionSheet` so the long-press and tap paths don't fight
    /// over a single binding (#294).
    @State private var showSupersetToggleConfirm = false

    private var isInSuperset: Bool {
        viewModel.exercises.indices.contains(exerciseIndex)
            && viewModel.exercises[exerciseIndex].supersetGroupId != nil
    }

    private var supersetLetter: String? {
        viewModel.supersetLetter(forExercise: exerciseIndex)
    }

    private var canGroupWithNext: Bool {
        guard exerciseIndex + 1 < viewModel.exercises.count else { return false }
        return viewModel.exercises[exerciseIndex].supersetGroupId == nil
            || viewModel.exercises[exerciseIndex].supersetGroupId
                != viewModel.exercises[exerciseIndex + 1].supersetGroupId
    }

    @ViewBuilder
    var body: some View {
        if viewModel.exercises.indices.contains(exerciseIndex) {
            let exercise = viewModel.exercises[exerciseIndex]
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Exercise header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    // Superset pill — moved to its OWN row so the title gets
                    // the full card width. Previously sat to the left of the
                    // title and shrunk it to ~2 chars per line on supersetted
                    // exercises with long names (#402).
                    if let letter = supersetLetter {
                        Text("Superset \(letter)")
                            .font(.caption2.weight(.black))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, Theme.Spacing.tighter)
                            .background(Theme.accent)
                            .clipShape(.capsule)
                            .accessibilityLabel("Superset \(letter)")
                    }
                    HStack(spacing: 6) {
                        Text(exercise.exercise.name)
                            .font(.body.weight(.bold))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    HStack(spacing: Theme.Spacing.tight) {
                        ForEach(exercise.exercise.muscleGroups.prefix(2), id: \.self) { mg in
                            Text(mg.displayName)
                                .font(Theme.fontSmall)
                                .foregroundStyle(Theme.accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, Theme.Spacing.tighter)
                                .background(Theme.accent.opacity(0.15))
                                .clipShape(.rect(cornerRadius: 4))
                        }
                    }
                }

                Button {
                    Haptics.selection()
                    showDetails = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: Theme.Spacing.xl, height: Theme.Spacing.xl)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show details for \(exercise.exercise.name)")

                Spacer()

                // Reorder buttons
                if exerciseIndex > 0 {
                    Button {
                        withAnimation(.xomConfident) {
                            viewModel.moveExercise(from: exerciseIndex, direction: -1)
                        }
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.textPrimary)
                            .frame(width: 44, height: 44)
                            .background(Theme.surface.opacity(0.5))
                            .clipShape(Circle())
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Move \(exercise.exercise.name) up")
                }

                if exerciseIndex < viewModel.exercises.count - 1 {
                    Button {
                        withAnimation(.xomConfident) {
                            viewModel.moveExercise(from: exerciseIndex, direction: 1)
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.textPrimary)
                            .frame(width: 44, height: 44)
                            .background(Theme.surface.opacity(0.5))
                            .clipShape(Circle())
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Move \(exercise.exercise.name) down")
                }

                // Superset toggle (#294) — visible affordance for grouping with the
                // next exercise. Disabled (but still rendered) when neither action
                // is meaningful, so the button row layout stays stable.
                Button {
                    Haptics.selection()
                    showSupersetToggleConfirm = true
                } label: {
                    Image(systemName: isInSuperset ? "link.circle.fill" : "link")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isInSuperset ? Theme.accent : Theme.textSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!isInSuperset && !canGroupWithNext)
                .accessibilityLabel(isInSuperset
                    ? "Ungroup superset"
                    : "Group with next exercise as superset")
                .accessibilityHint(isInSuperset
                    ? "Removes this exercise from its superset"
                    : "Pairs this exercise with the next one for back-to-back sets")

                Button {
                    viewModel.removeExercise(at: exerciseIndex)
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Remove \(exercise.exercise.name)")
            }

            // Variant config (grip, attachment, position, laterality) + per-session extras
            // (notes pill, rest override). The extras pills always render so the user can
            // edit notes / rest even on exercises without grip/attachment/position variants.
            ExerciseConfigRow(
                exercise: exercise,
                onGripChanged: { grip in viewModel.setGrip(exerciseIndex: exerciseIndex, grip: grip) },
                onAttachmentChanged: { att in viewModel.setAttachment(exerciseIndex: exerciseIndex, attachment: att) },
                onPositionChanged: { pos in viewModel.setPosition(exerciseIndex: exerciseIndex, position: pos) },
                onLateralityChanged: { lat in viewModel.setLaterality(exerciseIndex: exerciseIndex, laterality: lat) },
                onNotesChanged: { notes in viewModel.setNotes(exerciseIndex: exerciseIndex, notes: notes) },
                onRestSecondsChanged: { secs in viewModel.setRestSeconds(exerciseIndex: exerciseIndex, seconds: secs) },
                defaultRestSeconds: Int(viewModel.defaultRestDuration)
            )

            // Laterality badge
            if exercise.exercise.supportsUnilateral && exercise.selectedLaterality != .bilateral {
                HStack(spacing: Theme.Spacing.tight) {
                    Image(systemName: "arrow.left.and.right")
                        .font(Theme.fontCaption2)
                    Text(exercise.selectedLaterality.displayName)
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 6)
                .padding(.vertical, Theme.Spacing.tighter)
                .background(Theme.accent.opacity(0.15))
                .clipShape(.capsule)
            }

            // Column headers
            if !exercise.sets.isEmpty {
                HStack(spacing: Theme.Spacing.sm) {
                    Spacer().frame(width: 30) // delete button spacer
                    Text("SET")
                        .frame(width: Theme.Spacing.lg)
                    Spacer()
                    Text("WEIGHT")
                        .frame(maxWidth: .infinity)
                    Text("")
                        .frame(width: 40)
                    Text("REPS")
                        .frame(maxWidth: .infinity)
                    Text("")
                        .frame(width: 36)
                }
                .font(Theme.fontSmall)
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, Theme.Spacing.md)
            }

            // Per-exercise current set index — first incomplete row, or the
            // last row if all sets are complete. Drives the accent border +
            // tint on the SetRowView so the lifter always knows where they
            // are in list mode (#411 bug 4).
            let currentSetIdx: Int? = {
                if let firstIncomplete = exercise.sets.firstIndex(where: { $0.completedAt == Date.distantPast }) {
                    return firstIncomplete
                }
                return exercise.sets.indices.last
            }()

            // Sets — use stable element IDs to prevent state loss on expand/collapse
            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { setIdx, workoutSet in
                SetRowView(
                    setNumber: setIdx + 1,
                    workoutSet: workoutSet,
                    onWeightChange: { w in
                        viewModel.updateSet(
                            exerciseIndex: exerciseIndex,
                            setIndex: setIdx,
                            weight: w,
                            reps: viewModel.exercises[exerciseIndex].sets[setIdx].reps
                        )
                    },
                    onRepsChange: { r in
                        viewModel.updateSet(
                            exerciseIndex: exerciseIndex,
                            setIndex: setIdx,
                            weight: viewModel.exercises[exerciseIndex].sets[setIdx].weight,
                            reps: r
                        )
                    },
                    onComplete: {
                        viewModel.completeSet(exerciseIndex: exerciseIndex, setIndex: setIdx)
                    },
                    onDelete: {
                        viewModel.removeSet(exerciseIndex: exerciseIndex, setIndex: setIdx)
                    },
                    onToggleWeightMode: {
                        viewModel.toggleWeightMode(exerciseIndex: exerciseIndex, setIndex: setIdx)
                    },
                    onAddDropSet: {
                        viewModel.addDropSet(exerciseIndex: exerciseIndex, parentSetIndex: setIdx)
                    },
                    lateralityLabel: exercise.selectedLaterality != .bilateral ? (exercise.exercise.muscleGroups.contains(where: { [.quads, .hamstrings, .glutes, .calves].contains($0) }) ? "/leg" : "/arm") : nil,
                    lastSet: viewModel.lastSetForExercise(exercise.exercise.id),
                    personalRecord: viewModel.personalRecordForExercise(exercise.exercise.id),
                    isCurrentSet: setIdx == currentSetIdx
                )
            }

            // Add Set button
            Button {
                viewModel.addSet(to: exerciseIndex)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Add Set")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Theme.accent.opacity(0.08))
                .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
            }
            .padding(.top, Theme.Spacing.tight)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.surface)
        .overlay(alignment: .leading) {
            // Vertical accent bar marking superset members
            if isInSuperset {
                Rectangle()
                    .fill(Theme.accent)
                    .frame(width: Theme.Spacing.tight)
                    .accessibilityHidden(true)
            }
        }
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
        .onLongPressGesture(minimumDuration: 0.5) {
            // Only present the menu when there is something actionable
            guard isInSuperset || canGroupWithNext else { return }
            Haptics.selection()
            showSupersetActionSheet = true
        }
        .confirmationDialog(
            exercise.exercise.name,
            isPresented: $showSupersetActionSheet,
            titleVisibility: .visible
        ) {
            if isInSuperset {
                Button("Ungroup Superset", role: .destructive) {
                    Haptics.light()
                    viewModel.toggleSupersetWithNext(exerciseIndex: exerciseIndex)
                }
            }
            if canGroupWithNext {
                Button("Group with Next Exercise") {
                    Haptics.success()
                    viewModel.toggleSupersetWithNext(exerciseIndex: exerciseIndex)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(isInSuperset
                 ? "This exercise is part of a superset."
                 : "Group this exercise with the next one for back-to-back sets.")
        }
        // Visible-affordance dialog (#294). Mirrors the long-press menu but
        // surfaces a single primary action so the icon-button intent is clear.
        .confirmationDialog(
            isInSuperset ? "Ungroup Superset?" : "Group with Next Exercise?",
            isPresented: $showSupersetToggleConfirm,
            titleVisibility: .visible
        ) {
            if isInSuperset {
                Button("Ungroup Superset", role: .destructive) {
                    Haptics.light()
                    viewModel.toggleSupersetWithNext(exerciseIndex: exerciseIndex)
                }
            } else if canGroupWithNext {
                Button("Group with Next Exercise") {
                    Haptics.success()
                    viewModel.toggleSupersetWithNext(exerciseIndex: exerciseIndex)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(isInSuperset
                 ? "Removes \(exercise.exercise.name) from its superset."
                 : "Pairs \(exercise.exercise.name) with the next exercise for back-to-back sets.")
        }
        .sheet(isPresented: $showDetails) {
            ExerciseDetailSheet(exercise: exercise.exercise)
        }
        }
    }
}

// MARK: - Exercise Transition Card

private struct ExerciseTransitionCard: View {
    let viewModel: WorkoutLoggerViewModel
    var onAddExercise: (() -> Void)?
    var onFinishWorkout: (() -> Void)?
    @State private var showRemainingList = false

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Header: completed exercise name
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .font(Theme.fontTitle2)
                    .foregroundStyle(Theme.accent)
                Text("\(viewModel.completedExerciseName) Complete")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button {
                    withAnimation { viewModel.dismissTransition() }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
            }

            // Option 1: Do Another Set
            Button {
                withAnimation { viewModel.addAnotherSet() }
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.bold))
                    Text("Do Another Set")
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                        .stroke(Theme.accent, lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add another set to \(viewModel.completedExerciseName)")

            // Option 2: Move to Next Exercise
            if let nextIdx = viewModel.nextExerciseIndex, let nextEx = viewModel.nextExercise {
                Button {
                    withAnimation { viewModel.moveToExercise(index: nextIdx) }
                } label: {
                    VStack(spacing: Theme.Spacing.tight) {
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "arrow.right")
                                .font(.subheadline.weight(.bold))
                            Text("Move to \(nextEx.exercise.name)")
                                .font(.subheadline.weight(.bold))
                        }
                        .foregroundStyle(.black)

                        // Show config hints (grips, attachments, positions)
                        configHints(for: nextEx.exercise)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Move to \(nextEx.exercise.name)")
            }

            // All exercises complete — prompt to add or finish
            if viewModel.allExercisesComplete {
                VStack(spacing: Theme.Spacing.sm) {
                    HStack(spacing: 6) {
                        Image(systemName: "trophy.fill")
                            .font(Theme.fontBody)
                            .foregroundStyle(Theme.accent)
                        Text("All exercises complete!")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.textPrimary)
                    }

                    Text("Add another exercise or finish your workout.")
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)

                    // Add Exercise
                    if let onAddExercise {
                        Button {
                            withAnimation { viewModel.dismissTransition() }
                            onAddExercise()
                        } label: {
                            HStack(spacing: Theme.Spacing.sm) {
                                Image(systemName: "plus")
                                    .font(.subheadline.weight(.bold))
                                Text("Add Exercise")
                                    .font(.subheadline.weight(.bold))
                            }
                            .foregroundStyle(Theme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                                    .stroke(Theme.accent, lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // Finish Workout
                    if let onFinishWorkout {
                        Button {
                            withAnimation { viewModel.dismissTransition() }
                            onFinishWorkout()
                        } label: {
                            HStack(spacing: Theme.Spacing.sm) {
                                Image(systemName: "checkmark")
                                    .font(.subheadline.weight(.bold))
                                Text("Finish Workout")
                                    .font(.subheadline.weight(.bold))
                            }
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Theme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, Theme.Spacing.sm)
            }

            // Option 3: Choose Different
            if !viewModel.remainingExercises.isEmpty {
                VStack(spacing: 0) {
                    Button {
                        withAnimation(.xomConfident) {
                            showRemainingList.toggle()
                        }
                    } label: {
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "list.bullet")
                                .font(.subheadline.weight(.bold))
                            Text("Choose Different")
                                .font(.subheadline.weight(.bold))
                            Spacer()
                            Image(systemName: showRemainingList ? "chevron.up" : "chevron.down")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.vertical, 12)
                        .padding(.horizontal, Theme.Spacing.md)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Choose a different exercise")

                    if showRemainingList {
                        VStack(spacing: 0) {
                            ForEach(viewModel.remainingExercises) { item in
                                Button {
                                    withAnimation { viewModel.moveToExercise(index: item.index) }
                                } label: {
                                    HStack(spacing: Theme.Spacing.sm) {
                                        Circle()
                                            .fill(Theme.accent.opacity(0.3))
                                            .frame(width: 6, height: 6)
                                        Text(item.name)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(Theme.textPrimary)
                                        Spacer()
                                    }
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, Theme.Spacing.md)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Switch to \(item.name)")
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .background(Theme.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall))
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .shadow(color: .black.opacity(0.5), radius: 16, x: 0, y: -4)
    }

    @ViewBuilder
    private func configHints(for exercise: Exercise) -> some View {
        let hints = buildConfigHints(for: exercise)
        if !hints.isEmpty {
            Text(hints.joined(separator: " \u{2022} "))
                .font(.caption.weight(.medium))
                .foregroundStyle(.black.opacity(0.6))
        }
    }

    private func buildConfigHints(for exercise: Exercise) -> [String] {
        var hints: [String] = []
        if let attachments = exercise.supportedAttachments {
            hints.append(contentsOf: attachments.prefix(2).map(\.displayName))
        }
        if let grips = exercise.supportedGrips {
            hints.append(contentsOf: grips.prefix(2).map(\.displayName))
        }
        if let positions = exercise.supportedPositions {
            hints.append(contentsOf: positions.prefix(2).map(\.displayName))
        }
        return hints
    }
}

// MARK: - Finish Workout Sheet

private struct FinishWorkoutSheet: View {
    /// Passed in so the sheet can render the captured-soundtrack section and
    /// accept manual track additions / removals (#387). Plain `let` — we only
    /// call methods + read computed properties; `@Observable` already invalidates
    /// the body on mutations to those properties.
    let viewModel: WorkoutLoggerViewModel
    @Binding var description: String
    @Binding var location: String
    @Binding var rating: Int
    @Binding var saveAsTemplate: Bool
    @Binding var selectedPhotos: [PhotosPickerItem]
    @Binding var photoImages: [UIImage]
    let isSaving: Bool
    let onFinish: () -> Void

    /// Drives the manual-track entry sub-sheet (#387).
    @State private var showManualTrackSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        // Star Rating
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("How was your workout?")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.textPrimary)
                            HStack(spacing: Theme.Spacing.sm) {
                                ForEach(1...5, id: \.self) { star in
                                    Button {
                                        withAnimation(.xomChill) {
                                            rating = rating == star ? 0 : star
                                        }
                                    } label: {
                                        Image(systemName: star <= rating ? "star.fill" : "star")
                                            .font(Theme.fontTitle2)
                                            .foregroundStyle(star <= rating ? Theme.accent : Theme.textSecondary.opacity(0.4))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("\(star) star\(star > 1 ? "s" : "")")
                                }
                                Spacer()
                            }
                        }

                        // Location (#387.3) — single-line free-text input above
                        // the soundtrack section. Placeholder steers the user to
                        // any short label (gym, home, park...). Trimming happens
                        // in the save path on the view model.
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("Location")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.textPrimary)
                            HStack(spacing: Theme.Spacing.sm) {
                                Image(systemName: "location.fill")
                                    .font(Theme.fontCaption)
                                    .foregroundStyle(Theme.textSecondary)
                                TextField("Where? (gym, home, park...)", text: $location)
                                    .font(Theme.fontBody)
                                    .foregroundStyle(Theme.textPrimary)
                                    .accessibilityLabel("Workout location")
                                    .accessibilityHint("Optional. Where you did this workout — gym, home, park, etc.")
                            }
                            .padding(Theme.Spacing.sm)
                            .background(Theme.surface)
                            .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                                    .stroke(Theme.textSecondary.opacity(0.2), lineWidth: 1)
                            )
                        }

                        // Soundtrack (#387.2) — captured Now Playing tracks plus
                        // any manual additions, with per-row remove. Sits above
                        // the caption so the user reviews their soundtrack right
                        // after rating/location.
                        soundtrackSection

                        // Description
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("Caption")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.textPrimary)
                            Text("Optional — appears on your feed post.")
                                .font(Theme.fontCaption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        TextEditor(text: $description)
                            .font(Theme.fontBody)
                            .foregroundStyle(Theme.textPrimary)
                            .scrollContentBackground(.hidden)
                            .padding(Theme.Spacing.sm)
                            .frame(minHeight: 80, maxHeight: 120)
                            .background(Theme.surface)
                            .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                                    .stroke(Theme.textSecondary.opacity(0.2), lineWidth: 1)
                            )

                        // Save as template toggle
                        Toggle(isOn: $saveAsTemplate) {
                            HStack(spacing: Theme.Spacing.sm) {
                                Image(systemName: "bookmark.fill")
                                    .foregroundStyle(Theme.accent)
                                Text("Save as Template")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Theme.textPrimary)
                            }
                        }
                        .tint(Theme.accent)

                        // Photos
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("Photos")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.textPrimary)
                            Text("Add up to 4 photos from your workout.")
                                .font(Theme.fontCaption)
                                .foregroundStyle(Theme.textSecondary)

                            if !photoImages.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: Theme.Spacing.sm) {
                                        ForEach(photoImages.indices, id: \.self) { index in
                                            ZStack(alignment: .topTrailing) {
                                                Image(uiImage: photoImages[index])
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 80, height: 80)
                                                    .clipShape(.rect(cornerRadius: 8))

                                                Button {
                                                    // Both arrays are kept in lockstep by the
                                                    // paired loader in `.onChange(of: selectedPhotos)`,
                                                    // so we remove from each at the same index (#359 bug 7).
                                                    guard photoImages.indices.contains(index) else { return }
                                                    photoImages.remove(at: index)
                                                    if selectedPhotos.indices.contains(index) {
                                                        selectedPhotos.remove(at: index)
                                                    }
                                                } label: {
                                                    // Visible glyph stays compact to fit the 80pt
                                                    // thumbnail; the transparent 44pt outer frame
                                                    // raises the hit target up to HIG (#313).
                                                    ZStack {
                                                        Color.clear
                                                            .frame(width: 44, height: 44)
                                                        Image(systemName: "xmark.circle.fill")
                                                            .font(Theme.fontCaption)
                                                            .foregroundStyle(.white)
                                                            .shadow(radius: 2)
                                                    }
                                                    .contentShape(Rectangle())
                                                }
                                                .offset(x: 14, y: -14)
                                                .accessibilityLabel("Remove photo \(index + 1)")
                                            }
                                        }
                                    }
                                }
                            }

                            PhotosPicker(
                                selection: $selectedPhotos,
                                maxSelectionCount: 4,
                                matching: .images
                            ) {
                                HStack(spacing: 6) {
                                    Image(systemName: "photo.on.rectangle.angled")
                                    Text(photoImages.isEmpty ? "Add Photos" : "Change Photos")
                                        .font(.subheadline.weight(.medium))
                                }
                                .foregroundStyle(Theme.accent)
                                .padding(.horizontal, 12)
                                .padding(.vertical, Theme.Spacing.sm)
                                .background(Theme.accent.opacity(0.12))
                                .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
                            }
                            .onChange(of: selectedPhotos) { _, newItems in
                                Task {
                                    // Use the paired loader so `selectedPhotos` and
                                    // `photoImages` stay in lockstep even when some
                                    // PhotosPickerItems fail to decode. Without this,
                                    // index-based removal targets the wrong photo (#359 bug 7).
                                    let pairs = await PhotoService.shared.loadPaired(from: newItems)
                                    let loadedItems = pairs.map { $0.0 }
                                    let loadedImages = pairs.map { $0.1 }
                                    if loadedItems != selectedPhotos {
                                        selectedPhotos = loadedItems
                                    }
                                    photoImages = loadedImages
                                }
                            }
                        }

                        // Finish button
                        Button {
                            Haptics.workoutComplete()
                            onFinish()
                        } label: {
                            if isSaving {
                                ProgressView()
                                    .tint(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                            } else {
                                Text("Finish Workout")
                                    .font(.body.weight(.bold))
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                            }
                        }
                        .background(Theme.accent)
                        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
                        .disabled(isSaving)
                    }
                    .padding(Theme.Spacing.md)
                }
            }
            .navigationTitle("Finish Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .sheet(isPresented: $showManualTrackSheet) {
            ManualTrackSheet { title, artist in
                viewModel.addManualTrack(title: title, artist: artist)
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: - Soundtrack section (#387.2)

    @ViewBuilder
    private var soundtrackSection: some View {
        let tracks = viewModel.curatedTracksSnapshot
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Text("Soundtrack")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                if !tracks.isEmpty {
                    Text("\(tracks.count)")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Theme.accent.opacity(0.15), in: Capsule())
                }
                Spacer()
            }

            if tracks.isEmpty {
                Text("No songs captured. Add one manually or play music during your next workout.")
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 0) {
                    ForEach(tracks) { track in
                        SoundtrackRow(track: track) {
                            withAnimation(.xomChill) {
                                viewModel.removeCapturedTrack(id: track.id)
                            }
                        }
                        if track.id != tracks.last?.id {
                            Divider()
                                .background(Theme.textSecondary.opacity(0.15))
                                .padding(.leading, Theme.Spacing.md)
                        }
                    }
                }
                .background(Theme.surface)
                .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                        .stroke(Theme.textSecondary.opacity(0.2), lineWidth: 1)
                )
            }

            Button {
                Haptics.selection()
                showManualTrackSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Add manual track")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, Theme.Spacing.sm)
                .frame(minHeight: 44)
                .background(Theme.accent.opacity(0.12))
                .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add a track manually")
            .accessibilityHint("Opens a form to enter a song title and artist")
        }
    }
}

// MARK: - Soundtrack Row (#387.2)

/// Single captured-track row used by the finish sheet. Renders an icon + title
/// + artist + source pill with a trailing trash button. Hit target on the trash
/// is sized to 44pt per HIG.
private struct SoundtrackRow: View {
    let track: WorkoutTrack
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: sourceIcon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let artist = track.artist, !artist.isEmpty {
                        Text(artist)
                            .font(Theme.fontCaption)
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                        Text("\u{2022}")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Theme.textTertiary)
                            .accessibilityHidden(true)
                    }
                    Text(track.sourceApp)
                        .font(Theme.fontSmall)
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Theme.textTertiary.opacity(0.15), in: Capsule())
                }
            }
            Spacer()

            Button {
                Haptics.light()
                onRemove()
            } label: {
                Image(systemName: "trash")
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.destructive.opacity(0.85))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(track.title) from soundtrack")
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(track.title)\(track.artist.map { ", \($0)" } ?? "") from \(track.sourceApp)")
    }

    private var sourceIcon: String {
        switch track.sourceApp.lowercased() {
        case "manual": return "pencil"
        case "spotify": return "music.note"
        case "soundcloud": return "waveform"
        case "apple music": return "music.note"
        default: return "music.note"
        }
    }
}

// MARK: - Manual Track Sheet (#387.2)

/// Compact title + artist entry sheet for adding a song the auto-capture missed.
/// Source is hard-coded to "Manual" by `WorkoutLoggerViewModel.addManualTrack`.
private struct ManualTrackSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var artist: String = ""
    @FocusState private var focusedField: Field?

    enum Field { case title, artist }

    let onAdd: (String, String?) -> Void

    private var canAdd: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        VStack(alignment: .leading, spacing: Theme.Spacing.tighter) {
                            Text("Title")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.textSecondary)
                            TextField("Song title", text: $title)
                                .font(Theme.fontBody)
                                .foregroundStyle(Theme.textPrimary)
                                .focused($focusedField, equals: .title)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .artist }
                                .padding(Theme.Spacing.sm)
                                .background(Theme.surface)
                                .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                                        .stroke(Theme.textSecondary.opacity(0.2), lineWidth: 1)
                                )
                                .accessibilityLabel("Song title")
                        }

                        VStack(alignment: .leading, spacing: Theme.Spacing.tighter) {
                            Text("Artist")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.textSecondary)
                            TextField("Artist (optional)", text: $artist)
                                .font(Theme.fontBody)
                                .foregroundStyle(Theme.textPrimary)
                                .focused($focusedField, equals: .artist)
                                .submitLabel(.done)
                                .onSubmit { if canAdd { commit() } }
                                .padding(Theme.Spacing.sm)
                                .background(Theme.surface)
                                .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                                        .stroke(Theme.textSecondary.opacity(0.2), lineWidth: 1)
                                )
                                .accessibilityLabel("Artist (optional)")
                        }

                        Button {
                            commit()
                        } label: {
                            Text("Add Track")
                                .font(.body.weight(.bold))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(canAdd ? Theme.accent : Theme.accent.opacity(0.4))
                                .clipShape(.rect(cornerRadius: Theme.cornerRadius))
                        }
                        .buttonStyle(.plain)
                        .disabled(!canAdd)
                        .accessibilityLabel("Add track")
                    }
                    .padding(Theme.Spacing.md)
                }
            }
            .navigationTitle("Add Track")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear { focusedField = .title }
    }

    private func commit() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        Haptics.success()
        let trimmedArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        onAdd(trimmedTitle, trimmedArtist.isEmpty ? nil : trimmedArtist)
        dismiss()
    }
}
