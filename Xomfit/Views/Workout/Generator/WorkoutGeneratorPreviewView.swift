import SwiftUI

/// Preview of a generated workout: exercise rows with per-row reroll, plus a
/// Start Now / Save footer. No chat, no spinner, no "thinking" state — the
/// generator is instant and offline, and the header reinforces that.
///
/// Binds to `WorkoutGeneratorViewModel` only. Start Now hands the finished
/// `WorkoutTemplate` back to the host (which routes it through the warmup gate);
/// Save goes through the view model's `saveTemplate()`.
struct WorkoutGeneratorPreviewView: View {
    @Bindable var viewModel: WorkoutGeneratorViewModel
    let userId: String
    let onStart: (WorkoutTemplate) -> Void
    let onSaved: () -> Void

    @State private var savedConfirmation = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if let template = viewModel.previewTemplate, !template.exercises.isEmpty {
                content(template)
            } else {
                emptyState
            }
        }
        .navigationTitle("Your Workout")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Content

    private func content(_ template: WorkoutTemplate) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    summaryHeader(template)

                    ForEach(Array(template.exercises.enumerated()), id: \.element.id) { index, exercise in
                        row(exercise, index: index)
                    }
                }
                .padding(Theme.Spacing.md)
                .padding(.bottom, 120)
            }

            footer(template)
        }
    }

    private func summaryHeader(_ template: WorkoutTemplate) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(Theme.accent)
                Text("Generated instantly · offline")
                    .font(Theme.fontCaption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
            Text(template.description)
                .font(Theme.fontFootnote)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ exercise: WorkoutTemplate.TemplateExercise, index: Int) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: exercise.exercise.category == .compound ? "flame.fill" : "circle.fill")
                .font(.caption2)
                .foregroundStyle(exercise.exercise.category == .compound ? Theme.accent : Theme.textSecondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.exercise.name)
                    .font(Theme.fontBodyEmphasized)
                    .foregroundStyle(Theme.textPrimary)
                Text("\(exercise.targetSets) × \(exercise.targetReps)  ·  \(muscleTag(exercise.exercise))")
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            Button {
                Haptics.light()
                viewModel.rerollSlot(index, userId: userId)
            } label: {
                Image(systemName: "dice")
                    .font(.body)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reroll \(exercise.exercise.name)")
        }
        .padding(Theme.Spacing.md)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }

    private func footer(_ template: WorkoutTemplate) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            XomButton("Start Now", variant: .primary, icon: "play.fill") {
                Haptics.success()
                onStart(template)
            }
            XomButton(savedConfirmation ? "Saved" : "Save as Template", variant: .secondary, icon: savedConfirmation ? "checkmark" : "bookmark") {
                Haptics.medium()
                viewModel.saveTemplate()
                savedConfirmation = true
                onSaved()
            }
            .disabled(savedConfirmation)
        }
        .padding(Theme.Spacing.md)
        .background(.ultraThinMaterial)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "questionmark.square.dashed")
                .font(.system(size: 44))
                .foregroundStyle(Theme.textSecondary)
            Text("No exercises matched")
                .font(Theme.fontHeadline)
                .foregroundStyle(Theme.textPrimary)
            Text("Try selecting more muscle groups.")
                .font(Theme.fontFootnote)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(Theme.Spacing.xl)
    }

    private func muscleTag(_ exercise: Exercise) -> String {
        exercise.muscleGroups.first?.displayName ?? "—"
    }
}
