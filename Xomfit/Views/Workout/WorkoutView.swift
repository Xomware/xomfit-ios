import SwiftUI

struct WorkoutView: View {
    @Environment(AuthService.self) private var authService
    @Environment(WorkoutLoggerViewModel.self) private var workoutSession
    @Environment(GeneratorPreseed.self) private var generatorPreseed

    /// Work deferred to a sheet's `onDismiss` — see `runAfterDismiss()`.
    @State private var afterDismiss: (() -> Void)?
    @State private var showBuilder = false
    @State private var showLogPastWorkout = false
    @State private var showGenerator = false
    @State private var previewTemplate: WorkoutTemplate?

    /// Owns generator config/preview state across the sheet lifetime.
    @State private var generatorViewModel = WorkoutGeneratorViewModel()

    /// Shared data store for every category list (#338). Owned here so all four
    /// segments share the same loaded data without re-fetching on segment change.
    @State private var viewModel = WorkoutTabViewModel()

    /// Active segment under the CTAs. Defaults to Recents — the most common
    /// landing point for returning users.
    @State private var selectedCategory: WorkoutCategory = .recents

    private var hasStartedFirstWorkout: Bool {
        UserDefaults.standard.bool(forKey: "xomfit_first_workout_started")
    }

    // MARK: - Warmup flow (#261)

    /// Persisted preference: "" = ask each time, "yes" = always warm up, "no" = always skip.
    @AppStorage("warmupOptIn") private var warmupOptIn: String = ""
    /// Default warmup length in minutes — kept here so we can tweak via settings later.
    @AppStorage("warmupMinutes") private var warmupMinutes: Int = 6

    /// Captured action that runs after the warmup (or immediately if skipped).
    @State private var pendingStart: (() -> Void)?
    /// Stretches we'll show during the warmup, computed before presenting the sheet.
    @State private var pendingStretches: [Stretch] = []
    /// Exercises captured at start-flow time so the warmup preview can render
    /// "why this stretch" captions (#349). Empty for "blank start" flows.
    @State private var pendingExercises: [Exercise] = []
    /// Whether to present the warmup sheet right now.
    @State private var showWarmup = false

    private var userId: String {
        authService.currentUser?.id.uuidString.lowercased() ?? ""
    }

    var body: some View {
        // Lives inside `MainTabView`'s NavigationStack (#372). Sheets and the
        // warmup full-screen cover stay attached at the root of the view so
        // they can re-present after the drawer closes.
        // The "Name Your Workout" alert and the "Warm up first?" dialog that
        // used to gate this screen are gone. Between them they put two modals
        // and up to 550ms of scripted delay in front of the single most common
        // action in the app. The workout now starts immediately with a default
        // name (editable live in the workout header), and the warmup offer is a
        // dismissible card inside the session rather than a blocking question.
        workoutRoot
        .fullScreenCover(isPresented: $showWarmup) {
            WarmupView(
                stretches: pendingStretches.isEmpty ? StretchDatabase.defaultRoutine() : pendingStretches,
                totalDuration: warmupMinutes * 60,
                exercises: pendingExercises
            ) {
                runPendingStartImmediately()
            }
        }
        .sheet(isPresented: $showBuilder, onDismiss: {
            Task { await viewModel.load(userId: userId) }
        }) {
            WorkoutBuilderView()
        }
        .sheet(isPresented: $showLogPastWorkout, onDismiss: {
            Task { await viewModel.load(userId: userId) }
        }) {
            LogPastWorkoutView()
        }
        // Both template-start paths below hand their work to `afterDismiss`,
        // which the sheet's `onDismiss` runs. Previously they fired straight
        // into `requestStart` while the sheet was still animating away, and a
        // hardcoded 0.35s delay was used to hope the dismissal had finished.
        .sheet(isPresented: $showGenerator, onDismiss: {
            Task { await viewModel.load(userId: userId) }
            runAfterDismiss()
        }) {
            WorkoutGeneratorConfigView(
                viewModel: generatorViewModel,
                userId: userId,
                onStart: { template in
                    afterDismiss = {
                        requestStart(
                            stretches: StretchDatabase.suggestedStretches(for: template, target: TimeInterval(warmupMinutes * 60)),
                            exercises: template.exercises.map(\.exercise)
                        ) {
                            workoutSession.startFromTemplate(template, userId: userId)
                            workoutSession.isPresented = true
                        }
                    }
                    showGenerator = false
                },
                onSaved: {
                    Task { await viewModel.load(userId: userId) }
                }
            )
        }
        .sheet(item: $previewTemplate, onDismiss: { runAfterDismiss() }) { template in
            TemplateDetailView(template: template) {
                let captured = template
                afterDismiss = {
                    requestStart(
                        stretches: StretchDatabase.suggestedStretches(for: captured, target: TimeInterval(warmupMinutes * 60)),
                        exercises: captured.exercises.map(\.exercise)
                    ) {
                        workoutSession.startFromTemplate(captured, userId: userId)
                        workoutSession.isPresented = true
                    }
                }
                previewTemplate = nil
            }
        }
    }

    /// Work deferred until the presenting sheet has actually finished
    /// dismissing. Replaces the delay-and-hope sequencing.
    private func runAfterDismiss() {
        let work = afterDismiss
        afterDismiss = nil
        work?()
    }

    // MARK: - Root

