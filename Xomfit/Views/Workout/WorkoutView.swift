import SwiftUI

struct WorkoutView: View {
    @Environment(AuthService.self) private var authService

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

                    ScrollView {
                        VStack(spacing: Theme.paddingSmall) {
                            // Quick Start templates
                            templateSection
                        }
                    }
                }
            }
            .navigationTitle("Workout")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .alert("Name Your Workout", isPresented: $showNameEntry) {
            TextField("e.g. Push Day", text: $pendingWorkoutName)
            Button("Start") { showActiveWorkout = true }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showActiveWorkout) {
            ActiveWorkoutView(
                workoutName: pendingWorkoutName.isEmpty ? "Workout" : pendingWorkoutName
            )
            .environment(authService)
        }
        .fullScreenCover(item: $selectedTemplate) { template in
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
                    ForEach(Array(TemplateService.shared.allTemplates().prefix(6).enumerated()), id: \.element.id) { index, template in
                        TemplateCardView(template: template) {
                            previewTemplate = template
                        }
                        .staggeredAppear(index: index)
                    }
                }
                .padding(.horizontal, Theme.paddingMedium)
                .id(templateRefreshId)
            }
        }
        .padding(.vertical, Theme.paddingSmall)
    }

}
