import SwiftUI

/// Manual data-entry sheet for logging a workout that already happened.
/// No live timer, no rest timer — just date, optional duration, optional name,
/// and a list of exercises with weight/reps for each set.
struct LogPastWorkoutView: View {
    @Environment(AuthService.self) private var authService
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = LogPastWorkoutViewModel()
    @State private var showExercisePicker = false
    @State private var showDiscardAlert = false

    private var userId: String {
        authService.currentUser?.id.uuidString.lowercased() ?? ""
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.md) {
                        metadataCard
                        exerciseList
                        addExerciseButton
                        if let error = viewModel.errorMessage {
                            errorBanner(error)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .padding(.bottom, Theme.Spacing.xxl)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Log Past Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if hasContent {
                            showDiscardAlert = true
                        } else {
                            dismiss()
                        }
                    }
                    .foregroundStyle(Theme.accent)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                                .tint(Theme.accent)
                        } else {
                            Text("Save")
                                .fontWeight(.bold)
                        }
                    }
                    .foregroundStyle(viewModel.canSave ? Theme.accent : Theme.textSecondary)
                    .disabled(!viewModel.canSave || viewModel.isSaving)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                    }
                    .foregroundStyle(Theme.accent)
                }
            }
        }
        .interactiveDismissDisabled(hasContent)
        .sheet(isPresented: $showExercisePicker) {
            ExercisePickerView { exercise in
                viewModel.addExercise(exercise)
            }
        }
        .alert("Discard entry?", isPresented: $showDiscardAlert) {
            Button("Discard", role: .destructive) {
                viewModel.reset()
                dismiss()
            }
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("Your entered data will be lost.")
        }
    }

    // MARK: - Save

    private func save() async {
        guard !userId.isEmpty else {
            viewModel.errorMessage = "Sign in required to save."
            return
        }
        Haptics.medium()
        let ok = await viewModel.saveWorkout(userId: userId)
        if ok {
            Haptics.success()
            dismiss()
        } else {
            Haptics.error()
        }
    }

    private var hasContent: Bool {
        !viewModel.exercises.isEmpty
            || !viewModel.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || viewModel.durationMinutes != nil
    }

    // MARK: - Metadata Card

    private var metadataCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Name
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Name")
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textSecondary)
                TextField(LogPastWorkoutViewModel.defaultName, text: $viewModel.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(Theme.Spacing.sm)
                    .background(Theme.surfaceElevated)
                    .clipShape(.rect(cornerRadius: Theme.Radius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.sm)
                            .strokeBorder(Theme.hairline, lineWidth: 0.5)
                    )
            }

            // Date
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Date & Time")
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textSecondary)
                DatePicker(
                    "",
                    selection: $viewModel.workoutDate,
                    in: ...Date(),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(Theme.accent)
                .accessibilityLabel("Workout date and time")
            }

            // Duration
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Duration (minutes, optional)")
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textSecondary)
                DurationField(durationMinutes: $viewModel.durationMinutes)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }

    // MARK: - Exercises

    private var exerciseList: some View {
        Group {
            if viewModel.exercises.isEmpty {
                emptyState
            } else {
                VStack(spacing: Theme.Spacing.md) {
                    ForEach(viewModel.exercises.indices, id: \.self) { index in
                        PastExerciseCard(
                            exercise: viewModel.exercises[index],
                            onAddSet: { viewModel.addSet(to: index) },
                            onRemoveSet: { setIdx in viewModel.removeSet(exerciseIndex: index, setIndex: setIdx) },
                            onUpdateSet: { setIdx, weight, reps in
                                viewModel.updateSet(exerciseIndex: index, setIndex: setIdx, weight: weight, reps: reps)
                            },
                            onDelete: { viewModel.removeExercise(at: index) }
                        )
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "calendar.badge.clock")
                .font(.largeTitle)
                .foregroundStyle(Theme.textSecondary.opacity(0.5))
            Text("No exercises yet")
                .font(Theme.fontBody)
                .foregroundStyle(Theme.textSecondary)
            Text("Add the lifts you did")
                .font(Theme.fontCaption)
                .foregroundStyle(Theme.textSecondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.lg * 2)
    }

    private var addExerciseButton: some View {
        Button {
            Haptics.light()
            showExercisePicker = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                Text("Add Exercise")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(Theme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.accent.opacity(0.1))
            .clipShape(.rect(cornerRadius: Theme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .strokeBorder(Theme.accent.opacity(0.3), lineWidth: 1)
            )
        }
        .accessibilityLabel("Add exercise to past workout")
    }

    private func errorBanner(_ text: String) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.destructive)
            Text(text)
                .font(Theme.fontCaption)
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.destructive.opacity(0.12))
        .clipShape(.rect(cornerRadius: Theme.Radius.sm))
    }
}

// MARK: - Duration Field

