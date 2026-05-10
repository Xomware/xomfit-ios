import SwiftUI

struct TemplateDetailView: View {
    let template: WorkoutTemplate
    let onStart: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var authService
    @Environment(WorkoutLoggerViewModel.self) private var workoutSession

    // MARK: - Editable State

    /// Mutable copy of the template used as the source of truth for the editable UI.
    @State private var draft: WorkoutTemplate
    /// Per-exercise target weight entered by the user. Not persisted on `WorkoutTemplate`
    /// (model has no weight field) — only used for "Save as workout" and "Start Lift" prefill.
    @State private var targetWeights: [String: Double] = [:]

    @State private var hasUnsavedChanges = false
    @State private var showExercisePicker = false
    @State private var showLegacyEditor = false
    @State private var showSaveDialog = false
    @State private var showDismissDialog = false
    @State private var showSaveAsNewSheet = false
    @State private var newTemplateName: String = ""
    @State private var isSaving = false
    @State private var saveError: String?

    init(template: WorkoutTemplate, onStart: @escaping () -> Void) {
        self.template = template
        self.onStart = onStart
        _draft = State(initialValue: template)
    }

    private var userId: String {
        authService.currentUser?.id.uuidString.lowercased() ?? ""
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            headerSection
                            exerciseListSection
                            addExerciseButton
                            if let saveError {
                                Text(saveError)
                                    .font(Theme.fontCaption)
                                    .foregroundStyle(Theme.destructive)
                            }
                        }
                        .padding(Theme.Spacing.md)
                        .padding(.bottom, 80)
                    }

                    startButton
                }
            }
            .navigationTitle(draft.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar { toolbarContent }
            .interactiveDismissDisabled(hasUnsavedChanges)
            .sheet(isPresented: $showLegacyEditor) {
                WorkoutBuilderView(template: draft)
            }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerView { exercise in
                    addExercise(exercise)
                }
            }
            .sheet(isPresented: $showSaveAsNewSheet) {
                saveAsNewSheet
            }
            .confirmationDialog(
                "Save changes?",
                isPresented: $showSaveDialog,
                titleVisibility: .visible
            ) {
                if draft.isCustom {
                    Button("Update this template") {
                        Task { await saveUpdate() }
                    }
                }
                Button("Save as new template") {
                    newTemplateName = "\(draft.name) (Copy)"
                    showSaveAsNewSheet = true
                }
                Button("Save as workout (logged now)") {
                    Task { await saveAsWorkout() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You have unsaved changes to this template.")
            }
            .confirmationDialog(
                "Unsaved changes",
                isPresented: $showDismissDialog,
                titleVisibility: .visible
            ) {
                if draft.isCustom {
                    Button("Update this template") {
                        Task {
                            await saveUpdate()
                            if saveError == nil { dismiss() }
                        }
                    }
                }
                Button("Save as new template") {
                    newTemplateName = "\(draft.name) (Copy)"
                    showSaveAsNewSheet = true
                }
                Button("Save as workout (logged now)") {
                    Task {
                        await saveAsWorkout()
                        if saveError == nil { dismiss() }
                    }
                }
                Button("Discard changes", role: .destructive) {
                    hasUnsavedChanges = false
                    dismiss()
                }
                Button("Keep editing", role: .cancel) {}
            } message: {
                Text("Save as template, save as workout, or discard?")
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Close") {
                if hasUnsavedChanges {
                    Haptics.warning()
                    showDismissDialog = true
                } else {
                    dismiss()
                }
            }
            .foregroundStyle(Theme.textSecondary)
        }
        ToolbarItem(placement: .primaryAction) {
            HStack(spacing: Theme.Spacing.sm) {
                if hasUnsavedChanges {
                    Button {
                        Haptics.medium()
                        showSaveDialog = true
                    } label: {
                        Text("Save")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.accent)
                    }
                    .accessibilityLabel("Save changes")
                } else {
                    Button {
                        shareTemplate()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                    }
                    .accessibilityLabel("Share template")

                    if draft.isCustom {
                        Button {
                            showLegacyEditor = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.accent)
                        }
                        .accessibilityLabel("Edit template details")
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: 10) {
                Image(systemName: draft.category.icon)
                    .font(Theme.fontTitle3)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 40, height: 40)
                    .background(Theme.accent.opacity(0.15))
                    .clipShape(.rect(cornerRadius: Theme.Radius.xs))

                VStack(alignment: .leading, spacing: Theme.Spacing.tighter) {
                    Text(draft.category.displayName)
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.accent)
                    Text(draft.description)
                        .font(Theme.fontBody)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            if !targetMuscleGroups.isEmpty {
                targetsRow
            }

            HStack(spacing: Theme.Spacing.lg) {
                statPill(icon: "dumbbell.fill", label: "Exercises", value: "\(draft.exercises.count)")
                statPill(icon: "clock.fill", label: "Duration", value: "~\(estimatedDuration)m")
                statPill(icon: "arrow.up.arrow.down", label: "Total Sets", value: "\(totalSets)")
            }
            .padding(.top, Theme.Spacing.sm)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }

    /// Union of muscle groups hit by every exercise in the template, in source order
    /// (de-duplicated). Used by the "Targets" chip row.
    private var targetMuscleGroups: [MuscleGroup] {
        var seen = Set<MuscleGroup>()
        var ordered: [MuscleGroup] = []
        for tex in draft.exercises {
            for mg in tex.exercise.muscleGroups where !seen.contains(mg) {
                seen.insert(mg)
                ordered.append(mg)
            }
        }
        return ordered
    }

    private var targetsRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Targets")
                .font(Theme.fontSmall)
                .foregroundStyle(Theme.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(targetMuscleGroups, id: \.self) { mg in
                        XomBadge(mg.displayName, icon: mg.icon, color: Theme.accent, variant: .display)
                    }
                }
            }
        }
        .padding(.top, Theme.Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Targets: \(targetMuscleGroups.map(\.displayName).joined(separator: ", "))")
    }

    private var totalSets: Int {
        draft.exercises.reduce(0) { $0 + $1.targetSets }
    }

    /// Estimated duration recomputes from current set count for live feedback.
    private var estimatedDuration: Int {
        max(draft.estimatedDuration, totalSets * 2)
    }

    private func statPill(icon: String, label: String, value: String) -> some View {
        VStack(spacing: Theme.Spacing.tight) {
            Image(systemName: icon)
                .font(Theme.fontSubheadline)
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

    private var exerciseListSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Exercises")
                .font(.body.weight(.bold))
                .foregroundStyle(Theme.textPrimary)

            if draft.exercises.isEmpty {
                emptyState
            } else {
                ForEach(Array(draft.exercises.enumerated()), id: \.element.id) { index, exercise in
                    EditableExerciseRow(
                        index: index + 1,
                        exercise: exercise,
                        targetWeight: bindingForWeight(exerciseId: exercise.id),
                        onUpdateSets: { newValue in updateSets(at: index, value: newValue) },
                        onUpdateReps: { newValue in updateReps(at: index, value: newValue) },
                        onDelete: { removeExercise(at: index) }
                    )
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
            Text("Add exercises to fill out this workout")
                .font(Theme.fontCaption)
                .foregroundStyle(Theme.textSecondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.lg)
    }

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
        .accessibilityLabel("Add exercise to template")
    }

    // MARK: - Start Button

    private var startButton: some View {
        Button {
            Haptics.medium()
            startLift()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                Text(hasUnsavedChanges ? "Start Lift" : "Start Workout")
                    .font(Theme.fontHeadline)
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
            .background(Theme.accent)
            .clipShape(.rect(cornerRadius: Theme.cornerRadius))
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.md)
        .background(Theme.background)
        .accessibilityLabel("Start \(draft.name) workout")
        .disabled(draft.exercises.isEmpty)
        .opacity(draft.exercises.isEmpty ? 0.5 : 1)
    }

    // MARK: - Save-as-new Sheet

    private var saveAsNewSheet: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                VStack(spacing: Theme.Spacing.md) {
                    Text("Name your new template")
                        .font(Theme.fontHeadline)
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("Template name", text: $newTemplateName)
                        .font(Theme.fontBodyEmphasized)
                        .foregroundStyle(Theme.textPrimary)
                        .padding(Theme.Spacing.md)
                        .background(Theme.surface)
                        .clipShape(.rect(cornerRadius: Theme.cornerRadius))

                    Spacer()
                }
                .padding(Theme.Spacing.md)
            }
            .navigationTitle("Save as New")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showSaveAsNewSheet = false }
                        .foregroundStyle(Theme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveAsNewTemplate() }
                    }
                    .foregroundStyle(canSaveNew ? Theme.accent : Theme.textSecondary)
                    .disabled(!canSaveNew)
                }
            }
        }
    }

    private var canSaveNew: Bool {
        !newTemplateName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Mutation Helpers

    private func bindingForWeight(exerciseId: String) -> Binding<Double> {
        Binding(
            get: { targetWeights[exerciseId] ?? 0 },
            set: { newValue in
                if (targetWeights[exerciseId] ?? 0) != newValue {
                    targetWeights[exerciseId] = newValue
                    markDirty()
                }
            }
        )
    }

    private func updateSets(at index: Int, value: Int) {
        guard draft.exercises.indices.contains(index) else { return }
        let clamped = max(1, value)
        guard draft.exercises[index].targetSets != clamped else { return }
        draft.exercises[index].targetSets = clamped
        markDirty()
    }

    private func updateReps(at index: Int, value: String) {
        guard draft.exercises.indices.contains(index) else { return }
        guard draft.exercises[index].targetReps != value else { return }
        draft.exercises[index].targetReps = value
        markDirty()
    }

    private func addExercise(_ exercise: Exercise) {
        let newRow = WorkoutTemplate.TemplateExercise(
            id: UUID().uuidString,
            exercise: exercise,
            targetSets: 3,
            targetReps: "8-12",
            notes: nil
        )
        draft.exercises.append(newRow)
        markDirty()
    }

    private func removeExercise(at index: Int) {
        guard draft.exercises.indices.contains(index) else { return }
        let removed = draft.exercises.remove(at: index)
        targetWeights.removeValue(forKey: removed.id)
        markDirty()
    }

    private func markDirty() {
        if !hasUnsavedChanges { hasUnsavedChanges = true }
        saveError = nil
    }

    // MARK: - Actions: Save Paths

    /// Save edits onto the existing template (preserves id).
    private func saveUpdate() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        var updated = draft
        updated.estimatedDuration = estimatedDuration
        updated.isCustom = true
        TemplateService.shared.saveCustomTemplate(updated)
        Haptics.success()
        hasUnsavedChanges = false
    }

    /// Save edits as a new template (new id, name from prompt).
    private func saveAsNewTemplate() async {
        guard !isSaving, canSaveNew else { return }
        isSaving = true
        defer { isSaving = false }

        var copy = draft
        copy = WorkoutTemplate(
            id: UUID().uuidString,
            name: newTemplateName.trimmingCharacters(in: .whitespaces),
            description: copy.description,
            exercises: copy.exercises,
            estimatedDuration: estimatedDuration,
            category: copy.category == .saved ? .custom : copy.category,
            isCustom: true
        )
        TemplateService.shared.saveCustomTemplate(copy)
        Haptics.success()
        hasUnsavedChanges = false
        showSaveAsNewSheet = false
        // After saving as new, leave the sheet up so the user can choose to start lift,
        // matching the issue's "User can hit save then hit lift" flow.
    }

    /// Save the current edited values as a completed Workout (timestamped now).
    /// Reuses `WorkoutService.shared.saveWorkout(_:)` — same path used by `WorkoutLoggerViewModel.finishWorkout`.
    private func saveAsWorkout() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        let now = Date()
        let exercises: [WorkoutExercise] = draft.exercises.map { tex in
            let weight = targetWeights[tex.id] ?? 0
            let reps = parseFirstReps(tex.targetReps)
            let sets: [WorkoutSet] = (0..<tex.targetSets).map { _ in
                WorkoutSet(
                    id: UUID().uuidString,
                    exerciseId: tex.exercise.id,
                    weight: weight,
                    reps: reps,
                    rpe: nil,
                    isPersonalRecord: false,
                    completedAt: now
                )
            }
            return WorkoutExercise(
                id: UUID().uuidString,
                exercise: tex.exercise,
                sets: sets,
                notes: tex.notes
            )
        }

        let workout = Workout(
            id: UUID().uuidString,
            userId: userId,
            name: draft.name,
            exercises: exercises,
            startTime: now,
            endTime: now,
            notes: nil
        )

        // saveWorkout always writes to local cache and queues for retry on Supabase failure.
        // A `false` return is non-fatal — surface a soft notice but still mark clean.
        let persisted = await WorkoutService.shared.saveWorkout(workout)
        if !persisted {
            saveError = "Saved offline — will sync when you're back online."
        }
        Haptics.success()
        hasUnsavedChanges = false
    }

    /// Best-effort parse of the leading rep count from a reps string like "8-12" or "AMRAP".
    private func parseFirstReps(_ s: String) -> Int {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        if let n = Int(trimmed) { return n }
        let head = trimmed.prefix { $0.isNumber }
        return Int(head) ?? 0
    }

    // MARK: - Actions: Start Lift

    /// Starts a workout from the current edited template values.
    /// Reuses `WorkoutLoggerViewModel.startFromTemplate(_:userId:)` — the same entry point WorkoutView uses.
    private func startLift() {
        if hasUnsavedChanges {
            // Prefill weights into the per-exercise notes? No — we feed them via Workout when saving,
            // and the logger uses last-set lookup for prefill. We pass the edited template directly.
            let edited = draft
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                workoutSession.startFromTemplate(edited, userId: userId)
                workoutSession.isPresented = true
                // Apply per-exercise target weight overrides where the user entered one.
                for (idx, tex) in edited.exercises.enumerated() {
                    if let w = targetWeights[tex.id], w > 0,
                       workoutSession.exercises.indices.contains(idx) {
                        for setIdx in workoutSession.exercises[idx].sets.indices {
                            workoutSession.exercises[idx].sets[setIdx].weight = w
                        }
                    }
                }
            }
        } else {
            // Unedited — defer to the parent's onStart callback (preserves existing flow).
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onStart()
            }
        }
    }

    // MARK: - Share

    private func shareTemplate() {
        let exercises = draft.exercises
            .map { "\($0.exercise.name) — \($0.targetSets) x \($0.targetReps)" }
            .joined(separator: "\n")
        let text = """
        \(draft.name)
        \(draft.description)

        \(exercises)

        \(draft.exercises.count) exercises · ~\(estimatedDuration) min

        Shared from XomFit
        """
        let controller = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.keyWindow?.rootViewController {
            root.present(controller, animated: true)
        }
    }
}

