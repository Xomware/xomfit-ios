import SwiftUI

struct WorkoutView: View {
    @Environment(AuthService.self) private var authService

    @State private var workouts: [Workout] = []
    @State private var showActiveWorkout = false
    @State private var showNameEntry = false
    @State private var pendingWorkoutName = ""
    @State private var selectedTemplate: WorkoutTemplate?
    @State private var showTemplateList = false

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
                                .font(.system(size: 17, weight: .bold))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.accent)
                        .cornerRadius(Theme.cornerRadius)
                    }
                    .padding(.horizontal, Theme.paddingMedium)
                    .padding(.top, Theme.paddingMedium)
                    .padding(.bottom, Theme.paddingSmall)

                    // Quick Start templates
                    templateSection

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
            selectedTemplate = nil
            Task { await loadWorkouts() }
        }) {
            ActiveWorkoutView(
                workoutName: selectedTemplate?.name ?? (pendingWorkoutName.isEmpty ? "Workout" : pendingWorkoutName),
                template: selectedTemplate
            )
            .environment(authService)
        }
        .sheet(isPresented: $showTemplateList) {
            TemplateListView { template in
                selectedTemplate = template
                showActiveWorkout = true
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
                            selectedTemplate = template
                            showActiveWorkout = true
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
