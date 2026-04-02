import SwiftUI

struct TemplateDetailView: View {
    let template: WorkoutTemplate
    let onStart: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showEditor = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            headerSection
                            exerciseList
                        }
                        .padding(Theme.Spacing.md)
                        // Bottom padding for the start button
                        .padding(.bottom, 80)
                    }

                    startButton
                }
            }
            .navigationTitle(template.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Button {
                            shareTemplate()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.accent)
                        }
                        .accessibilityLabel("Share template")

                        if template.isCustom {
                            Button {
                                showEditor = true
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.accent)
                            }
                            .accessibilityLabel("Edit template")
                        }
                    }
                }
            }
            .sheet(isPresented: $showEditor) {
                WorkoutBuilderView(template: template)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: 10) {
                Image(systemName: template.category.icon)
                    .font(.title3)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 40, height: 40)
                    .background(Theme.accent.opacity(0.15))
                    .clipShape(.rect(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(template.category.displayName)
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.accent)
                    Text(template.description)
                        .font(Theme.fontBody)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            HStack(spacing: Theme.Spacing.lg) {
                statPill(icon: "dumbbell.fill", label: "Exercises", value: "\(template.exercises.count)")
                statPill(icon: "clock.fill", label: "Duration", value: "~\(template.estimatedDuration)m")
                statPill(icon: "arrow.up.arrow.down", label: "Total Sets", value: "\(totalSets)")
            }
            .padding(.top, Theme.Spacing.sm)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }

    private func shareTemplate() {
        let exercises = template.exercises.map { "\($0.exercise.name) — \($0.targetSets) x \($0.targetReps)" }.joined(separator: "\n")
        let text = """
        💪 \(template.name)
        \(template.description)

        \(exercises)

        \(template.exercises.count) exercises · ~\(template.estimatedDuration) min

        Shared from XomFit
        """
        let controller = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.keyWindow?.rootViewController {
            root.present(controller, animated: true)
        }
    }

    private var totalSets: Int {
        template.exercises.reduce(0) { $0 + $1.targetSets }
    }

    private func statPill(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(Theme.accent)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(Theme.fontSmall)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Exercise List

    private var exerciseList: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Exercises")
                .font(.body.weight(.bold))
                .foregroundStyle(Theme.textPrimary)

            ForEach(Array(template.exercises.enumerated()), id: \.element.id) { index, exercise in
                exerciseRow(index: index + 1, exercise: exercise)
            }
        }
    }

    private func exerciseRow(index: Int, exercise: WorkoutTemplate.TemplateExercise) -> some View {
        HStack(spacing: 12) {
            Text("\(index)")
                .font(.caption.weight(.bold).monospaced())
                .foregroundStyle(Theme.accent)
                .frame(width: 24, height: 24)
                .background(Theme.accent.opacity(0.15))
                .clipShape(.rect(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.exercise.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)

                HStack(spacing: 6) {
                    ForEach(exercise.exercise.muscleGroups.prefix(2), id: \.self) { mg in
                        Text(mg.displayName)
                            .font(Theme.fontSmall)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                if let notes = exercise.notes, !notes.isEmpty {
                    Text(notes)
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary.opacity(0.8))
                        .italic()
                }
            }

            Spacer()

            Text("\(exercise.targetSets) x \(exercise.targetReps)")
                .font(.subheadline.weight(.bold).monospaced())
                .foregroundStyle(Theme.accent)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(exercise.exercise.name), \(exercise.targetSets) sets of \(exercise.targetReps) reps")
    }

    // MARK: - Start Button

    private var startButton: some View {
        Button {
            dismiss()
            // Small delay so the sheet dismisses before the full-screen cover appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onStart()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                Text("Start Workout")
                    .font(.headline)
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.accent)
            .clipShape(.rect(cornerRadius: Theme.cornerRadius))
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.md)
        .background(Theme.background)
        .accessibilityLabel("Start \(template.name) workout")
    }
}