// MARK: - Editable Row

private struct EditableExerciseRow: View {
    let index: Int
    let exercise: WorkoutTemplate.TemplateExercise
    @Binding var targetWeight: Double
    let onUpdateSets: (Int) -> Void
    let onUpdateReps: (String) -> Void
    let onDelete: () -> Void

    @State private var repsText: String = ""
    @State private var weightText: String = ""
    @State private var showDetails: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Header row
            HStack(spacing: 12) {
                Text("\(index)")
                    .font(.caption.weight(.bold).monospaced())
                    .foregroundStyle(Theme.accent)
                    .frame(width: Theme.Spacing.lg, height: Theme.Spacing.lg)
                    .background(Theme.accent.opacity(0.15))
                    .clipShape(.rect(cornerRadius: Theme.Radius.xs))

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
                }

                Spacer()

                Button {
                    Haptics.selection()
                    showDetails = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: Theme.Spacing.xl, height: Theme.Spacing.xl)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show details for \(exercise.exercise.name)")

                Button {
                    Haptics.light()
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(Theme.fontSubheadline)
                        .foregroundStyle(Theme.destructive.opacity(0.85))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Remove \(exercise.exercise.name)")
            }

            // Editable controls: sets stepper, reps, weight
            HStack(alignment: .center, spacing: Theme.Spacing.sm) {
                // Sets stepper
                VStack(alignment: .leading, spacing: Theme.Spacing.tight) {
                    Text("Sets")
                        .font(Theme.fontSmall)
                        .foregroundStyle(Theme.textSecondary)
                    HStack(spacing: Theme.Spacing.tight) {
                        Button {
                            Haptics.selection()
                            onUpdateSets(exercise.targetSets - 1)
                        } label: {
                            Image(systemName: "minus.circle")
                                .foregroundStyle(exercise.targetSets > 1 ? Theme.accent : Theme.textSecondary.opacity(0.3))
                        }
                        .disabled(exercise.targetSets <= 1)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                        .accessibilityLabel("Decrease sets")

                        Text("\(exercise.targetSets)")
                            .font(.subheadline.weight(.bold).monospaced())
                            .foregroundStyle(Theme.textPrimary)
                            .frame(minWidth: 22)

                        Button {
                            Haptics.selection()
                            onUpdateSets(exercise.targetSets + 1)
                        } label: {
                            Image(systemName: "plus.circle")
                                .foregroundStyle(Theme.accent)
                        }
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                        .accessibilityLabel("Increase sets")
                    }
                }

                // Reps text field
                VStack(alignment: .leading, spacing: Theme.Spacing.tight) {
                    Text("Reps")
                        .font(Theme.fontSmall)
                        .foregroundStyle(Theme.textSecondary)
                    TextField("8-12", text: $repsText)
                        .font(.subheadline.weight(.semibold).monospaced())
                        .foregroundStyle(Theme.textPrimary)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.center)
                        .frame(width: 64)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(Theme.surfaceElevated)
                        .clipShape(.rect(cornerRadius: Theme.Radius.sm))
                        .onChange(of: repsText) { _, newValue in
                            onUpdateReps(newValue)
                        }
                        .accessibilityLabel("Target reps")
                }