    private var workoutRoot: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: Theme.Spacing.sm) {
                        // One primary action, then a single row of secondary
                        // ones. This screen used to stack five full-width CTAs
                        // — Start, Build, Log Past, Cardio, Generate — before
                        // any actual workout content appeared, so the list you
                        // came here for started below the fold.
                        Button {
                            Haptics.light()
                            startBlankWorkout()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "play.fill")
                                Text("Start Workout")
                            }
                        }
                        .buttonStyle(AccentButtonStyle())
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.top, Theme.Spacing.md)

                        HStack(spacing: Theme.Spacing.sm) {
                            secondaryAction(icon: "hammer.fill", label: "Build") {
                                showBuilder = true
                            }
                            secondaryAction(icon: "dice.fill", label: "Generate") {
                                generatorViewModel.reset()
                                showGenerator = true
                            }
                            secondaryAction(icon: "calendar.badge.clock", label: "Log Past") {
                                showLogPastWorkout = true
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.md)

                        // First workout guide for new users (#310).
                        // Persist this card even after recents arrive — gate
                        // only on whether the user has built/saved their own
                        // template (myTemplates + savedTemplates), plus the
                        // manual "Skip" escape hatch.
                        if viewModel.myTemplates.isEmpty
                            && viewModel.savedTemplates.isEmpty
                            && !hasStartedFirstWorkout {
                            firstWorkoutCard
                        }

                        // Category segmented nav + selected list (#338)
                        WorkoutCategoryTabs(selection: $selectedCategory)
                            .padding(.top, Theme.Spacing.sm)

                        WorkoutCategoryListView(category: selectedCategory, viewModel: viewModel)
                    }
                }
                // #339: lift bottom of scroll content above the resume bar so
                // the last item isn't hidden under chrome.
                .safeAreaPadding(.bottom, Theme.Spacing.md)
            }
        }
        .navigationTitle("Workout")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await viewModel.load(userId: userId)
            // Consume any pending nudge pre-seed that arrived before this view
            // mounted (e.g. the toast tap flipped destination → .workout).
            consumePendingPreseed()
        }
        .onChange(of: generatorPreseed.pending) { _, _ in
            consumePendingPreseed()
        }
        .onChange(of: workoutSession.isPresented) { _, isPresented in
            if !isPresented {
                Task { await viewModel.load(userId: userId) }
            }
        }
    }

    /// Open the generator pre-seeded with the muscle the training nudge surfaced.
    /// Checked both on mount (`.task`) and on change to cover the race where this
    /// view mounts after the nudge tap flips the destination.
    private func consumePendingPreseed() {
        guard let muscle = generatorPreseed.pending else { return }
        generatorViewModel.reset()
        generatorViewModel.preseed(muscle: muscle)
        showGenerator = true
        generatorPreseed.pending = nil
    }

    /// Compact secondary CTA chip. Three of these in one row replace what were
    /// three full-width rows.
    private func secondaryAction(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.light()
            action()
        } label: {
            VStack(spacing: Theme.Spacing.tight) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                Text(label)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(Theme.accent)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
            .background(Theme.surface, in: .rect(cornerRadius: Theme.cornerRadius))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// Starts an unnamed session immediately. The name defaults to "Workout"
    /// and stays editable in the active-workout header, which is a better place
    /// to name it than a modal you have to clear before you can lift.
    private func startBlankWorkout() {
        requestStart(stretches: StretchDatabase.defaultRoutine(target: TimeInterval(warmupMinutes * 60))) {
            workoutSession.startWorkout(name: "Workout", userId: userId)
            workoutSession.isPresented = true
        }
    }

    // MARK: - First Workout Guide

    private var firstWorkoutCard: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 40))
                .foregroundStyle(Theme.accent)

            Text("Welcome to XomFit!")
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.textPrimary)

            Text("Start with a guided workout to learn the ropes. We'll walk you through logging sets, using the rest timer, and more.")
                .font(Theme.fontBody)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                Haptics.success()
                UserDefaults.standard.set(true, forKey: "xomfit_first_workout_started")
                if let template = WorkoutTemplate.builtIn.first(where: { $0.id == "tpl-fb-a" }) {
                    requestStart(
                        stretches: StretchDatabase.suggestedStretches(for: template, target: TimeInterval(warmupMinutes * 60)),
                        exercises: template.exercises.map(\.exercise)
                    ) {
                        workoutSession.startFromTemplate(template, userId: userId)
                        workoutSession.isPresented = true
                    }
                }
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "play.fill")
                    Text("Start Guided Workout")
                }
            }
            .buttonStyle(AccentButtonStyle())

            Button {
                UserDefaults.standard.set(true, forKey: "xomfit_first_workout_started")
            } label: {
                Text("Skip — I know what I'm doing")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
        .padding(.horizontal, Theme.Spacing.md)
    }

    // MARK: - Warmup gating (#261)

    /// Entry point used by every "start workout" path.
    ///
    /// Only the explicit "always warm up" preference still interrupts; every
    /// other case starts lifting immediately. The old default was to *ask*,
    /// which meant a confirmation dialog stood between the user and the primary
    /// action of the app every single session until they picked a preference.
    private func requestStart(stretches: [Stretch], exercises: [Exercise] = [], action: @escaping () -> Void) {
        pendingStart = action
        pendingStretches = stretches
        pendingExercises = exercises

        if warmupOptIn == "yes" {
            showWarmup = true
        } else {
            runPendingStartImmediately()
        }
    }

    /// Run the captured pending start action and clear it.
    ///
    /// This used to trail a fixed 0.2s `asyncAfter` to let a dismissing sheet
    /// get out of the way — racing a hardcoded delay against an animation.
    /// Callers now sequence off `onDismiss`, which is deterministic.
    private func runPendingStartImmediately() {
        let action = pendingStart
        pendingStart = nil
        pendingStretches = []
        pendingExercises = []
        action?()
    }
}
