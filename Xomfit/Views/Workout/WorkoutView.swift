import SwiftUI

struct WorkoutView: View {
    @Environment(AuthService.self) private var authService
    @Environment(WorkoutLoggerViewModel.self) private var workoutSession

    @State private var showNameEntry = false
    @State private var pendingWorkoutName = ""
    @State private var showTemplateList = false
    @State private var showBuilder = false
    @State private var showLogPastWorkout = false
    @State private var previewTemplate: WorkoutTemplate?
    @State private var templateRefreshId = UUID()
    @State private var recentWorkouts: [Workout] = []
    private var hasStartedFirstWorkout: Bool {
        UserDefaults.standard.bool(forKey: "xomfit_first_workout_started")
    }
    @State private var myTemplates: [WorkoutTemplate] = []
    @State private var savedTemplates: [WorkoutTemplate] = []

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

                            // Build Workout + Log Past Workout (side-by-side)
                            HStack(spacing: Theme.Spacing.sm) {
                                Button {
                                    Haptics.light()
                                    showBuilder = true
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "hammer.fill")
                                        Text("Build")
                                    }
                                }
                                .buttonStyle(GhostButtonStyle())

                                Button {
                                    Haptics.light()
                                    showLogPastWorkout = true
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "calendar.badge.clock")
                                        Text("Log Past")
                                    }
                                }
                                .buttonStyle(GhostButtonStyle())
                                .accessibilityLabel("Log a past workout")
                            }
                            .padding(.horizontal, Theme.Spacing.md)

                            // First workout guide for new users
                            if recentWorkouts.isEmpty && !hasStartedFirstWorkout {
                                firstWorkoutCard
                            }

                            // Quick Start templates
                            templateSection

                            // Recent workouts
                            if !recentWorkouts.isEmpty {
                                recentSection
                            }

                            // My Workouts (custom templates)
                            if !myTemplates.isEmpty {
                                myWorkoutsSection
                            }

                            // Saved Workouts
                            if !savedTemplates.isEmpty {
                                savedSection
                            }
                        }
                    }
                }
            }
            .navigationTitle("Workout")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                await loadSections()
            }
            .onChange(of: workoutSession.isPresented) { _, isPresented in
                if !isPresented {
                    Task { await loadSections() }
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
            templateRefreshId = UUID()
            Task { await loadSections() }
        }) {
            WorkoutBuilderView()
        }
        .sheet(isPresented: $showLogPastWorkout, onDismiss: {
            Task { await loadSections() }
        }) {
            LogPastWorkoutView()
        }
        .sheet(item: $previewTemplate) { template in
            TemplateDetailView(template: template) {
                previewTemplate = nil
                workoutSession.startFromTemplate(template, userId: userId)
                workoutSession.isPresented = true
            }
        }
        .sheet(isPresented: $showTemplateList) {
            TemplateListView { template in
                // Dismiss the list first, then show preview after a brief delay
                showTemplateList = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    previewTemplate = template
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

    // MARK: - Templates

    private var templateSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("Quick Start")
                    .font(.body.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button {
                    showTemplateList = true
                } label: {
                    Text("See All")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(Array(TemplateService.shared.allTemplates().prefix(6).enumerated()), id: \.element.id) { index, template in
                        TemplateCardView(template: template) {
                            previewTemplate = template
                        }
                        .staggeredAppear(index: index)
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .id(templateRefreshId)
            }
        }
        .padding(.vertical, Theme.Spacing.sm)
    }

    // MARK: - Recent Workouts

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Recent")
                .font(.body.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, Theme.Spacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(Array(recentWorkouts.prefix(5).enumerated()), id: \.element.id) { index, workout in
                        TemplateCardView(template: templateFromWorkout(workout)) {
                            previewTemplate = templateFromWorkout(workout)
                        }
                        .staggeredAppear(index: index)
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
            }
        }
        .padding(.vertical, Theme.Spacing.sm)
    }

    // MARK: - My Workouts

    private var myWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("My Workouts")
                .font(.body.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, Theme.Spacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(Array(myTemplates.enumerated()), id: \.element.id) { index, template in
                        TemplateCardView(template: template) {
                            previewTemplate = template
                        }
                        .staggeredAppear(index: index)
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
            }
        }
        .padding(.vertical, Theme.Spacing.sm)
    }

    // MARK: - Saved Workouts

    private var savedSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Saved Workouts")
                .font(.body.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, Theme.Spacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(Array(savedTemplates.enumerated()), id: \.element.id) { index, template in
                        TemplateCardView(template: template) {
                            previewTemplate = template
                        }
                        .staggeredAppear(index: index)
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
            }
        }
        .padding(.vertical, Theme.Spacing.sm)
    }

    // MARK: - Data Loading

    private func loadSections() async {
        guard !userId.isEmpty else { return }
        recentWorkouts = await WorkoutService.shared.fetchWorkouts(userId: userId)
        let allCustom = TemplateService.shared.allTemplates().filter { $0.isCustom }
        myTemplates = allCustom.filter { $0.category != .saved }
        savedTemplates = allCustom.filter { $0.category == .saved }
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
