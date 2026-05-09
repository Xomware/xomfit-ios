import SwiftUI

struct WorkoutView: View {
    @Environment(AuthService.self) private var authService
    @Environment(WorkoutLoggerViewModel.self) private var workoutSession

    @State private var viewModel = WorkoutTabViewModel()

    @State private var showNameEntry = false
    @State private var pendingWorkoutName = ""
    @State private var showBuilder = false
    @State private var previewTemplate: WorkoutTemplate?
    @State private var friendWorkoutDetail: Workout?

    private var hasStartedFirstWorkout: Bool {
        UserDefaults.standard.bool(forKey: "xomfit_first_workout_started")
    }

    private var userId: String {
        authService.currentUser?.id.uuidString.lowercased() ?? ""
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        return NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.sm) {
                        // Top-level CTAs — preserved per #257 coordination
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

                        Button {
                            Haptics.light()
                            showBuilder = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "hammer.fill")
                                Text("Build Workout")
                            }
                        }
                        .buttonStyle(GhostButtonStyle())
                        .padding(.horizontal, Theme.Spacing.md)

                        // First-workout onboarding card — preserved
                        if viewModel.recent.isEmpty && !hasStartedFirstWorkout {
                            firstWorkoutCard
                        }

                        // Filter bar — applies to whichever tab is active
                        WorkoutFilterBar(filter: $viewModel.filter)

                        // Tab segmented control
                        Picker("Workout Tab", selection: $viewModel.selectedTab) {
                            ForEach(WorkoutTab.allCases) { tab in
                                Text(tab.displayName).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, Theme.Spacing.md)
                        .accessibilityLabel("Workout tab")

                        // Tab content
                        tabContent
                            .padding(.bottom, Theme.Spacing.xl)
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
        .sheet(item: $friendWorkoutDetail) { workout in
            NavigationStack {
                WorkoutDetailView(workout: workout)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { friendWorkoutDetail = nil }
                                .foregroundStyle(Theme.accent)
                        }
                    }
            }
        }
        .alert("Name Your Workout", isPresented: $showNameEntry) {
            TextField("e.g. Push Day", text: $pendingWorkoutName)
            Button("Start") {
                let name = pendingWorkoutName.isEmpty ? "Workout" : pendingWorkoutName
                workoutSession.startWorkout(name: name, userId: userId)
                workoutSession.isPresented = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showBuilder, onDismiss: {
            Task { await viewModel.load(userId: userId) }
        }) {
            WorkoutBuilderView()
        }
        .sheet(item: $previewTemplate) { template in
            TemplateDetailView(template: template) {
                previewTemplate = nil
                workoutSession.startFromTemplate(template, userId: userId)
                workoutSession.isPresented = true
            }
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.selectedTab {
        case .mine:      mineTab
        case .recent:    recentTab
        case .templates: templatesTab
        case .friends:   friendsTab
        }
    }

    // MARK: - Mine Tab

    private var mineTab: some View {
        Group {
            if viewModel.myTemplates.isEmpty {
                XomEmptyState(
                    icon: "star.fill",
                    title: "No Custom Workouts Yet",
                    subtitle: "Build a workout to save it here for quick access.",
                    ctaLabel: "Build Workout",
                    ctaAction: { showBuilder = true }
                )
            } else if viewModel.isEmptyAfterFilter(for: .mine) {
                noMatchesState
            } else {
                LazyVStack(spacing: Theme.Spacing.sm) {
                    ForEach(Array(viewModel.filteredTemplatesMine.enumerated()), id: \.element.id) { index, template in
                        TemplateCardView(template: template, style: .row) {
                            previewTemplate = template
                        }
                        .staggeredAppear(index: index)
                        .contextMenu {
                            Button(role: .destructive) {
                                deleteTemplate(template)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
            }
        }
    }

    // MARK: - Recent Tab

    private var recentTab: some View {
        Group {
            if viewModel.recent.isEmpty {
                XomEmptyState(
                    icon: "clock.arrow.circlepath",
                    title: "No Recent Workouts",
                    subtitle: "Complete your first workout to see it here.",
                    ctaLabel: "Start Workout",
                    ctaAction: {
                        pendingWorkoutName = ""
                        showNameEntry = true
                    }
                )
            } else if viewModel.isEmptyAfterFilter(for: .recent) {
                noMatchesState
            } else {
                LazyVStack(spacing: Theme.Spacing.sm) {
                    ForEach(Array(viewModel.filteredRecent.enumerated()), id: \.element.id) { index, workout in
                        RecentWorkoutCard(workout: workout, style: .row) {
                            previewTemplate = templateFromWorkout(workout)
                        }
                        .staggeredAppear(index: index)
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
            }
        }
    }

    // MARK: - Templates Tab

    private var templatesTab: some View {
        Group {
            if viewModel.builtInTemplates.isEmpty && viewModel.savedTemplates.isEmpty {
                XomEmptyState(
                    icon: "list.bullet.rectangle.portrait",
                    title: "No Templates",
                    subtitle: "Templates will appear once they load."
                )
            } else if viewModel.isEmptyAfterFilter(for: .templates) {
                noMatchesState
            } else {
                LazyVStack(spacing: Theme.Spacing.sm) {
                    ForEach(Array(viewModel.filteredTemplatesBuiltIn.enumerated()), id: \.element.id) { index, template in
                        TemplateCardView(template: template, style: .row) {
                            previewTemplate = template
                        }
                        .staggeredAppear(index: index)
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
            }
        }
    }

    // MARK: - Friends Tab

    private var friendsTab: some View {
        Group {
            if viewModel.isLoadingFriends && viewModel.friendWorkouts.isEmpty {
                VStack(spacing: Theme.Spacing.md) {
                    XomFitLoaderPulse()
                    Text("Loading friends' workouts...")
                        .font(Theme.fontSmall)
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(Theme.Spacing.xl)
            } else if viewModel.friendWorkouts.isEmpty {
                XomEmptyState(
                    icon: "person.2.fill",
                    title: "No Friend Activity",
                    subtitle: "Add friends to see their recent workouts here.",
                    ctaLabel: nil,
                    ctaAction: nil
                )
            } else if viewModel.isEmptyAfterFilter(for: .friends) {
                noMatchesState
            } else {
                LazyVStack(spacing: Theme.Spacing.sm) {
                    ForEach(Array(viewModel.filteredFriendWorkouts.enumerated()), id: \.element.id) { index, workout in
                        RecentWorkoutCard(workout: workout, style: .row) {
                            friendWorkoutDetail = workout
                        }
                        .staggeredAppear(index: index)
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
            }
        }
    }

    // MARK: - Shared Empty States

    private var noMatchesState: some View {
        XomEmptyState(
            icon: "line.3.horizontal.decrease.circle",
            title: "No Matches",
            subtitle: "Try clearing the filter to see more results.",
            ctaLabel: "Clear Filter",
            ctaAction: {
                viewModel.filter = WorkoutFilter()
            }
        )
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
                    workoutSession.startFromTemplate(template, userId: userId)
                    workoutSession.isPresented = true
                }
            } label: {
                HStack(spacing: 8) {
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

    // MARK: - Helpers

    private func deleteTemplate(_ template: WorkoutTemplate) {
        guard template.isCustom else { return }
        Haptics.medium()
        TemplateService.shared.deleteCustomTemplate(id: template.id)
        Task { await viewModel.load(userId: userId) }
    }

    private func templateFromWorkout(_ workout: Workout) -> WorkoutTemplate {
        let exercises = workout.exercises.map { ex in
            WorkoutTemplate.TemplateExercise(
                id: UUID().uuidString,
                exercise: ex.exercise,
                targetSets: ex.sets.count,
                targetReps: ex.bestSet.map { "\($0.reps)" } ?? "8",
                notes: ex.notes
            )
        }
        return WorkoutTemplate(
            id: "recent-\(workout.id)",
            name: workout.name,
            description: "From \(workout.startTime.workoutDateString)",
            exercises: exercises,
            estimatedDuration: Int(workout.duration / 60),
            category: .custom,
            isCustom: false
        )
    }
}
