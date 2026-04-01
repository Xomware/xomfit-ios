import SwiftUI

struct WorkoutBuilderView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = WorkoutBuilderViewModel()
    @State private var showExercisePicker = false

    var template: WorkoutTemplate? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.paddingMedium) {
                        nameField
                        categoryPicker
                        exerciseList
                        addExerciseButton
                    }
                    .padding(.horizontal, Theme.paddingMedium)
                    .padding(.vertical, Theme.paddingSmall)
                }
            }
            .navigationTitle("Build Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.accent)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.save()
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(viewModel.isValid ? Theme.accent : Theme.textSecondary)
                    .disabled(!viewModel.isValid)
                }
            }
        }
        .onAppear {
            if let template {
                viewModel.loadTemplate(template)
            }
        }
        .interactiveDismissDisabled(!viewModel.exercises.isEmpty)
        .sheet(isPresented: $showExercisePicker) {
            ExercisePickerView { exercise in
                viewModel.addExercise(exercise)
            }
        }
    }

    // MARK: - Name Field

    private var nameField: some View {
        TextField("Workout Name", text: $viewModel.name)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Theme.textPrimary)
            .padding(Theme.paddingMedium)
            .background(Theme.cardBackground)
            .cornerRadius(Theme.cornerRadius)
    }

    // MARK: - Category Picker

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.paddingSmall) {
                ForEach(WorkoutTemplate.TemplateCategory.allCases, id: \.self) { cat in
                    Button {
                        viewModel.category = cat
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: cat.icon)
                                .font(.system(size: 11))
                            Text(cat.displayName)
                                .font(Theme.fontSmall)
                        }
                        .foregroundStyle(viewModel.category == cat ? .black : Theme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(viewModel.category == cat ? Theme.accent : Theme.cardBackground)
                        .cornerRadius(20)
                    }
                    .accessibilityLabel("\(cat.displayName) category")
                    .accessibilityAddTraits(viewModel.category == cat ? .isSelected : [])
                }
            }
        }
    }

    // MARK: - Exercise List

    private var exerciseList: some View {
        Group {
            if viewModel.exercises.isEmpty {
                emptyState
            } else {
                VStack(spacing: Theme.paddingSmall) {
                    ForEach(Array(viewModel.exercises.enumerated()), id: \.element.id) { index, exercise in
                        BuilderExerciseRow(
                            exercise: exercise,
                            onUpdateSets: { viewModel.updateSets(at: index, sets: $0) },
                            onUpdateReps: { viewModel.updateReps(at: index, reps: $0) },
                            onDelete: { viewModel.removeExercise(at: index) }
                        )
                    }
                }

                if viewModel.exercises.count > 1 {
                    Text("~\(viewModel.estimatedDuration) min estimated")
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.paddingSmall) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 32))
                .foregroundStyle(Theme.textSecondary.opacity(0.5))
            Text("No exercises yet")
                .font(Theme.fontBody)
                .foregroundStyle(Theme.textSecondary)
            Text("Add exercises to build your workout")
                .font(Theme.fontCaption)
                .foregroundStyle(Theme.textSecondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.paddingLarge * 2)
    }

    // MARK: - Add Exercise Button

    private var addExerciseButton: some View {
        Button {
            showExercisePicker = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                Text("Add Exercise")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(Theme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.accent.opacity(0.1))
            .cornerRadius(Theme.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .strokeBorder(Theme.accent.opacity(0.3), lineWidth: 1)
            )
        }
        .accessibilityLabel("Add exercise to workout")
    }
}

// MARK: - Exercise Row

private struct BuilderExerciseRow: View {
    let exercise: WorkoutTemplate.TemplateExercise
    let onUpdateSets: (Int) -> Void
    let onUpdateReps: (String) -> Void
    let onDelete: () -> Void

    @State private var repsText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.paddingSmall) {
            // Header: name + delete
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(exercise.exercise.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)

                    HStack(spacing: 4) {
                        ForEach(exercise.exercise.muscleGroups.prefix(3), id: \.self) { mg in
                            Text(mg.displayName)
                                .font(Theme.fontSmall)
                                .foregroundStyle(Theme.textSecondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.secondaryBackground)
                                .cornerRadius(4)
                        }
                    }
                }

                Spacer()

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.destructive.opacity(0.8))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Remove \(exercise.exercise.name)")
            }

            // Sets & Reps controls
            HStack(spacing: Theme.paddingMedium) {
                // Sets stepper
                HStack(spacing: 8) {
                    Text("Sets")
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)

                    Button {
                        onUpdateSets(exercise.targetSets - 1)
                    } label: {
                        Image(systemName: "minus.circle")
                            .foregroundStyle(exercise.targetSets > 1 ? Theme.accent : Theme.textSecondary.opacity(0.3))
                    }
                    .disabled(exercise.targetSets <= 1)
                    .frame(minWidth: 44, minHeight: 44)

                    Text("\(exercise.targetSets)")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(minWidth: 24)

                    Button {
                        onUpdateSets(exercise.targetSets + 1)
                    } label: {
                        Image(systemName: "plus.circle")
                            .foregroundStyle(Theme.accent)
                    }
                    .frame(minWidth: 44, minHeight: 44)
                }

                Spacer()

                // Reps field
                HStack(spacing: 8) {
                    Text("Reps")
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)

                    TextField("8-12", text: $repsText)
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.center)
                        .frame(width: 60)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Theme.secondaryBackground)
                        .cornerRadius(Theme.cornerRadiusSmall)
                        .onAppear { repsText = exercise.targetReps }
                        .onChange(of: repsText) { _, newValue in
                            onUpdateReps(newValue)
                        }
                }
            }
        }
        .padding(Theme.paddingMedium)
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
    }
}
