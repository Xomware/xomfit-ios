import SwiftUI

struct WorkoutView: View {
    @Environment(AuthService.self) private var authService
    @Environment(WorkoutLoggerViewModel.self) private var workoutSession
    @Environment(GeneratorPreseed.self) private var generatorPreseed

    @State private var showNameEntry = false
    @State private var pendingWorkoutName = ""
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
    /// Whether to ask the user about warming up right now.
    @State private var showWarmupPrompt = false
    /// Whether to present the warmup sheet right now.
    @State private var showWarmup = false

    private var userId: String {
        authService.currentUser?.id.uuidString.lowercased() ?? ""
    }

    var body: some View {
        // Lives inside `MainTabView`'s NavigationStack (#372). Sheets and the
        // warmup full-screen cover stay attached at the root of the view so
        // they can re-present after the drawer closes.
        workoutRoot
            .alert("Name Your Workout", isPresented: $showNameEntry) {
            TextField("e.g. Push Day", text: $pendingWorkoutName)
            Button("Start") {
                let name = pendingWorkoutName.isEmpty ? "Workout" : pendingWorkoutName
                requestStart(stretches: StretchDatabase.defaultRoutine(target: TimeInterval(warmupMinutes * 60))) {
                    workoutSession.startWorkout(name: name, userId: userId)
                    workoutSession.isPresented = true
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Warm up first?",
            isPresented: $showWarmupPrompt,
            titleVisibility: .visible
        ) {
            Button("Yes, \(warmupMinutes) min") {
                warmupOptIn = "yes"
                showWarmup = true
            }
            Button("No, skip") {
                warmupOptIn = "no"
                runPendingStartImmediately()
            }
            Button("Just this once", role: .cancel) {
                // Don't persist a preference — start without warmup but ask again next time.
                runPendingStartImmediately()
            }
        } message: {
            Text("A 5-10 minute stretch routine helps loosen up before lifting.")
        }
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
        .sheet(isPresented: $showGenerator, onDismiss: {
            Task { await viewModel.load(userId: userId) }
        }) {
            WorkoutGeneratorConfigView(
                viewModel: generatorViewModel,
                userId: userId,
                onStart: { template in
                    // Mirror the TemplateDetailView start path: route through the
                    // warmup gate before starting the generated session.
                    requestStart(
                        stretches: StretchDatabase.suggestedStretches(for: template, target: TimeInterval(warmupMinutes * 60)),
                        exercises: template.exercises.map(\.exercise)
                    ) {
                        workoutSession.startFromTemplate(template, userId: userId)
                        workoutSession.isPresented = true
                    }
                },
                onSaved: {
                    Task { await viewModel.load(userId: userId) }
                }
            )
        }
        .sheet(item: $previewTemplate) { template in
            TemplateDetailView(template: template) {
                let captured = template
                previewTemplate = nil
                requestStart(
                    stretches: StretchDatabase.suggestedStretches(for: captured, target: TimeInterval(warmupMinutes * 60)),
                    exercises: captured.exercises.map(\.exercise)
                ) {
                    workoutSession.startFromTemplate(captured, userId: userId)
                    workoutSession.isPresented = true
                }
            }
        }
    }

    // MARK: - Root

    private var workoutRoot: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: Theme.Spacing.sm) {
                        // Start Workout CTA
                        Button {
                            Haptics.light()
                            pendingWorkoutName = ""
                            showNameEntry = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "play.fill")
                                Text("Start Workout")
                            }
                        }
                        .buttonStyle(AccentButtonStyle())
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.top, Theme.Spacing.md)
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.6).onEnded { _ in
                                // Long-press resets the warmup preference so the prompt shows again.
                                Haptics.medium()
                                warmupOptIn = ""
                                pendingWorkoutName = ""
                                showNameEntry = true
                            }
                        )
                        .accessibilityHint("Long press to reset warmup preference")

                        // Build Workout + Log Past Workout (side-by-side)
                        HStack(spacing: Theme.Spacing.sm) {
                            Button {
                                Haptics.light()
                                showBuilder = true
                            } label: {
                                HStack(spacing: Theme.Spacing.sm) {
                                    Image(systemName: "hammer.fill")
                                    Text("Build")
                                }
                            }
                            .buttonStyle(GhostButtonStyle())

                            Button {
                                Haptics.light()
                                showLogPastWorkout = true
                            } label: {
                                HStack(spacing: Theme.Spacing.sm) {
                                    Image(systemName: "calendar.badge.clock")
                                    Text("Log Past")
                                }
                            }
                            .buttonStyle(GhostButtonStyle())
                            .accessibilityLabel("Log a past workout")
                        }
                        .padding(.horizontal, Theme.Spacing.md)

                        // Generate (offline) — the instant, on-device twin of the
                        // AI Coach. Framed distinctly: dice icon + "Instant · No AI
                        // · Offline" so it never reads as a second chat coach.
                        Button {
                            Haptics.light()
                            generatorViewModel.reset()
                            showGenerator = true
                        } label: {
                            HStack(spacing: Theme.Spacing.md) {
                                Image(systemName: "dice.fill")
                                    .font(.title3)
                                    .foregroundStyle(Theme.accent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Generate")
                                        .font(Theme.fontBodyEmphasized)
                                        .foregroundStyle(Theme.textPrimary)
                                    Text("Instant · No AI · Offline")
                                        .font(Theme.fontCaption)
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            .padding(Theme.Spacing.md)
                            .background(Theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                                    .strokeBorder(Theme.accent.opacity(0.25), lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, Theme.Spacing.md)
                        .accessibilityLabel("Generate a workout instantly, offline")

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

    /// Entry point used by every "start workout" path. Either prompts the user about
    /// warming up first, presents the warmup, or runs the start action directly,
    /// depending on the user's saved preference.
    private func requestStart(stretches: [Stretch], exercises: [Exercise] = [], action: @escaping () -> Void) {
        pendingStart = action
        pendingStretches = stretches
        pendingExercises = exercises

        switch warmupOptIn {
        case "yes":
            // User opted into warmups — present the warmup sheet.
            // Defer slightly so any presenting sheet has time to dismiss.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                showWarmup = true
            }
        case "no":
            // User opted out — start immediately.
            runPendingStartImmediately()
        default:
            // First time (or user reset via long-press) — ask.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                showWarmupPrompt = true
            }
        }
    }

    /// Run the captured pending start action and clear it.
    private func runPendingStartImmediately() {
        let action = pendingStart
        pendingStart = nil
        pendingStretches = []
        pendingExercises = []
        // Slight delay so any prompt/sheet dismissal lands cleanly before the workout cover.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            action?()
        }
    }
}
