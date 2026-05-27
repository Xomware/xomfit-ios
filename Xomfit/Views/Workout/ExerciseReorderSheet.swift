import SwiftUI

struct ExerciseReorderSheet: View {
    let viewModel: WorkoutLoggerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(viewModel.exercises.enumerated()), id: \.element.id) { idx, exercise in
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "line.3.horizontal")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.textTertiary)

                        VStack(alignment: .leading, spacing: Theme.Spacing.tighter) {
                            Text(exercise.exercise.name)
                                .font(.body.weight(.medium))
                                .foregroundStyle(Theme.textPrimary)

                            let completed = exercise.sets.filter { $0.completedAt != Date.distantPast }.count
                            Text("\(completed)/\(exercise.sets.count) sets")
                                .font(Theme.fontCaption)
                                .foregroundStyle(Theme.textSecondary)
                        }

                        Spacer()

                        if let groups = exercise.exercise.muscleGroups.first {
                            Text(groups.displayName)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Theme.accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, Theme.Spacing.tighter)
                                .background(Theme.accent.opacity(0.15))
                                .clipShape(.rect(cornerRadius: 4))
                        }
                    }
                    .listRowBackground(Theme.surface)
                }
                .onMove { source, destination in
                    viewModel.moveExercises(from: source, to: destination)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Reorder Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