                // Target weight text field
                VStack(alignment: .leading, spacing: Theme.Spacing.tight) {
                    Text("Weight")
                        .font(Theme.fontSmall)
                        .foregroundStyle(Theme.textSecondary)
                    TextField("0", text: $weightText)
                        .font(.subheadline.weight(.semibold).monospaced())
                        .foregroundStyle(Theme.textPrimary)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .frame(width: 70)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(Theme.surfaceElevated)
                        .clipShape(.rect(cornerRadius: Theme.Radius.sm))
                        .onChange(of: weightText) { _, newValue in
                            let parsed = Double(newValue) ?? 0
                            if parsed != targetWeight {
                                targetWeight = parsed
                            }
                        }
                        .accessibilityLabel("Target weight")
                }

                Spacer(minLength: 0)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
        .sheet(isPresented: $showDetails) {
            ExerciseDetailSheet(exercise: exercise.exercise)
        }
        .onAppear {
            repsText = exercise.targetReps
            if targetWeight > 0 {
                weightText = formatWeight(targetWeight)
            }
        }
        .onChange(of: exercise.targetReps) { _, newValue in
            if repsText != newValue { repsText = newValue }
        }
    }

    private func formatWeight(_ w: Double) -> String {
        if w.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(w))
        }
        return String(format: "%.1f", w)
    }
}
