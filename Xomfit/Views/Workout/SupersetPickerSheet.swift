import SwiftUI

/// Choose which exercise to superset with.
///
/// Grouping was "group with the next exercise" and nothing else. A superset is
/// a pairing the lifter picks — the exercise they want is often not whichever
/// one happens to be next, and reordering the whole workout to make it adjacent
/// is a poor way to say so.
struct SupersetPickerSheet: View {
    let viewModel: WorkoutLoggerViewModel
    let exerciseIndex: Int

    @Environment(\.dismiss) private var dismiss

    private var candidates: [Int] {
        viewModel.supersetCandidates(for: exerciseIndex)
    }

    private var sourceName: String {
        guard viewModel.exercises.indices.contains(exerciseIndex) else { return "" }
        return viewModel.exercises[exerciseIndex].exercise.name
    }

    var body: some View {
        NavigationStack {
            Group {
                if candidates.isEmpty {
                    ContentUnavailableView(
                        "Nothing to pair with",
                        systemImage: "link",
                        description: Text("Add another exercise to this workout first.")
                    )
                } else {
                    List(candidates, id: \.self) { index in
                        Button {
                            Haptics.success()
                            viewModel.groupSuperset(exerciseIndex: exerciseIndex, with: index)
                            dismiss()
                        } label: {
                            row(for: index)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Superset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func row(for index: Int) -> some View {
        let exercise = viewModel.exercises[index]
        let done = exercise.sets.filter { !$0.isPending }.count

        return HStack(spacing: Theme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.exercise.name)
                    .font(Theme.fontBody)
                    .foregroundStyle(Theme.textPrimary)
                Text("\(done)/\(exercise.sets.count) sets")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer(minLength: 0)

            // Says what pairing means here, since joining an exercise that is
            // already grouped adds to that group rather than starting a new one.
            if exercise.supersetGroupId != nil {
                Image(systemName: "link")
                    .font(.caption)
                    .foregroundStyle(Theme.accent)
                    .accessibilityLabel("Already in a superset")
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Supersets \(sourceName) with \(exercise.exercise.name).")
    }
}
