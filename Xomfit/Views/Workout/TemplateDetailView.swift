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

    @State private var hasUnsavedChanges = false
    @State private var showExercisePicker = false
    @State private var showLegacyEditor = false
    @State private var showSaveDialog = false
    @State private var showDismissDialog = false
    @State private var showSaveAsNewSheet = false
    @State private var newTemplateName: String = ""
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showHistory = false
    @State private var matchingWorkouts: [Workout] = []
    @State private var selectedWorkout: Workout?

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
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            exerciseListSection
                            addExerciseButton
                            historySection
                            if let saveError {
                                Text(saveError)
                                    .font(Theme.fontCaption)
                                    .foregroundStyle(Theme.destructive)
                            }
                        }
                        .padding(Theme.Spacing.md)
                        .padding(.bottom, 80)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .scrollBounceBehavior(.basedOnSize)
                    .defaultScrollAnchor(.top)

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

    private var totalSets: Int {
        draft.exercises.reduce(0) { $0 + $1.targetSets }
    }

    /// Estimated duration recomputes from current set count for live feedback.
    private var estimatedDuration: Int {
        max(draft.estimatedDuration, totalSets * 2)
    }

    // MARK: - Exercise List

    private var exerciseListSection: some View {
        Group {
            if draft.exercises.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: Theme.Spacing.xs) {
                    ForEach(Array(draft.exercises.enumerated()), id: \.element.id) { index, exercise in
                        let exerciseId = exercise.id
                        TemplateExerciseRow(
                            index: index + 1,
                            exercise: exercise,
                            canMoveUp: index > 0,
                            canMoveDown: index < draft.exercises.count - 1,
                            onMoveUp: { moveExerciseById(exerciseId, direction: -1) },
                            onMoveDown: { moveExerciseById(exerciseId, direction: 1) },
                            onDelete: { removeExerciseById(exerciseId) }
                        )
                    }
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

    // MARK: - History Section

    private var historySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Button {
                withAnimation(.xomConfident) {
                    showHistory.toggle()
                }
                if showHistory && matchingWorkouts.isEmpty {
                    loadMatchingWorkouts()
                }
            } label: {
                HStack {
                    Text("History")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    if !matchingWorkouts.isEmpty {
                        Text("\(matchingWorkouts.count)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.accent)
                    }
                    Image(systemName: showHistory ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(Theme.surface)
                .clipShape(.rect(cornerRadius: Theme.cornerRadius))
            }
            .buttonStyle(.plain)

            if showHistory {
                if matchingWorkouts.isEmpty {
                    Text("No past workouts found")
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, Theme.Spacing.md)
                } else {
                    LazyVStack(spacing: Theme.Spacing.xs) {
                        ForEach(matchingWorkouts) { workout in
                            Button {
                                selectedWorkout = workout
                            } label: {
                                HStack {
                                    Text(workout.startTime.formatted(date: .abbreviated, time: .omitted))
                                        .font(.subheadline)
                                        .foregroundStyle(Theme.textPrimary)
                                    Spacer()
                                    Text(formatDuration(workout.duration))
                                        .font(.caption)
                                        .foregroundStyle(Theme.textSecondary)
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(Theme.textTertiary)
                                }
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.vertical, Theme.Spacing.sm)
                                .background(Theme.surfaceElevated)
                                .clipShape(.rect(cornerRadius: Theme.Radius.sm))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(.top, Theme.Spacing.md)
        .sheet(item: $selectedWorkout) { workout in
            NavigationStack {
                WorkoutDetailView(workout: workout)
            }
        }
        .onAppear {
            loadMatchingWorkouts()
        }
    }

    private func loadMatchingWorkouts() {
        Task {
            let allWorkouts = await WorkoutService.shared.fetchWorkouts(userId: userId)
            let templateExerciseIds = Set(draft.exercises.map { $0.exercise.id })

            // Find workouts that have the same exercises (by name match since IDs may differ)
            let templateExerciseNames = Set(draft.exercises.map { $0.exercise.name.lowercased() })

            let matches = allWorkouts.filter { workout in
                let workoutExerciseNames = Set(workout.exercises.map { $0.exercise.name.lowercased() })
                // Match if workout has at least 80% of template exercises
                let overlap = templateExerciseNames.intersection(workoutExerciseNames)
                return overlap.count >= Int(Double(templateExerciseNames.count) * 0.8)
            }
            .sorted { $0.startTime > $1.startTime }
            .prefix(10)

            await MainActor.run {
                matchingWorkouts = Array(matches)
            }
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        return "\(mins)m"
    }

    // MARK: - Start Button

    private var startButton: some View {
        Button {
            Haptics.success()
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
        draft.exercises.remove(at: index)
        markDirty()
    }

    /// ID-based remove — looks up current index at call time to avoid stale captures.
    private func removeExerciseById(_ id: String) {
        guard let index = draft.exercises.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.xomConfident) {
            draft.exercises.remove(at: index)
        }
        markDirty()
    }

    /// Swap an exercise with the row above (`direction = -1`) or below (`direction = 1`).
    /// No-ops cleanly at the boundaries so callers don't need their own guards.
    private func moveExercise(at index: Int, direction: Int) {
        let target = index + direction
        guard draft.exercises.indices.contains(index),
              draft.exercises.indices.contains(target) else { return }
        Haptics.selection()
        withAnimation(.xomConfident) {
            draft.exercises.swapAt(index, target)
        }
        markDirty()
    }

    /// ID-based move — looks up current index at call time to avoid stale captures.
    private func moveExerciseById(_ id: String, direction: Int) {
        guard let index = draft.exercises.firstIndex(where: { $0.id == id }) else { return }
        let target = index + direction
        guard draft.exercises.indices.contains(target) else { return }
        Haptics.selection()
        withAnimation(.xomConfident) {
            draft.exercises.swapAt(index, target)
        }
        markDirty()
    }

    private func markDirty() {
        if !hasUnsavedChanges { hasUnsavedChanges = true }
        saveError = nil

        // Auto-save custom templates so reordering persists immediately
        if draft.isCustom {
            autoSave()
        }
    }

    /// Quietly saves changes to custom templates without UI feedback.
    private func autoSave() {
        var updated = draft
        updated.estimatedDuration = estimatedDuration
        TemplateService.shared.saveCustomTemplate(updated)
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
            let reps = parseFirstReps(tex.targetReps)
            let sets: [WorkoutSet] = (0..<tex.targetSets).map { _ in
                WorkoutSet(
                    id: UUID().uuidString,
                    exerciseId: tex.exercise.id,
                    weight: 0,
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
            // Pass the edited template directly — weight prefill is handled by
            // WorkoutLoggerViewModel using last-set lookup for each exercise.
            let edited = draft
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                workoutSession.startFromTemplate(edited, userId: userId)
                workoutSession.isPresented = true
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

private struct TemplateExerciseRow: View {
    let index: Int
    let exercise: WorkoutTemplate.TemplateExercise
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Index badge
            Text("\(index)")
                .font(.caption.weight(.bold).monospaced())
                .foregroundStyle(Theme.accent)
                .frame(width: 24, height: 24)
                .background(Theme.accent.opacity(0.15))
                .clipShape(.rect(cornerRadius: 6))

            // Exercise name
            Text(exercise.exercise.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Sets x Reps display
            Text("\(exercise.targetSets) × \(exercise.targetReps.isEmpty ? "8-12" : exercise.targetReps)")
                .font(.subheadline.monospaced())
                .foregroundStyle(Theme.textSecondary)

            // Action buttons
            HStack(spacing: 0) {
                if canMoveUp {
                    Button {
                        onMoveUp()
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Move up")
                }

                if canMoveDown {
                    Button {
                        onMoveDown()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Move down")
                }

                Button {
                    Haptics.light()
                    onDelete()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete")
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
        .contentShape(Rectangle())
    }
}
