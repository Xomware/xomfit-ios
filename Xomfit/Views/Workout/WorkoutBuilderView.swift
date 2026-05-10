import SwiftUI

struct WorkoutBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var authService
    @Environment(WorkoutLoggerViewModel.self) private var workoutSession

    @State private var viewModel = WorkoutBuilderViewModel()
    @State private var showExercisePicker = false

    /// Action sheet presented when the user taps "Save" — lets them save as
    /// template, start immediately, do both, or cancel.
    @State private var showSaveOptions = false

    // MARK: - Warmup flow (#261)

    @AppStorage("warmupOptIn") private var warmupOptIn: String = ""
    @AppStorage("warmupMinutes") private var warmupMinutes: Int = 6

    @State private var pendingStart: (() -> Void)?
    @State private var pendingStretches: [Stretch] = []
    @State private var showWarmupPrompt = false
    @State private var showWarmup = false

    var template: WorkoutTemplate? = nil

    private var userId: String {
        authService.currentUser?.id.uuidString.lowercased() ?? ""
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.md) {
                        nameField
                        categoryPicker
                        exerciseList
                        addExerciseButton
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
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
                        Haptics.light()
                        showSaveOptions = true
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
        .confirmationDialog(
            "What do you want to do with this workout?",
            isPresented: $showSaveOptions,
            titleVisibility: .visible
        ) {
            Button("Save as Template") {
                Haptics.success()
                viewModel.save()
                dismiss()
            }
            Button("Start Now") {
                Haptics.medium()
                let template = viewModel.buildTemplate()
                startTemplateWithWarmupGate(template)
            }
            Button("Save AND Start") {
                Haptics.success()
                let saved = viewModel.save()
                startTemplateWithWarmupGate(saved)
            }
            Button("Discard", role: .destructive) {
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You can save it for later, jump in now, or both.")
        }
        .confirmationDialog(
            "Warm up first?",
            isPresented: $showWarmupPrompt,
            titleVisibility: .visible
        ) {
            Button("Yes, \(warmupMinutes) min") {
                warmupOptIn = "yes"
                showWarmup = true
            }
            Button("No, skip") {
                warmupOptIn = "no"
                runPendingStartImmediately()
            }
            Button("Just this once", role: .cancel) {
                runPendingStartImmediately()
            }
        } message: {
            Text("A 5-10 minute stretch routine helps loosen up before lifting.")
        }
        .fullScreenCover(isPresented: $showWarmup) {
            WarmupView(
                stretches: pendingStretches.isEmpty ? StretchDatabase.defaultRoutine() : pendingStretches,
                totalDuration: warmupMinutes * 60
            ) {
                runPendingStartImmediately()
            }
        }
    }

    // MARK: - Name Field

    private var nameField: some View {
        TextField("Workout Name", text: $viewModel.name)
            .font(Theme.fontBodyEmphasized)
            .foregroundStyle(Theme.textPrimary)
            .padding(Theme.Spacing.md)
            .background(Theme.surface)
            .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }

    // MARK: - Category Picker

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(WorkoutTemplate.TemplateCategory.allCases, id: \.self) { cat in
                    Button {
                        viewModel.category = cat
                    } label: {
                        HStack(spacing: Theme.Spacing.tight) {
                            Image(systemName: cat.icon)
                                .font(Theme.fontCaption2)
                            Text(cat.displayName)
                                .font(Theme.fontSmall)
                        }
                        .foregroundStyle(viewModel.category == cat ? .black : Theme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(viewModel.category == cat ? Theme.accent : Theme.surface)
                        .clipShape(.rect(cornerRadius: 20))
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
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(Array(viewModel.exercises.enumerated()), id: \.element.id) { index, exercise in
                        BuilderExerciseRow(
                            exercise: exercise,
                            onUpdateSets: { viewModel.updateSets(at: index, sets: $0) },
                            onUpdateReps: { viewModel.updateReps(at: index, reps: $0) },
                            onUpdateNotes: { viewModel.updateNotes(at: index, notes: $0) },
                            onUpdateRestSeconds: { viewModel.updateRestSeconds(at: index, seconds: $0) },
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
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(Theme.fontLargeTitle)
                .foregroundStyle(Theme.textSecondary.opacity(0.5))
            Text("No exercises yet")
                .font(Theme.fontBody)
                .foregroundStyle(Theme.textSecondary)
            Text("Add exercises to build your workout")
                .font(Theme.fontCaption)
                .foregroundStyle(Theme.textSecondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.lg * 2)
    }

    // MARK: - Add Exercise Button

    private var addExerciseButton: some View {
        Button {
            Haptics.light()
            showExercisePicker = true
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
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
        .accessibilityLabel("Add exercise to workout")
    }

    // MARK: - Start flow

    /// Dismisses the builder sheet, then runs the warmup gate before kicking off
    /// the live workout. The dismiss-first ordering ensures the active workout
    /// cover doesn't get presented on top of the builder.
    private func startTemplateWithWarmupGate(_ template: WorkoutTemplate) {
        let captured = template
        let startAction: () -> Void = {
            workoutSession.startFromTemplate(captured, userId: userId)
            workoutSession.isPresented = true
        }
        let stretches = StretchDatabase.suggestedStretches(
            for: captured,
            target: TimeInterval(warmupMinutes * 60)
        )

        // Dismiss first so the builder sheet animates away cleanly. Then gate.
        dismiss()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            requestStart(stretches: stretches, action: startAction)
        }
    }

    /// Mirrors `WorkoutView.requestStart` -- either prompts about warming up,
    /// presents the warmup sheet, or runs the start action directly, depending
    /// on the user's saved preference.
    private func requestStart(stretches: [Stretch], action: @escaping () -> Void) {
        pendingStart = action
        pendingStretches = stretches

        switch warmupOptIn {
        case "yes":
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showWarmup = true
            }
        case "no":
            runPendingStartImmediately()
        default:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showWarmupPrompt = true
            }
        }
    }

    private func runPendingStartImmediately() {
        let action = pendingStart
        pendingStart = nil
        pendingStretches = []
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            action?()
        }
    }
}

// MARK: - Exercise Row

private struct BuilderExerciseRow: View {
    let exercise: WorkoutTemplate.TemplateExercise
    let onUpdateSets: (Int) -> Void
    let onUpdateReps: (String) -> Void
    let onUpdateNotes: (String?) -> Void
    let onUpdateRestSeconds: (Int?) -> Void
    let onDelete: () -> Void

    /// Pulled from the same UserDefaults key the rest of the app reads. Lets the
    /// rest pill show the live default when the template doesn't override.
    @AppStorage("restDuration") private var defaultRestStored: Double = 90

    @State private var repsText: String = ""
    @State private var showNotesSheet = false
    @State private var showRestSheet = false

    private var defaultRestSeconds: Int {
        let v = defaultRestStored > 0 ? defaultRestStored : 90
        return Int(v)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Header: name + delete
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(exercise.exercise.name)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)

                    HStack(spacing: Theme.Spacing.tight) {
                        ForEach(exercise.exercise.muscleGroups.prefix(3), id: \.self) { mg in
                            Text(mg.displayName)
                                .font(Theme.fontSmall)
                                .foregroundStyle(Theme.textSecondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, Theme.Spacing.tighter)
                                .background(Theme.surfaceSecondary)
                                .clipShape(.rect(cornerRadius: 4))
                        }
                    }
                }

                Spacer()

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(Theme.fontSubheadline)
                        .foregroundStyle(Theme.destructive.opacity(0.8))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Remove \(exercise.exercise.name)")
            }

            // Sets & Reps controls
            HStack(spacing: Theme.Spacing.md) {
                // Sets stepper
                HStack(spacing: Theme.Spacing.sm) {
                    Text("Sets")
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)

                    Button {
                        onUpdateSets(exercise.targetSets - 1)
                    } label: {
                        Image(systemName: "minus.circle")
                            .foregroundStyle(exercise.targetSets > 1 ? Theme.accent : Theme.textSecondary.opacity(0.3))
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .disabled(exercise.targetSets <= 1)
                    .accessibilityLabel("Decrease sets")

                    Text("\(exercise.targetSets)")
                        .font(.body.weight(.bold).monospaced())
                        .foregroundStyle(Theme.textPrimary)
                        .frame(minWidth: 24)
                        .accessibilityLabel("\(exercise.targetSets) sets")

                    Button {
                        onUpdateSets(exercise.targetSets + 1)
                    } label: {
                        Image(systemName: "plus.circle")
                            .foregroundStyle(Theme.accent)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Increase sets")
                }

                Spacer()

                // Reps field
                HStack(spacing: Theme.Spacing.sm) {
                    Text("Reps")
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)

                    TextField("8-12", text: $repsText)
                        .font(.subheadline.weight(.semibold).monospaced())
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.center)
                        .frame(width: 60)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, 6)
                        .background(Theme.surfaceSecondary)
                        .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
                        .onAppear { repsText = exercise.targetReps }
                        .onChange(of: repsText) { _, newValue in
                            onUpdateReps(newValue)
                        }
                }
            }

            // Notes + per-exercise rest override (#318) — reuses the same sheets the
            // live workout uses so the look-and-feel matches the template builder.
            HStack(spacing: 6) {
                notesPill
                restPill
                Spacer()
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
        .sheet(isPresented: $showNotesSheet) {
            ExerciseNotesSheet(
                exerciseName: exercise.exercise.name,
                initialNotes: exercise.notes ?? "",
                onSave: { onUpdateNotes($0) }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showRestSheet) {
            ExerciseRestSheet(
                exerciseName: exercise.exercise.name,
                initialRestSeconds: exercise.restSeconds ?? defaultRestSeconds,
                isCustomized: exercise.restSeconds != nil,
                defaultRestSeconds: defaultRestSeconds,
                onSave: { onUpdateRestSeconds($0) }
            )
            .presentationDetents([.medium])
        }
    }

    // MARK: - Pills

    private var notesPill: some View {
        let hasNote = (exercise.notes?.isEmpty == false)
        return Button {
            Haptics.selection()
            showNotesSheet = true
        } label: {
            HStack(spacing: Theme.Spacing.tight) {
                Image(systemName: hasNote ? "note.text" : "plus")
                    .font(.caption2.weight(.semibold))
                if hasNote, let preview = previewText(exercise.notes) {
                    Text(preview)
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                } else {
                    Text("Add note")
                        .font(.caption2.weight(.semibold))
                }
            }
            .foregroundStyle(hasNote ? .black : Theme.textSecondary)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.tight)
            .background(hasNote ? Theme.accent : Theme.surfaceSecondary)
            .clipShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(hasNote ? "Edit note: \(exercise.notes ?? "")" : "Add note")
    }

    private var restPill: some View {
        let isCustom = exercise.restSeconds != nil
        let seconds = exercise.restSeconds ?? defaultRestSeconds
        return Button {
            Haptics.selection()
            showRestSheet = true
        } label: {
            HStack(spacing: Theme.Spacing.tight) {
                Image(systemName: "timer")
                    .font(.caption2.weight(.semibold))
                Text("Rest: \(formatRest(seconds))")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(isCustom ? .black : Theme.textSecondary)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.tight)
            .background(isCustom ? Theme.accent : Theme.surfaceSecondary)
            .clipShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Rest \(formatRest(seconds))\(isCustom ? ", custom" : ", default")")
    }

    private func previewText(_ notes: String?) -> String? {
        guard let notes else { return nil }
        let single = notes.replacingOccurrences(of: "\n", with: " ")
        let trimmed = single.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.count > 24 { return String(trimmed.prefix(24)) + "…" }
        return trimmed
    }

    private func formatRest(_ seconds: Int) -> String {
        if seconds >= 60 && seconds % 60 == 0 { return "\(seconds / 60)m" }
        if seconds < 60 { return "\(seconds)s" }
        let m = seconds / 60
        let s = seconds % 60
        return "\(m)m \(s)s"
    }
}
