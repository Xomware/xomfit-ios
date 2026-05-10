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
    @State private var showExercisePicker = false
    @State private var isRestTimerMinimized = false
    @AppStorage("restTimerSound") private var restTimerSound = false

    private var exercise: WorkoutExercise? { viewModel.focusExercise }
    private var currentSet: WorkoutSet? { viewModel.focusSet }

    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
                .onTapGesture { dismissKeyboard() }

            if let exercise, let currentSet {
                VStack(spacing: Theme.Spacing.lg) {
                    Spacer().frame(height: Theme.Spacing.sm)

                    // Exercise content — animated slide on exercise change
                    VStack(spacing: Theme.Spacing.lg) {
                        exerciseHeader(exercise: exercise)

                        // Variant config (grip, attachment, position, laterality) — shown when available
                        if exercise.exercise.supportedGrips != nil ||
                           exercise.exercise.supportedAttachments != nil ||
                           exercise.exercise.supportedPositions != nil ||
                           exercise.exercise.supportsUnilateral {
                            ExerciseConfigRow(
                                exercise: exercise,
                                onGripChanged: { grip in viewModel.setGrip(exerciseIndex: viewModel.focusExerciseIndex, grip: grip) },
                                onAttachmentChanged: { att in viewModel.setAttachment(exerciseIndex: viewModel.focusExerciseIndex, attachment: att) },
                                onPositionChanged: { pos in viewModel.setPosition(exerciseIndex: viewModel.focusExerciseIndex, position: pos) },
                                onLateralityChanged: { lat in viewModel.setLaterality(exerciseIndex: viewModel.focusExerciseIndex, laterality: lat) }
                            )
                        }

                        setIndicator(exercise: exercise)

                        weightDisplay(currentSet: currentSet)

                        repsDisplay(currentSet: currentSet)

                        doneButton(currentSet: currentSet)
                    }
                    .id(viewModel.focusExerciseIndex)
                    .transition(.push(from: .trailing))
                    .animation(.easeInOut(duration: 0.3), value: viewModel.focusExerciseIndex)

                    exerciseNavigation

                    Spacer().frame(height: viewModel.isRestTimerActive && isRestTimerMinimized ? 100 : 0)
                }
                .safeAreaPadding(.top)
                .padding(.top, Theme.Spacing.sm)
                .padding(.horizontal, Theme.Spacing.lg)

                // Rest timer overlay
                if viewModel.isRestTimerActive {
                    restTimerOverlay
                }
            } else {
                emptyFocusState
            }
        }
        // Push content below any active Dynamic Island (#289). Bumps content
        // down deterministically when an island (e.g. music app) is present.
        .safeAreaInset(edge: .top, spacing: 0) {
            Color.clear.frame(height: 8)
        }
        .sheet(isPresented: $showExercisePicker) {
            ExercisePickerView { exercise in
                viewModel.addExercise(exercise)
                // Jump focus to the newly added exercise
                viewModel.focusExerciseIndex = viewModel.exercises.count - 1
                viewModel.focusSetIndex = 0
            }
        }
        .onChange(of: viewModel.isRestTimerActive) { _, isActive in
            if isActive { isRestTimerMinimized = false }
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
                // Laterality badge when not bilateral
                if exercise.exercise.supportsUnilateral && exercise.selectedLaterality != .bilateral {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.left.and.right")
                            .font(.caption2)
                        Text(exercise.selectedLaterality.displayName)
                            .font(Theme.fontSmall)
                    }
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.accent.opacity(0.15))
                    .clipShape(.capsule)
                }
            }
        }
    }

    // MARK: - Set Indicator

    private func setIndicator(exercise: WorkoutExercise) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { idx, set in
                    let isCompleted = set.completedAt != Date.distantPast
                    let isFocused = idx == viewModel.focusSetIndex
                    Button {
                        viewModel.focusSetIndex = idx
                    } label: {
                        ZStack {
                            Circle()
                                .fill(isCompleted ? Theme.accent : Color.clear)
                                .frame(width: 36, height: 36)
                            if !isCompleted {
                                Circle()
                                    .stroke(isFocused ? Theme.accent : Theme.textSecondary.opacity(0.5), lineWidth: isFocused ? 2 : 1.5)
                                    .frame(width: 36, height: 36)
                            }
                            Text("\(idx + 1)")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(isCompleted ? .black : (isFocused ? Theme.accent : Theme.textSecondary))
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Set \(idx + 1)\(isCompleted ? ", completed" : "")\(isFocused ? ", current" : "")")
                }
            }
            .padding(.horizontal, Theme.Spacing.sm)
        }
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

            if let exercise = viewModel.focusExercise, exercise.selectedLaterality != .bilateral {
                let isLeg = exercise.exercise.muscleGroups.contains(where: { [.quads, .hamstrings, .glutes, .calves].contains($0) })
                Text(isLeg ? "per leg" : "per arm")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
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
        VStack(spacing: Theme.Spacing.sm) {
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

                // Add exercise button
                Button {
                    showExercisePicker = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 56, height: 56)
                        .background(Theme.surface)
                        .clipShape(Circle())
                }
                .accessibilityLabel("Add exercise")
            }

            // Rest timer config (compact, visible in focus mode)
            HStack(spacing: 6) {
                Image(systemName: "timer")
                    .font(.caption2)
                    .foregroundStyle(Theme.accent)
                Text("Rest:")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                Menu {
                    Button("Off") { viewModel.defaultRestDuration = 0 }
                    Button("30s") { viewModel.defaultRestDuration = 30 }
                    Button("60s") { viewModel.defaultRestDuration = 60 }
                    Button("90s") { viewModel.defaultRestDuration = 90 }
                    Button("120s") { viewModel.defaultRestDuration = 120 }
                    Button("180s") { viewModel.defaultRestDuration = 180 }
                } label: {
                    Text(viewModel.defaultRestDuration > 0 ? "\(Int(viewModel.defaultRestDuration))s" : "Off")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.accent.opacity(0.12))
                        .clipShape(.capsule)
                }
            }
        }
    }

    // MARK: - Rest Timer Overlay

    private var restTimerOverlay: some View {
        Group {
            if isRestTimerMinimized {
                // Minimized: bottom banner with Lift button and tap-to-expand
                VStack {
                    Spacer()
                    HStack(spacing: Theme.Spacing.sm) {
                        // Tap the timer area to expand back to full screen
                        Button {
                            withAnimation(.xomChill) { isRestTimerMinimized = false }
                        } label: {
                            RestTimerView(
                                restTimeRemaining: viewModel.restTimeRemaining,
                                restDuration: viewModel.restDuration,
                                onSkip: { viewModel.skipRestTimer() },
                                onExtend: { viewModel.extendRestTimer() }
                            )
                        }
                        .buttonStyle(.plain)

                        // Lift button to skip timer entirely
                        Button {
                            Haptics.success()
                            viewModel.skipRestTimer()
                            isRestTimerMinimized = false
                        } label: {
                            Text("LIFT")
                                .font(.caption.weight(.black))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Theme.accent)
                                .clipShape(.capsule)
                        }
                    }
                    if let nextEx = viewModel.upcomingExercise {
                        Text("Next: \(nextEx.exercise.name)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.lg)
                .shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: -4)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                // Full-screen rest timer
                fullScreenRestTimer
                    .transition(.opacity)
            }
        }
    }

    private var restIsOvertime: Bool { viewModel.restTimeRemaining <= 0 }

    private var restProgress: Double {
        guard viewModel.restDuration > 0 else { return 0 }
        if restIsOvertime { return 1.0 }
        return 1 - (viewModel.restTimeRemaining / viewModel.restDuration)
    }

    private var restTimeString: String {
        if restIsOvertime {
            let total = Int(abs(viewModel.restTimeRemaining))
            return String(format: "-%d:%02d", total / 60, total % 60)
        }
        let total = Int(viewModel.restTimeRemaining)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private var fullScreenRestTimer: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()

            VStack(spacing: Theme.Spacing.xl) {
                // Minimize button
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.xomChill) { isRestTimerMinimized = true }
                    } label: {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 44, height: 44)
                            .background(Theme.surface.opacity(0.3))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Minimize rest timer")
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)

                Spacer()

                // Large circular ring
                ZStack {
                    Circle()
                        .stroke(Theme.textSecondary.opacity(0.2), lineWidth: 12)

                    Circle()
                        .trim(from: 0, to: restProgress)
                        .stroke(restIsOvertime ? Theme.destructive : Theme.accent, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: restProgress)

                    VStack(spacing: 4) {
                        Text("REST")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.textSecondary)
                        Text(restTimeString)
                            .font(.system(size: 56, weight: .black, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(restIsOvertime ? Theme.destructive : .white)
                    }
                }
                .frame(width: 240, height: 240)

                // Next exercise hint
                if let nextEx = viewModel.upcomingExercise {
                    VStack(spacing: 4) {
                        Text("NEXT UP")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Theme.accent)
                        Text(nextEx.exercise.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                    }
                }

                // +30s button
                Button {
                    Haptics.light()
                    viewModel.extendRestTimer()
                } label: {
                    Text("+30s")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Theme.accent.opacity(0.15))
                        .clipShape(.capsule)
                }
                .accessibilityLabel("Add 30 seconds to rest timer")

                Spacer()

                // LIFT button
                Button {
                    Haptics.success()
                    viewModel.skipRestTimer()
                    isRestTimerMinimized = false
                } label: {
                    Text("LIFT")
                        .font(.title.weight(.black))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 22)
                        .background(Theme.accent)
                        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.xl)
                .accessibilityLabel("Skip rest timer and return to sets")
            }
        }
    }

    // MARK: - Empty State

    private var emptyFocusState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "figure.strengthtraining.traditional")
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
