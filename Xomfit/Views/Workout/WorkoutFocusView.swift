import SwiftUI

/// Full-screen "gym mode" view showing one exercise and set at a time with large, tappable controls.
struct WorkoutFocusView: View {
    let viewModel: WorkoutLoggerViewModel
    @State private var isEditingWeight = false
    @State private var isEditingReps = false
    @State private var weightText = ""
    @State private var repsText = ""
    @FocusState private var weightFieldFocused: Bool
    @FocusState private var repsFieldFocused: Bool

    private var exercise: WorkoutExercise? { viewModel.focusExercise }
    private var currentSet: WorkoutSet? { viewModel.focusSet }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if let exercise, let currentSet {
                VStack(spacing: Theme.Spacing.lg) {
                    Spacer().frame(height: Theme.Spacing.sm)

                    exerciseHeader(exercise: exercise)

                    setIndicator(exercise: exercise)

                    weightDisplay(currentSet: currentSet)

                    repsDisplay(currentSet: currentSet)

                    doneButton(currentSet: currentSet)

                    exerciseNavigation

                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.lg)

                // Rest timer overlay
                if viewModel.isRestTimerActive {
                    restTimerOverlay
                }
            } else {
                emptyFocusState
            }
        }
    }

    // MARK: - Exercise Header

    private func exerciseHeader(exercise: WorkoutExercise) -> some View {
        VStack(spacing: 4) {
            Text(exercise.exercise.name)
                .font(.title2.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: 4) {
                ForEach(exercise.exercise.muscleGroups.prefix(2), id: \.self) { mg in
                    Text(mg.displayName)
                        .font(Theme.fontSmall)
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.accent.opacity(0.15))
                        .clipShape(.rect(cornerRadius: 4))
                }
            }
        }
    }

    // MARK: - Set Indicator

    private func setIndicator(exercise: WorkoutExercise) -> some View {
        Text("Set \(viewModel.focusSetIndex + 1) of \(exercise.sets.count)")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.textSecondary)
    }

    // MARK: - Weight Display

    private func weightDisplay(currentSet: WorkoutSet) -> some View {
        VStack(spacing: 4) {
            Text("WEIGHT")
                .font(Theme.fontSmall)
                .foregroundStyle(Theme.textSecondary)

            if isEditingWeight {
                TextField("0", text: $weightText)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .keyboardType(.decimalPad)
                    .focused($weightFieldFocused)
                    .onSubmit { commitWeight() }
                    .onChange(of: weightFieldFocused) { _, focused in
                        if !focused { commitWeight() }
                    }
                    .frame(maxWidth: 200)
            } else {
                Button {
                    weightText = currentSet.weight > 0 ? currentSet.weight.formattedWeight : ""
                    isEditingWeight = true
                    weightFieldFocused = true
                } label: {
                    Text(currentSet.weight.formattedWeight)
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.textPrimary)
                }
                .accessibilityLabel("Weight: \(currentSet.weight.formattedWeight) pounds. Tap to edit.")
            }

            // Per-side indicator
            if currentSet.weightMode == .perSide {
                Text("lbs x2 (per side)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            } else {
                Text("lbs")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.md)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }

    // MARK: - Reps Display

    private func repsDisplay(currentSet: WorkoutSet) -> some View {
        VStack(spacing: 4) {
            Text("REPS")
                .font(Theme.fontSmall)
                .foregroundStyle(Theme.textSecondary)

            if isEditingReps {
                TextField("0", text: $repsText)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .focused($repsFieldFocused)
                    .onSubmit { commitReps() }
                    .onChange(of: repsFieldFocused) { _, focused in
                        if !focused { commitReps() }
                    }
                    .frame(maxWidth: 200)
            } else {
                Button {
                    repsText = currentSet.reps > 0 ? "\(currentSet.reps)" : ""
                    isEditingReps = true
                    repsFieldFocused = true
                } label: {
                    Text("\(currentSet.reps)")
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.textPrimary)
                }
                .accessibilityLabel("Reps: \(currentSet.reps). Tap to edit.")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.md)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }

    // MARK: - Done Button

    private func doneButton(currentSet: WorkoutSet) -> some View {
        let isCompleted = currentSet.completedAt != Date.distantPast
        return Button {
            dismissKeyboard()
            if !isCompleted {
                viewModel.completeFocusedSet()
            }
        } label: {
            Text(isCompleted ? "COMPLETED" : "DONE")
                .font(.title3.weight(.black))
                .foregroundStyle(isCompleted ? Theme.textSecondary : .black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(isCompleted ? Theme.surface : Theme.accent)
                .clipShape(.rect(cornerRadius: Theme.cornerRadius))
        }
        .disabled(isCompleted)
        .accessibilityLabel(isCompleted ? "Set completed" : "Complete set")
    }

    // MARK: - Exercise Navigation

    private var exerciseNavigation: some View {
        HStack(spacing: Theme.Spacing.lg) {
            Button {
                dismissKeyboard()
                viewModel.focusPreviousExercise()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(viewModel.focusExerciseIndex > 0 ? Theme.textPrimary : Theme.textSecondary.opacity(0.3))
                    .frame(width: 56, height: 56)
                    .background(Theme.surface)
                    .clipShape(Circle())
            }
            .disabled(viewModel.focusExerciseIndex <= 0)
            .accessibilityLabel("Previous exercise")

            Text("\(viewModel.focusExerciseIndex + 1) / \(viewModel.exercises.count)")
                .font(.subheadline.weight(.semibold).monospaced())
                .foregroundStyle(Theme.textSecondary)

            Button {
                dismissKeyboard()
                viewModel.focusNextExercise()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(viewModel.focusExerciseIndex < viewModel.exercises.count - 1 ? Theme.textPrimary : Theme.textSecondary.opacity(0.3))
                    .frame(width: 56, height: 56)
                    .background(Theme.surface)
                    .clipShape(Circle())
            }
            .disabled(viewModel.focusExerciseIndex >= viewModel.exercises.count - 1)
            .accessibilityLabel("Next exercise")
        }
    }

    // MARK: - Rest Timer Overlay

    private var restTimerOverlay: some View {
        VStack {
            Spacer()
            RestTimerView(
                restTimeRemaining: viewModel.restTimeRemaining,
                restDuration: viewModel.restDuration,
                onSkip: { viewModel.skipRestTimer() },
                onExtend: { viewModel.extendRestTimer() }
            )
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.lg)
            .shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: -4)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Empty State

    private var emptyFocusState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "dumbbell")
                .font(.system(size: 48))
                .foregroundStyle(Theme.textSecondary)
            Text("No exercises yet")
                .font(Theme.fontHeadline)
                .foregroundStyle(Theme.textPrimary)
            Text("Add an exercise to use Focus Mode")
                .font(Theme.fontBody)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: - Helpers

    private func commitWeight() {
        isEditingWeight = false
        guard let value = Double(weightText) else { return }
        viewModel.updateSet(
            exerciseIndex: viewModel.focusExerciseIndex,
            setIndex: viewModel.focusSetIndex,
            weight: value,
            reps: viewModel.focusSet?.reps ?? 0
        )
    }

    private func commitReps() {
        isEditingReps = false
        guard let value = Int(repsText) else { return }
        viewModel.updateSet(
            exerciseIndex: viewModel.focusExerciseIndex,
            setIndex: viewModel.focusSetIndex,
            weight: viewModel.focusSet?.weight ?? 0,
            reps: value
        )
    }

    private func dismissKeyboard() {
        if isEditingWeight { commitWeight() }
        if isEditingReps { commitReps() }
        weightFieldFocused = false
        repsFieldFocused = false
    }
}
