import SwiftUI

struct ProfileWorkoutListView: View {
    var workouts: [Workout]
    var allWorkouts: [Workout]
    var isFiltered: Bool
    @Binding var dateRange: FeedDateRange
    @Binding var muscleGroups: Set<MuscleGroup>

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
                        .font(.largeTitle)
                        .foregroundStyle(Theme.textSecondary)
                    Text("No matching workouts")
                        .font(Theme.fontBody)
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                LazyVStack(spacing: Theme.Spacing.sm) {
                    ForEach(workouts) { workout in
                        NavigationLink {
                            WorkoutDetailView(workout: workout)
                        } label: {
                            workoutCard(workout)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
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

    private func workoutCard(_ workout: Workout) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
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
                    .padding(.vertical, 4)
                    .background(Theme.accent.opacity(0.12))
                    .clipShape(.rect(cornerRadius: 6))
            }

            HStack(spacing: 16) {
                statLabel(value: "\(workout.exercises.count)", label: "exercises")
                statLabel(value: "\(workout.totalSets)", label: "sets")
                statLabel(value: workout.formattedVolume, label: "lbs")
                if workout.totalPRs > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "trophy.fill")
                            .font(.caption2)
                        Text("\(workout.totalPRs) PRs")
                            .font(Theme.fontCaption)
                    }
                    .foregroundStyle(Theme.prGold)
                }
            }

            if !workout.muscleGroups.isEmpty {
                HStack(spacing: 4) {
                    ForEach(workout.muscleGroups.prefix(4), id: \.self) { mg in
                        Text(mg.displayName)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
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
                .font(.largeTitle)
                .foregroundStyle(Theme.textSecondary)
            Text("No workouts yet")
                .font(Theme.fontBody)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
