import SwiftUI

struct WorkoutView: View {
    @Environment(AuthService.self) private var authService
    @Environment(WorkoutLoggerViewModel.self) private var workoutSession

    @State private var showNameEntry = false
    @State private var pendingWorkoutName = ""
    @State private var showBuilder = false
    @State private var showLogPastWorkout = false
    @State private var previewTemplate: WorkoutTemplate?

    /// Shared data store for the Quick Hitter previews and the See-All pages.
    /// Owned here so the same loaded data backs both the previews and the
    /// dedicated category pages without re-fetching on push.
    @State private var viewModel = WorkoutTabViewModel()

    private var hasStartedFirstWorkout: Bool {
        UserDefaults.standard.bool(forKey: "xomfit_first_workout_started")
    }

    /// Number of items shown in each Quick Hitter preview before "See All".
    private let previewCount = 4

    // MARK: - Warmup flow (#261)

    /// Persisted preference: "" = ask each time, "yes" = always warm up, "no" = always skip.
    @AppStorage("warmupOptIn") private var warmupOptIn: String = ""
    /// Default warmup length in minutes — kept here so we can tweak via settings later.
    @AppStorage("warmupMinutes") private var warmupMinutes: Int = 6

    /// Captured action that runs after the warmup (or immediately if skipped).
    @State private var pendingStart: (() -> Void)?
    /// Stretches we'll show during the warmup, computed before presenting the sheet.
    @State private var pendingStretches: [Stretch] = []
    /// Whether to ask the user about warming up right now.
    @State private var showWarmupPrompt = false
    /// Whether to present the warmup sheet right now.
    @State private var showWarmup = false

    private var userId: String {
        authService.currentUser?.id.uuidString.lowercased() ?? ""
    }

    var body: some View {
        NavigationStack {
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

                            // Quick Hitter sections (vertical previews + See All)
                            recentsQuickHitters
                            preGeneratedQuickHitters
                            friendsAndSavedQuickHitters
                        }
                    }
                }
            }
            .navigationTitle("Workout")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                await viewModel.load(userId: userId)
            }
            .onChange(of: workoutSession.isPresented) { _, isPresented in
                if !isPresented {
                    Task { await viewModel.load(userId: userId) }
                }
            }
        }
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
                totalDuration: warmupMinutes * 60
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
        .sheet(item: $previewTemplate) { template in
            TemplateDetailView(template: template) {
                let captured = template
                previewTemplate = nil
                requestStart(stretches: StretchDatabase.suggestedStretches(for: captured, target: TimeInterval(warmupMinutes * 60))) {
                    workoutSession.startFromTemplate(captured, userId: userId)
                    workoutSession.isPresented = true
                }
            }
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
                Haptics.medium()
                UserDefaults.standard.set(true, forKey: "xomfit_first_workout_started")
                if let template = WorkoutTemplate.builtIn.first(where: { $0.id == "tpl-fb-a" }) {
                    requestStart(stretches: StretchDatabase.suggestedStretches(for: template, target: TimeInterval(warmupMinutes * 60))) {
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

    // MARK: - Quick Hitter Sections

    /// Header row used by each Quick Hitter section. Tappable "See All" pushes
    /// the dedicated category page.
    private func sectionHeader(for category: WorkoutCategory, showSeeAll: Bool) -> some View {
        HStack {
            Text(category.title)
                .font(.body.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            if showSeeAll {
                NavigationLink {
                    WorkoutCategoryPage(category: category, viewModel: viewModel)
                } label: {
                    HStack(spacing: Theme.Spacing.tight) {
                        Text("See All")
                            .font(.caption.weight(.semibold))
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(Theme.accent)
                }
                .accessibilityLabel("See all \(category.title.lowercased())")
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
    }

    @ViewBuilder
    private var recentsQuickHitters: some View {
        if !viewModel.recent.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                sectionHeader(for: .recents, showSeeAll: viewModel.recent.count > previewCount)

                VStack(spacing: Theme.Spacing.xs) {
                    ForEach(Array(viewModel.recent.prefix(previewCount))) { workout in
                        NavigationLink {
                            WorkoutDetailView(workout: workout)
                        } label: {
                            RecentWorkoutCard(workout: workout, style: .row)
                        }
                        .buttonStyle(PressableCardStyle())
                        .accessibilityLabel("\(workout.name), \(workout.startTime.timeAgo)")
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
            }
            .padding(.vertical, Theme.Spacing.sm)
        }
    }

    @ViewBuilder
    private var preGeneratedQuickHitters: some View {
        if !viewModel.builtInTemplates.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                sectionHeader(for: .preGenerated, showSeeAll: viewModel.builtInTemplates.count > previewCount)

                VStack(spacing: Theme.Spacing.xs) {
                    ForEach(Array(viewModel.builtInTemplates.prefix(previewCount))) { template in
                        TemplateCardView(template: template, style: .row) {
                            previewTemplate = template
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
            }
            .padding(.vertical, Theme.Spacing.sm)
        }
    }

    @ViewBuilder
    private var friendsAndSavedQuickHitters: some View {
        let combinedTemplates = viewModel.myTemplates + viewModel.savedTemplates
        let friendItems = viewModel.friendWorkouts
        let totalCount = combinedTemplates.count + friendItems.count

        if totalCount > 0 {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                sectionHeader(for: .friendsAndSaved, showSeeAll: totalCount > previewCount)

                VStack(spacing: Theme.Spacing.xs) {
                    // Templates first (own + saved), then friend workouts, capped at previewCount total.
                    let templatePreview = Array(combinedTemplates.prefix(previewCount))
                    let remainingSlots = max(0, previewCount - templatePreview.count)
                    let friendPreview = Array(friendItems.prefix(remainingSlots))

                    ForEach(templatePreview) { template in
                        TemplateCardView(template: template, style: .row) {
                            previewTemplate = template
                        }
                    }

                    ForEach(friendPreview) { workout in
                        NavigationLink {
                            WorkoutDetailView(workout: workout)
                        } label: {
                            RecentWorkoutCard(workout: workout, style: .row)
                        }
                        .buttonStyle(PressableCardStyle())
                        .accessibilityLabel("Friend workout: \(workout.name)")
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
            }
            .padding(.vertical, Theme.Spacing.sm)
        }
    }

    // MARK: - Warmup gating (#261)

    /// Entry point used by every "start workout" path. Either prompts the user about
    /// warming up first, presents the warmup, or runs the start action directly,
    /// depending on the user's saved preference.
    private func requestStart(stretches: [Stretch], action: @escaping () -> Void) {
        pendingStart = action
        pendingStretches = stretches

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
        // Slight delay so any prompt/sheet dismissal lands cleanly before the workout cover.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            action?()
        }
    }
}
