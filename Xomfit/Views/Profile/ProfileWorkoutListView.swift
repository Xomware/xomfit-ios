import SwiftUI

struct ProfileWorkoutListView: View {
    var workouts: [Workout]
    var allWorkouts: [Workout]
    var isFiltered: Bool
    @Binding var dateRange: FeedDateRange
    @Binding var muscleGroups: Set<MuscleGroup>
    /// Pull-to-refresh hook owned by the parent (e.g. `ProfileView` -> `loadAll`).
    /// Optional so callers that haven't migrated yet still compile cleanly.
    var onRefresh: (() async -> Void)? = nil
    /// Swipe-to-delete callback for past-workout rows. Optional — only the
    /// current user's own profile should pass this.
    var onDelete: ((Workout) -> Void)? = nil

    /// Drives the workout-history search sheet (#323).
    @State private var showSearch = false

    var body: some View {
        VStack(spacing: 0) {
            if !allWorkouts.isEmpty {
                FeedFilterBar(
                    selectedDateRange: $dateRange,
                    selectedMuscleGroups: $muscleGroups
                )
            }

            if allWorkouts.isEmpty {
                emptyState
            } else if isFiltered && workouts.isEmpty {
                VStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(Theme.fontLargeTitle)
                        .foregroundStyle(Theme.textSecondary)
                    Text("No matching workouts")
                        .font(Theme.fontBody)
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                workoutList
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Haptics.light()
                    showSearch = true
                } label: {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Theme.textPrimary)
                }
                .accessibilityLabel("Search workout history")
                .disabled(allWorkouts.isEmpty)
            }
        }
        .sheet(isPresented: $showSearch) {
            WorkoutHistorySearchView(workouts: allWorkouts)
        }
    }

    // MARK: - Workout List

    /// List-backed rendering so `.swipeActions(edge: .trailing)` works on each
    /// past-workout row. Owners that don't pass `onDelete` simply won't get the
    /// swipe affordance.
    private var workoutList: some View {
        List {
            ForEach(workouts) { workout in
                NavigationLink {
                    // #365 — surface the same pull-to-refresh closure as
                    // `onUpdated` so saving an edit re-fetches the list.
                    WorkoutDetailView(workout: workout, onUpdated: onRefresh)
                } label: {
                    workoutCard(workout)
                }
                .listRowBackground(Theme.background)
                .listRowInsets(EdgeInsets(top: Theme.Spacing.tight, leading: Theme.Spacing.md, bottom: Theme.Spacing.tight, trailing: Theme.Spacing.md))
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if let onDelete {
                        Button(role: .destructive) {
                            Haptics.medium()
                            onDelete(workout)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .simultaneousGesture(TapGesture().onEnded { Haptics.light() })
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable {
            await onRefresh?()
        }
    }

    private func workoutCard(_ workout: Workout) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.tight) {
                    Text(workout.name)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(workout.startTime.workoutDateString)
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Text(workout.durationString)
                    .font(.caption.weight(.bold).monospaced())
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, Theme.Spacing.tight)
                    .background(Theme.accent.opacity(0.12))
                    .clipShape(.rect(cornerRadius: 6))
            }

            HStack(spacing: Theme.Spacing.md) {
                statLabel(value: "\(workout.exercises.count)", label: "exercises")
                statLabel(value: "\(workout.totalSets)", label: "sets")
                statLabel(value: workout.formattedVolume, label: "lbs")
                if workout.totalPRs > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "trophy.fill")
                            .font(Theme.fontCaption2)
                        Text("\(workout.totalPRs) PRs")
                            .font(Theme.fontCaption)
                    }
                    .foregroundStyle(Theme.prGold)
                }
            }

            if !workout.muscleGroups.isEmpty {
                HStack(spacing: Theme.Spacing.tight) {
                    ForEach(workout.muscleGroups.prefix(4), id: \.self) { mg in
                        Text(mg.displayName)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, Theme.Spacing.tighter)
                            .background(Theme.surfaceSecondary)
                            .clipShape(.rect(cornerRadius: 4))
                    }
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }

    private func statLabel(value: String, label: String) -> some View {
        HStack(spacing: 3) {
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(Theme.fontCaption)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(Theme.fontLargeTitle)
                .foregroundStyle(Theme.textSecondary)
            Text("No workouts yet")
                .font(Theme.fontBody)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