private struct DurationField: View {
    @Binding var durationMinutes: Int?
    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("e.g. 45", text: $text)
            .keyboardType(.numberPad)
            .font(Theme.fontNumberMedium)
            .foregroundStyle(Theme.textPrimary)
            .padding(Theme.Spacing.sm)
            .background(Theme.surfaceElevated)
            .clipShape(.rect(cornerRadius: Theme.Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .strokeBorder(focused ? Theme.hairlineStrong : Theme.hairline, lineWidth: 0.5)
            )
            .focused($focused)
            .onAppear {
                if let m = durationMinutes { text = "\(m)" }
            }
            .onChange(of: text) { _, newValue in
                let digits = newValue.filter { $0.isNumber }
                if digits != newValue { text = digits }
                durationMinutes = digits.isEmpty ? nil : Int(digits)
            }
            .accessibilityLabel("Duration in minutes, optional")
    }
}

// MARK: - Past Exercise Card

private struct PastExerciseCard: View {
    let exercise: WorkoutExercise
    let onAddSet: () -> Void
    let onRemoveSet: (Int) -> Void
    let onUpdateSet: (Int, Double, Int) -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Header
            HStack {
                Image(systemName: exercise.exercise.icon)
                    .font(.headline)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 32, height: 32)
                    .background(Theme.accentMuted)
                    .clipShape(.rect(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.exercise.name)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(exercise.exercise.muscleGroups.first?.displayName ?? "")
                        .font(Theme.fontSmall)
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer()

                Button {
                    Haptics.light()
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.subheadline)
                        .foregroundStyle(Theme.destructive.opacity(0.8))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Remove \(exercise.exercise.name)")
            }

            // Column header
            HStack(spacing: Theme.Spacing.sm) {
                Text("SET")
                    .frame(width: 36, alignment: .center)
                Text("WEIGHT (LBS)")
                    .frame(maxWidth: .infinity)
                Text("REPS")
                    .frame(maxWidth: .infinity)
                // Spacer matching trailing delete button width in PastSetRow
                Color.clear.frame(width: 32)
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, Theme.Spacing.xs)

            // Sets
            VStack(spacing: Theme.Spacing.xs) {
                ForEach(exercise.sets.indices, id: \.self) { setIdx in
                    PastSetRow(
                        setNumber: setIdx + 1,
                        workoutSet: exercise.sets[setIdx],
                        onWeightChange: { w in
                            onUpdateSet(setIdx, w, exercise.sets[setIdx].reps)
                        },
                        onRepsChange: { r in
                            onUpdateSet(setIdx, exercise.sets[setIdx].weight, r)
                        },
                        onDelete: { onRemoveSet(setIdx) }
                    )
                }
            }

            // Add set
            Button {
                Haptics.light()
                onAddSet()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Add Set")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Theme.accent.opacity(0.08))
                .clipShape(.rect(cornerRadius: Theme.Radius.sm))
            }
            .accessibilityLabel("Add set to \(exercise.exercise.name)")
        }
        .padding(Theme.Spacing.md)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }
}

// MARK: - Past Set Row (no checkmark, no rest timer)

private struct PastSetRow: View {
    let setNumber: Int
    let workoutSet: WorkoutSet
    let onWeightChange: (Double) -> Void
    let onRepsChange: (Int) -> Void
    let onDelete: () -> Void

    @State private var weightText: String
    @State private var repsText: String
    @FocusState private var isWeightFocused: Bool
    @FocusState private var isRepsFocused: Bool

    init(
        setNumber: Int,
        workoutSet: WorkoutSet,
        onWeightChange: @escaping (Double) -> Void,
        onRepsChange: @escaping (Int) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.setNumber = setNumber
        self.workoutSet = workoutSet
        self.onWeightChange = onWeightChange
        self.onRepsChange = onRepsChange
        self.onDelete = onDelete
        let w = workoutSet.weight
        let r = workoutSet.reps
        _weightText = State(initialValue: w > 0 ? w.formattedWeight : "")
        _repsText   = State(initialValue: r > 0 ? "\(r)" : "")
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text("\(setNumber)")
                .font(.subheadline.weight(.bold).monospaced())
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 36, alignment: .center)

            TextField("0", text: $weightText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(Theme.fontNumberMedium)
                .padding(.vertical, 8)
                .padding(.horizontal, 6)
                .background(Theme.surfaceElevated)
                .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                        .strokeBorder(isWeightFocused ? Theme.hairlineStrong : Theme.hairline, lineWidth: 0.5)
                )
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity)
                .focused($isWeightFocused)
                .onChange(of: weightText) { _, newValue in
                    if newValue.isEmpty {
                        onWeightChange(0)
                    } else if let w = Double(newValue) {
                        onWeightChange(w)
                    }
                }
                .accessibilityLabel("Weight for set \(setNumber)")

            TextField("0", text: $repsText)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(Theme.fontNumberMedium)
                .padding(.vertical, 8)
                .padding(.horizontal, 6)
                .background(Theme.surfaceElevated)
                .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                        .strokeBorder(isRepsFocused ? Theme.hairlineStrong : Theme.hairline, lineWidth: 0.5)
                )
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity)
                .focused($isRepsFocused)
                .onChange(of: repsText) { _, newValue in
                    if newValue.isEmpty {
                        onRepsChange(0)
                    } else if let r = Int(newValue) {
                        onRepsChange(r)
                    }
                }
                .accessibilityLabel("Reps for set \(setNumber)")

            Button {
                Haptics.light()
                onDelete()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(Theme.destructive)
                    .font(.headline)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete set \(setNumber)")
        }
        .frame(minHeight: 44)
    }
}
