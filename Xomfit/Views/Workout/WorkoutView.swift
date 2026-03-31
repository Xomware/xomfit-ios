import SwiftUI

struct WorkoutView: View {
    @Environment(AuthService.self) private var authService

    @State private var workouts: [Workout] = []
    @State private var showActiveWorkout = false
    @State private var showNameEntry = false
    @State private var pendingWorkoutName = ""
    @State private var selectedTemplate: WorkoutTemplate?
    @State private var showTemplateList = false
    @State private var showBuilder = false
    @State private var previewTemplate: WorkoutTemplate?
    @State private var templateRefreshId = UUID()

    private var userId: String {
        authService.currentUser?.id.uuidString ?? ""
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Start Workout CTA
                    Button {
                        pendingWorkoutName = ""
                        showNameEntry = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "play.fill")
                            Text("Start Workout")
                        }
                    }
                    .buttonStyle(AccentButtonStyle())
                    .padding(.horizontal, Theme.paddingMedium)
                    .padding(.top, Theme.paddingMedium)
                    .padding(.bottom, Theme.paddingSmall)

                    // Build Workout
                    Button {
                        showBuilder = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "hammer.fill")
                            Text("Build Workout")
                        }
                    }
                    .buttonStyle(GhostButtonStyle())
                    .padding(.horizontal, Theme.paddingMedium)
                    .padding(.bottom, Theme.paddingSmall)

                    // Quick Start templates
                    templateSection

                    // Recent workouts
                    if !workouts.isEmpty {
                        recentSection
                    }

                    // Workout history
                    if workouts.isEmpty {
                        Spacer()
                        VStack(spacing: Theme.paddingMedium) {
                            Image("XomFitLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .opacity(0.6)
                            Text("No workouts yet")
                                .font(Theme.fontHeadline)
                                .foregroundColor(Theme.textPrimary)
                            Text("Start your first workout above")
                                .font(Theme.fontBody)
                                .foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                    } else {
                        List {
                            ForEach(workouts) { workout in
                                WorkoutHistoryCard(workout: workout)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 6, leading: Theme.paddingMedium, bottom: 6, trailing: Theme.paddingMedium))
                            }
                            .onDelete { indexSet in
                                let idsToDelete = indexSet.map { workouts[$0].id }
                                Task {
                                    for id in idsToDelete {
                                        await WorkoutService.shared.deleteWorkout(id: id)
                                    }
                                    await loadWorkouts()
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .refreshable { await loadWorkouts() }
                    }
                }
            }
            .navigationTitle("Workout")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .task { await loadWorkouts() }
        .alert("Name Your Workout", isPresented: $showNameEntry) {
            TextField("e.g. Push Day", text: $pendingWorkoutName)
            Button("Start") { showActiveWorkout = true }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showActiveWorkout, onDismiss: {
            Task { await loadWorkouts() }
        }) {
            ActiveWorkoutView(
                workoutName: pendingWorkoutName.isEmpty ? "Workout" : pendingWorkoutName
            )
            .environment(authService)
        }
        .fullScreenCover(item: $selectedTemplate, onDismiss: {
            Task { await loadWorkouts() }
        }) { template in
            ActiveWorkoutView(
                workoutName: template.name,
                template: template
            )
            .environment(authService)
        }
        .sheet(isPresented: $showBuilder, onDismiss: {
            templateRefreshId = UUID()
        }) {
            WorkoutBuilderView()
        }
        .sheet(item: $previewTemplate) { template in
            TemplateDetailView(template: template) {
                selectedTemplate = template
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

    // MARK: - Templates

    private var templateSection: some View {
        VStack(alignment: .leading, spacing: Theme.paddingSmall) {
            HStack {
                Text("Quick Start")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button {
                    showTemplateList = true
                } label: {
                    Text("See All")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
            }
            .padding(.horizontal, Theme.paddingMedium)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.paddingSmall) {
                    ForEach(TemplateService.shared.allTemplates().prefix(6)) { template in
                        TemplateCardView(template: template) {
                            previewTemplate = template
                        }
                    }
                }
                .padding(.horizontal, Theme.paddingMedium)
                .id(templateRefreshId)
            }
        }
        .padding(.vertical, Theme.paddingSmall)
    }

    // MARK: - Recent Workouts

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: Theme.paddingSmall) {
            Text("Recent")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, Theme.paddingMedium)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.paddingSmall) {
                    ForEach(workouts.prefix(5)) { workout in
                        RecentWorkoutCard(workout: workout) {
                            pendingWorkoutName = workout.name
                            // Build a template from the workout's exercises
                            let templateExercises = workout.exercises.map { ex in
                                WorkoutTemplate.TemplateExercise(
                                    id: UUID().uuidString,
                                    exercise: ex.exercise,
                                    targetSets: ex.sets.count,
                                    targetReps: ex.bestSet.map { "\($0.reps)" } ?? "0",
                                    notes: ex.notes
                                )
                            }
                            let replayTemplate = WorkoutTemplate(
                                id: UUID().uuidString,
                                name: workout.name,
                                description: "Repeat of \(workout.name)",
                                exercises: templateExercises,
                                estimatedDuration: Int(workout.duration / 60),
                                category: .custom,
                                isCustom: false
                            )
                            selectedTemplate = replayTemplate
                        }
                    }
                }
                .padding(.horizontal, Theme.paddingMedium)
            }
        }
        .padding(.vertical, Theme.paddingSmall)
    }

    private func loadWorkouts() async {
        workouts = await WorkoutService.shared.fetchWorkouts(userId: userId)
    }
}

