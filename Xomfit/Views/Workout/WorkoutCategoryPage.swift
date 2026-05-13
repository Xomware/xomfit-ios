import SwiftUI

// MARK: - WorkoutCategory

/// The four category segments surfaced on the Workouts tab (#338).
///
/// Each case identifies a list shown under the segmented control on `WorkoutView`.
enum WorkoutCategory: String, CaseIterable, Identifiable, Hashable {
    /// The user's own recent past workouts.
    case recents
    /// The user's own custom templates (built with WorkoutBuilder, not saved-from-friend).
    case myWorkouts
    /// Templates the user saved from elsewhere, plus friends' recent workouts.
    case savedFriendsWorkouts
    /// Built-in templates shipped with the app.
    case preGen

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recents:              return "Recents"
        case .myWorkouts:           return "My Workouts"
        case .savedFriendsWorkouts: return "Saved & Friends"
        case .preGen:               return "Pre-Gen"
        }
    }

    var icon: String {
        switch self {
        case .recents:              return "clock.fill"
        case .myWorkouts:           return "star.fill"
        case .savedFriendsWorkouts: return "person.2.fill"
        case .preGen:               return "list.bullet.rectangle.portrait"
        }
    }

    /// Empty-state copy when the user has no items in this category at all (no filter applied).
    var emptyStateTitle: String {
        switch self {
        case .recents:              return "No recent workouts"
        case .myWorkouts:           return "No custom workouts yet"
        case .savedFriendsWorkouts: return "Nothing saved yet"
        case .preGen:               return "No templates available"
        }
    }

    var emptyStateMessage: String {
        switch self {
        case .recents:
            return "Finished workouts will show up here."
        case .myWorkouts:
            return "Build a workout to save it here for quick reuse."
        case .savedFriendsWorkouts:
            return "Save a template or follow friends to populate this list."
        case .preGen:
            return "Built-in templates will appear once loaded."
        }
    }
}

// MARK: - WorkoutCategoryListView

/// Reusable list body for a `WorkoutCategory` — filter bar + items + empty states.
///
/// Used inline on `WorkoutView` under the segmented control (#338). Receives the
/// shared `WorkoutTabViewModel` so the same loaded data backs every category
/// without re-fetching when the segment changes.
struct WorkoutCategoryListView: View {
    let category: WorkoutCategory

    /// Shared view model owned by `WorkoutView`. Local filter state is per-list
    /// so each category starts with a clean filter.
    let viewModel: WorkoutTabViewModel

    @Environment(AuthService.self) private var authService
    @Environment(WorkoutLoggerViewModel.self) private var workoutSession

    @State private var localFilter = WorkoutFilter()
    @State private var previewTemplate: WorkoutTemplate?

    /// Default warmup length in minutes (matches WorkoutView's setting).
    @AppStorage("warmupMinutes") private var warmupMinutes: Int = 6
    @AppStorage("warmupOptIn") private var warmupOptIn: String = ""

    @State private var pendingStart: (() -> Void)?
    @State private var pendingStretches: [Stretch] = []
    /// Exercises captured at start-flow time so the warmup preview can render
    /// "why this stretch" captions (#349).
    @State private var pendingExercises: [Exercise] = []
    @State private var showWarmupPrompt = false
    @State private var showWarmup = false

    private var userId: String {
        authService.currentUser?.id.uuidString.lowercased() ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            WorkoutFilterBar(filter: $localFilter)

            LazyVStack(spacing: Theme.Spacing.sm) {
                contentView
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
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
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        switch category {
        case .recents:
            recentsContent
        case .myWorkouts:
            myWorkoutsContent
        case .savedFriendsWorkouts:
            savedFriendsContent
        case .preGen:
            preGeneratedContent
        }
    }

    @ViewBuilder
    private var recentsContent: some View {
        let items = viewModel.recent.filter(localFilter.matches)
        if viewModel.recent.isEmpty {
            emptyState
        } else if items.isEmpty {
            filteredEmptyState
        } else {
            ForEach(items) { workout in
                NavigationLink {
                    WorkoutDetailView(workout: workout)
                } label: {
                    RecentWorkoutCard(workout: workout, style: .row)
                }
                .buttonStyle(PressableCardStyle())
                .accessibilityLabel("\(workout.name), \(workout.startTime.timeAgo)")
            }
        }
    }

    @ViewBuilder
    private var myWorkoutsContent: some View {
        let items = viewModel.myTemplates.filter(localFilter.matches)
        if viewModel.myTemplates.isEmpty {
            emptyState
        } else if items.isEmpty {
            filteredEmptyState
        } else {
            ForEach(items) { template in
                TemplateCardView(template: template, style: .row) {
                    previewTemplate = template
                }
            }
        }
    }

    @ViewBuilder
    private var savedFriendsContent: some View {
        let templates = viewModel.savedTemplates.filter(localFilter.matches)
        let workouts = viewModel.friendWorkouts.filter(localFilter.matches)
        let hasAnySource = !viewModel.savedTemplates.isEmpty || !viewModel.friendWorkouts.isEmpty
        let hasAnyMatch = !templates.isEmpty || !workouts.isEmpty

        if !hasAnySource {
            emptyState
        } else if !hasAnyMatch {
            filteredEmptyState
        } else {
            if !templates.isEmpty {
                sectionLabel("Saved Templates")
                ForEach(templates) { template in
                    TemplateCardView(template: template, style: .row) {
                        previewTemplate = template
                    }
                }
            }

            if !workouts.isEmpty {
                sectionLabel("From Friends")
                ForEach(workouts) { workout in
                    NavigationLink {
                        WorkoutDetailView(workout: workout)
                    } label: {
                        RecentWorkoutCard(workout: workout, style: .row)
                    }
                    .buttonStyle(PressableCardStyle())
                    .accessibilityLabel("Friend workout: \(workout.name)")
                }
            }
        }
    }

    @ViewBuilder
    private var preGeneratedContent: some View {
        let items = viewModel.builtInTemplates.filter(localFilter.matches)
        if viewModel.builtInTemplates.isEmpty {
            emptyState
        } else if items.isEmpty {
            filteredEmptyState
        } else {
            ForEach(items) { template in
                TemplateCardView(template: template, style: .row) {
                    previewTemplate = template
                }
            }
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.top, Theme.Spacing.sm)
    }

    // MARK: - Empty States

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: category.icon)
                .font(Theme.fontLargeTitle)
                .foregroundStyle(Theme.textTertiary)
            Text(category.emptyStateTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            Text(category.emptyStateMessage)
                .font(Theme.fontCaption)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var filteredEmptyState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "line.3.horizontal.decrease")
                .font(Theme.fontLargeTitle)
                .foregroundStyle(Theme.textTertiary)
            Text("No matches")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("Try clearing a filter or search term.")
                .font(Theme.fontCaption)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Warmup gating (mirrors WorkoutView for template starts)

    private func requestStart(stretches: [Stretch], exercises: [Exercise] = [], action: @escaping () -> Void) {
        pendingStart = action
        pendingStretches = stretches
        pendingExercises = exercises

        switch warmupOptIn {
        case "yes":
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                showWarmup = true
            }
        case "no":
            runPendingStartImmediately()
        default:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                showWarmupPrompt = true
            }
        }
    }

    private func runPendingStartImmediately() {
        let action = pendingStart
        pendingStart = nil
        pendingStretches = []
        pendingExercises = []
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            action?()
        }
    }
}
