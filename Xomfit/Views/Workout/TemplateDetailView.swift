import SwiftUI

struct TemplateDetailView: View {
    let template: WorkoutTemplate
    let onStart: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Theme.paddingMedium) {
                            headerSection
                            exerciseList
                        }
                        .padding(Theme.paddingMedium)
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
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Theme.paddingSmall) {
            HStack(spacing: 10) {
                Image(systemName: template.category.icon)
                    .font(.system(size: 22))
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

            HStack(spacing: Theme.paddingLarge) {
                statPill(icon: "dumbbell.fill", label: "Exercises", value: "\(template.exercises.count)")
                statPill(icon: "clock.fill", label: "Duration", value: "~\(template.estimatedDuration)m")
                statPill(icon: "arrow.up.arrow.down", label: "Total Sets", value: "\(totalSets)")
            }
            .padding(.top, Theme.paddingSmall)
        }
        .padding(Theme.paddingMedium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }

    private var totalSets: Int {
        template.exercises.reduce(0) { $0 + $1.targetSets }
    }

    private func statPill(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Theme.accent)
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(Theme.fontSmall)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Exercise List

    private var exerciseList: some View {
        VStack(alignment: .leading, spacing: Theme.paddingSmall) {
            Text("Exercises")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.textPrimary)

            ForEach(Array(template.exercises.enumerated()), id: \.element.id) { index, exercise in
                exerciseRow(index: index + 1, exercise: exercise)
            }
        }
    }

    private func exerciseRow(index: Int, exercise: WorkoutTemplate.TemplateExercise) -> some View {
        HStack(spacing: 12) {
            Text("\(index)")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.accent)
                .frame(width: 24, height: 24)
                .background(Theme.accent.opacity(0.15))
                .clipShape(.rect(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.exercise.name)
                    .font(.system(size: 15, weight: .semibold))
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
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.accent)
        }
        .padding(Theme.paddingMedium)
        .background(Theme.cardBackground)
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
                    .font(.system(size: 17, weight: .bold))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.accent)
            .clipShape(.rect(cornerRadius: Theme.cornerRadius))
        }
        .padding(.horizontal, Theme.paddingMedium)
        .padding(.bottom, Theme.paddingMedium)
        .background(Theme.background)
        .accessibilityLabel("Start \(template.name) workout")
    }
}