// MARK: - History Card

private struct WorkoutHistoryCard: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.paddingSmall) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(workout.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    Text(workout.startTime.workoutDateString)
                        .font(Theme.fontCaption)
                        .foregroundColor(Theme.textSecondary)
                }
                Spacer()
                Text(workout.durationString)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(Theme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Theme.accent.opacity(0.12))
                    .cornerRadius(6)
            }

            HStack(spacing: Theme.paddingLarge) {
                statPill(label: "Exercises", value: "\(workout.exercises.count)")
                statPill(label: "Sets", value: "\(workout.totalSets)")
                statPill(label: "Volume", value: "\(workout.formattedVolume) lbs")
            }

            // Muscle groups
            if !workout.muscleGroups.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(workout.muscleGroups, id: \.self) { mg in
                            Text(mg.displayName)
                                .font(Theme.fontSmall)
                                .foregroundColor(Theme.textSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Theme.secondaryBackground)
                                .cornerRadius(4)
                        }
                    }
                }
            }
        }
        .padding(Theme.paddingMedium)
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
    }

    private func statPill(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Theme.textPrimary)
            Text(label)
                .font(Theme.fontSmall)
                .foregroundColor(Theme.textSecondary)
        }
    }
}

// MARK: - Recent Workout Card

private struct RecentWorkoutCard: View {
    let workout: Workout
    let onRepeat: () -> Void

    var body: some View {
        Button(action: onRepeat) {
            VStack(alignment: .leading, spacing: 6) {
                Text(workout.name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                Text(workout.startTime.workoutDateString)
                    .font(Theme.fontSmall)
                    .foregroundStyle(Theme.textSecondary)

                HStack(spacing: 6) {
                    Text("\(workout.exercises.count) ex")
                    Text(workout.durationString)
                        .foregroundStyle(Theme.accent)
                }
                .font(Theme.fontSmall)
                .foregroundStyle(Theme.textSecondary)

                HStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 10, weight: .bold))
                    Text("Repeat")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(Theme.accent)
                .padding(.top, 2)
            }
            .padding(12)
            .frame(width: 140, alignment: .leading)
            .background(Theme.cardBackground)
            .clipShape(.rect(cornerRadius: Theme.cornerRadius))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Repeat \(workout.name) workout from \(workout.startTime.workoutDateString)")
        .accessibilityAddTraits(.isButton)
    }
}
