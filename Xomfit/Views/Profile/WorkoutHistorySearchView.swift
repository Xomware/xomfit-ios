import SwiftUI

/// Sheet for searching and filtering a user's workout history (#323).
///
/// Reuses the shared `WorkoutFilter` model + `WorkoutFilterBar` from #249 so the
/// muscle / equipment chip pattern stays consistent with the rest of the app.
/// Results are filtered through `WorkoutFilter.matches(_:)` (which already
/// matches workout name *or* any exercise name) and sorted most-recent first.
struct WorkoutHistorySearchView: View {
    let workouts: [Workout]

    @Environment(\.dismiss) private var dismiss
    @State private var filter = WorkoutFilter()

    /// Most-recent-first source list. Computed once so re-filtering is cheap.
    private var sortedWorkouts: [Workout] {
        workouts.sorted { $0.startTime > $1.startTime }
    }

    private var results: [Workout] {
        sortedWorkouts.filter(filter.matches)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    WorkoutFilterBar(filter: $filter)

                    ScrollView {
                        LazyVStack(spacing: Theme.Spacing.sm) {
                            if results.isEmpty {
                                emptyState
                            } else {
                                ForEach(results) { workout in
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
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)
                    }
                }
            }
            .navigationTitle("Search History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        Haptics.light()
                        dismiss()
                    }
                    .foregroundStyle(Theme.accent)
                    .accessibilityLabel("Close search")
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(Theme.textTertiary)
            Text("No matching workouts. Try a broader filter.")
                .font(Theme.fontBody)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

#Preview {
    WorkoutHistorySearchView(workouts: [])
}
