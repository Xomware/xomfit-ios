import SwiftUI

struct WorkoutDetailView: View {
    let workout: Workout
    /// Called after a successful edit-mode save (#365) so the parent list can
    /// refresh and reflect the new name/sets/etc. Optional — existing call
    /// sites that haven't migrated still compile.
    var onUpdated: (() async -> Void)? = nil

    @Environment(AuthService.self) private var authService
    @Environment(WorkoutLoggerViewModel.self) private var workoutSession

    /// Edit mode (#365). When `true` the read-only summary/exercise cards are
    /// swapped for editable forms, and the toolbar surfaces Cancel / Save in
    /// place of the share button.
    @State private var isEditing = false
    /// View model owning the editable draft of `workout` while in edit mode.
    /// Lazily seeded from `workout` the first time the user taps the pencil.
    @State private var editVM: WorkoutDetailViewModel?
    /// Confirmation dialog presented when the user taps Cancel with unsaved changes.
    @State private var showDiscardAlert = false
    /// Exercise picker presented from the Add Exercise button in edit mode.
    @State private var showExercisePicker = false

    /// Image rendered for sharing (#320). Held while the share sheet is presented
    /// so `UIActivityViewController` doesn't see a stale image.
    @State private var shareImage: UIImage?

    // MARK: - Warmup gating (#337)
    //
    // "Start this Workout" mirrors the gate used on `WorkoutView`/`WorkoutCategoryListView`:
    // build a fresh template from the recorded exercises, then either ask, present
    // the warmup, or start immediately based on the user's saved preference.

    @AppStorage("warmupOptIn") private var warmupOptIn: String = ""
    @AppStorage("warmupMinutes") private var warmupMinutes: Int = 6

    @State private var pendingStart: (() -> Void)?
    @State private var pendingStretches: [Stretch] = []
    /// Exercises captured at start-flow time so the warmup preview can render
    /// "why this stretch" captions (#349).
    @State private var pendingExercises: [Exercise] = []
    @State private var showWarmupPrompt = false
    @State private var showWarmup = false

    /// Currently-presented exercise for the form details sheet (#349). Driven by
    /// the info button on each exercise row — mirrors `WorkoutBuilderView` and
    /// `TemplateDetailView` so info is reachable from every workout surface.
    @State private var exerciseForDetail: Exercise?

    private var userId: String {
        authService.currentUser?.id.uuidString.lowercased() ?? ""
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                if isEditing, let editVM {
                    WorkoutDetailEditBody(viewModel: editVM, onAddExercise: {
                        Haptics.light()
                        showExercisePicker = true
                    })
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .padding(.bottom, Theme.Spacing.xxl)
                } else {
                    VStack(spacing: Theme.Spacing.md) {
                        summaryCard
                        exerciseList
                        soundtrackSection
                        startThisWorkoutButton
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle(isEditing ? "Edit Workout" : workout.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isEditing)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .hideTabBar()
        .toolbar {
            if isEditing, let editVM {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if editVM.hasChanges {
                            showDiscardAlert = true
                        } else {
                            exitEditMode()
                        }
                    }
                    .foregroundStyle(Theme.accent)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await commitSave() }
                    } label: {
                        if editVM.isSaving {
                            ProgressView().tint(Theme.accent)
                        } else {
                            Text("Save").fontWeight(.bold)
                        }
                    }
                    .foregroundStyle(editVM.canSave ? Theme.accent : Theme.textSecondary)
                    .disabled(!editVM.canSave || editVM.isSaving)
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
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Button {
                            Haptics.light()
                            enterEditMode()
                        } label: {
                            Image(systemName: "pencil")
                                .foregroundStyle(Theme.accent)
                        }
                        .accessibilityLabel("Edit workout")

                        Button {
                            Haptics.light()
                            shareImage = WorkoutImageRenderer.render(workout: workout)
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(Theme.accent)
                        }
                        .accessibilityLabel("Share workout as image")
                    }
                }
            }
        }
        .sheet(isPresented: $showExercisePicker) {
            ExercisePickerView { exercise in
                editVM?.addExercise(exercise)
            }
        }
        .alert("Discard changes?", isPresented: $showDiscardAlert) {
            Button("Discard", role: .destructive) {
                editVM?.cancel()
                exitEditMode()
            }
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("Your edits to this workout will be lost.")
        }
        .sheet(item: Binding(
            get: { shareImage.map { ShareImageWrapper(image: $0) } },
            set: { shareImage = $0?.image }
        )) { wrapper in
            WorkoutShareSheet(image: wrapper.image)
                .presentationDetents([.medium, .large])
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
                totalDuration: warmupMinutes * 60,
                exercises: pendingExercises
            ) {
                runPendingStartImmediately()
            }
        }
        .sheet(item: $exerciseForDetail) { exercise in
            ExerciseDetailSheet(exercise: exercise)
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.tight) {
                    Text(workout.startTime.workoutDateString)
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)

                    if let endTime = workout.endTime {
                        Text(timeRangeString(start: workout.startTime, end: endTime))
                            .font(Theme.fontSmall)
                            .foregroundStyle(Theme.textSecondary)
                    }

                    if let location = workout.location, !location.isEmpty {
                        HStack(spacing: Theme.Spacing.tight) {
                            Image(systemName: "location.fill")
                                .font(Theme.fontCaption2)
                            Text(location)
                                .font(Theme.fontSmall)
                        }
                        .foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer()

                if let rating = workout.rating, rating > 0 {
                    HStack(spacing: Theme.Spacing.tighter) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(Theme.fontCaption)
                                .foregroundStyle(star <= rating ? Theme.accent : Theme.textSecondary.opacity(0.3))
                        }
                    }
                }
                Text(workout.durationString)
                    .font(.subheadline.weight(.bold).monospaced())
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.accent.opacity(0.12))
                    .clipShape(.rect(cornerRadius: 8))
            }

            HStack(spacing: 0) {
                summaryStatView(value: "\(workout.exercises.count)", label: "Exercises")
                Spacer()
                summaryStatView(value: "\(workout.totalSets)", label: "Sets")
                Spacer()
                summaryStatView(value: "\(workout.formattedVolume) lbs", label: "Volume")
                if workout.totalPRs > 0 {
                    Spacer()
                    summaryStatView(value: "\(workout.totalPRs)", label: "PRs", highlight: true)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(summaryStatsAccessibility)

            if !workout.muscleGroups.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(workout.muscleGroups, id: \.self) { mg in
                            XomBadge(mg.displayName, variant: .secondary)
                        }
                    }
                }
            }

            if let notes = workout.notes, !notes.isEmpty {
                HStack {
                    Image(systemName: "note.text")
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)
                    Text(notes)
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }

    // MARK: - Exercise List

    private var exerciseList: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { index, exercise in
                exerciseCard(exercise: exercise, index: index + 1)
            }
        }
    }

    private func exerciseCard(exercise: WorkoutExercise, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 0) {
                    // Column headers
                    HStack(spacing: 0) {
                        Text("SET")
                            .frame(width: 36, alignment: .leading)
                        Text("WEIGHT")
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        Text("REPS")
                            .frame(width: 50, alignment: .trailing)
                        Text("VOL")
                            .frame(width: 70, alignment: .trailing)
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, Theme.Spacing.sm)

                    // Set rows
                    ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { setIndex, workoutSet in
                        setRow(set: workoutSet, number: setIndex + 1)
                    }
                }
            } label: {
                VStack(alignment: .leading, spacing: Theme.Spacing.tight) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Text("\(index)")
                            .font(.caption.weight(.bold).monospaced())
                            .foregroundStyle(Theme.accent)
                            .frame(width: Theme.Spacing.lg, height: Theme.Spacing.lg)
                            .background(Theme.accent.opacity(0.12))
                            .clipShape(.rect(cornerRadius: 6))

                        Text(exercise.exercise.name)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.textPrimary)

                        // Info button (#349) — opens the standard ExerciseDetailSheet
                        // so the user can check form from the workout history view.
                        // Wrapped in a Button with .buttonStyle(.plain) so it doesn't
                        // collide with the DisclosureGroup's tap-to-expand gesture.
                        Button {
                            Haptics.selection()
                            exerciseForDetail = exercise.exercise
                        } label: {
                            Image(systemName: "info.circle")
                                .font(Theme.fontCaption)
                                .foregroundStyle(Theme.textSecondary)
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Show details for \(exercise.exercise.name)")

                        Spacer()

                        Text("\(exercise.sets.count) sets")
                            .font(Theme.fontCaption)
                            .foregroundStyle(Theme.textSecondary)

                        if exercise.sets.contains(where: { $0.isPersonalRecord }) {
                            HStack(spacing: 3) {
                                Image(systemName: "trophy.fill")
                                    .font(Theme.fontCaption2)
                                Text("PR")
                                    .font(.caption2.weight(.bold))
                            }
                            .foregroundStyle(Theme.prGold)
                        }
                    }

                    // Quoted note preview — surfaces the per-exercise note inline so the
                    // user sees their context without expanding the disclosure.
                    if let notes = exercise.notes, !notes.isEmpty {
                        HStack(alignment: .top, spacing: 6) {
                            // Indent to roughly align with the exercise name (past the index badge).
                            Spacer().frame(width: 24 + Theme.Spacing.sm)
                            Rectangle()
                                .fill(Theme.accent.opacity(0.6))
                                .frame(width: Theme.Spacing.tighter)
                            Text(notes)
                                .font(Theme.fontSmall)
                                .italic()
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                        .accessibilityLabel("Note: \(notes)")
                    }
                }
            }
            .tint(Theme.accent)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }

    private func setRow(set: WorkoutSet, number: Int) -> some View {
        HStack(spacing: 0) {
            Text("\(number)")
                .frame(width: 36, alignment: .leading)
                .foregroundStyle(Theme.textSecondary)

            Text(formatWeight(set.weight))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .foregroundStyle(Theme.textPrimary)

            Text("\(set.reps)")
                .frame(width: 50, alignment: .trailing)
                .foregroundStyle(Theme.textPrimary)

            Text(formatWeight(set.volume))
                .frame(width: 70, alignment: .trailing)
                .foregroundStyle(Theme.textSecondary)

            if set.isPersonalRecord {
                Image(systemName: "trophy.fill")
                    .font(Theme.fontCaption2)
                    .foregroundStyle(Theme.prGold)
                    .padding(.leading, 6)
            }
        }
        .font(.subheadline.weight(.medium).monospaced())
        .padding(.vertical, Theme.Spacing.tight)
        .accessibilityLabel("Set \(number): \(formatWeight(set.weight)) lbs for \(set.reps) reps\(set.isPersonalRecord ? ", personal record" : "")")
    }

    // MARK: - Soundtrack

    /// Apple Music-only Now Playing capture (#302). See `NowPlayingService` for the iOS
    /// platform restriction explaining why Spotify / Xomify won't ever appear here.
    @ViewBuilder
    private var soundtrackSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "music.note")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                Text("Soundtrack")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if !workout.tracks.isEmpty {
                    Text("\(workout.tracks.count)")
                        .font(.caption.weight(.semibold).monospaced())
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            if workout.tracks.isEmpty {
                Text("No tracks captured. Tip: Now Playing capture works with Apple Music.")
                    .font(Theme.fontSmall)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("No tracks captured during this workout")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(workout.tracks.enumerated()), id: \.element.id) { index, track in
                        soundtrackRow(track: track)
                        if index < workout.tracks.count - 1 {
                            Divider()
                                .background(Theme.textSecondary.opacity(0.15))
                        }
                    }
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }

    private func soundtrackRow(track: WorkoutTrack) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "music.note")
                .font(Theme.fontCaption)
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: Theme.Spacing.tighter) {
                Text(track.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                if let artist = track.artist, !artist.isEmpty {
                    Text(artist)
                        .font(Theme.fontSmall)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.vertical, Theme.Spacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: track))
    }

    private func accessibilityLabel(for track: WorkoutTrack) -> String {
        if let artist = track.artist, !artist.isEmpty {
            return "\(track.title) by \(artist)"
        }
        return track.title
    }

    // MARK: - Start This Workout (#337)

    /// Repeats this workout as a fresh active session — builds a `WorkoutTemplate`
    /// from the recorded exercises/sets, then runs through the standard warmup gate.
    @ViewBuilder
    private var startThisWorkoutButton: some View {
        Button {
            Haptics.medium()
            let template = makeTemplateFromWorkout()
            requestStart(
                stretches: StretchDatabase.suggestedStretches(
                    for: workout,
                    target: TimeInterval(warmupMinutes * 60)
                ),
                exercises: workout.exercises.map(\.exercise)
            ) {
                workoutSession.startFromTemplate(template, userId: userId)
                workoutSession.isPresented = true
            }
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "play.fill")
                Text("Start this Workout")
            }
        }
        .buttonStyle(AccentButtonStyle())
        .accessibilityHint("Builds a fresh workout using these exercises as a template")
        .padding(.top, Theme.Spacing.sm)
    }

    /// Build a fresh `WorkoutTemplate` from this past workout. Target reps are
    /// derived from the most-common reps value across recorded sets; weight is
    /// not stored on the template — `WorkoutLoggerViewModel.startFromTemplate`
    /// will prefill it from the user's last set for that exercise.
    private func makeTemplateFromWorkout() -> WorkoutTemplate {
        let templateExercises: [WorkoutTemplate.TemplateExercise] = workout.exercises.map { we in
            WorkoutTemplate.TemplateExercise(
                id: UUID().uuidString,
                exercise: we.exercise,
                targetSets: max(1, we.sets.count),
                targetReps: modalRepsString(for: we.sets),
                notes: we.notes,
                restSeconds: we.restSeconds
            )
        }

        return WorkoutTemplate(
            id: UUID().uuidString,
            name: workout.name,
            description: "Repeat of \(workout.startTime.workoutDateString)",
            exercises: templateExercises,
            estimatedDuration: Int(workout.duration / 60),
            category: .custom,
            isCustom: true
        )
    }

    /// Picks the most-common reps value across the recorded sets as the target.
    /// Falls back to the first set's reps, then "0" if there are no sets.
    private func modalRepsString(for sets: [WorkoutSet]) -> String {
        guard !sets.isEmpty else { return "0" }
        let counts = Dictionary(sets.map { ($0.reps, 1) }, uniquingKeysWith: +)
        // Prefer the highest-count reps value; break ties on the larger reps
        // count so AMRAP-style sets don't get masked by a single warmup set.
        let mode = counts.max { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value < rhs.value }
            return lhs.key < rhs.key
        }?.key ?? sets[0].reps
        return "\(mode)"
    }

    // MARK: - Warmup gating (#337)

    private func requestStart(stretches: [Stretch], exercises: [Exercise] = [], action: @escaping () -> Void) {
        pendingStart = action
        pendingStretches = stretches
        pendingExercises = exercises

        switch warmupOptIn {
        case "yes":
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                showWarmup = true
            }
        case "no":
            runPendingStartImmediately()
        default:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                showWarmupPrompt = true
            }
        }
    }

    private func runPendingStartImmediately() {
        let action = pendingStart
        pendingStart = nil
        pendingStretches = []
        pendingExercises = []
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            action?()
        }
    }

    // MARK: - Helpers

    private func summaryStatView(value: String, label: String, highlight: Bool = false) -> some View {
        XomStat(value, label: label, iconColor: highlight ? Theme.prGold : Theme.accent)
    }

    /// Combined VoiceOver readout for the summary stat row.
    private var summaryStatsAccessibility: String {
        var parts = [
            "\(workout.exercises.count) exercises",
            "\(workout.totalSets) sets",
            "\(workout.formattedVolume) pounds total volume"
        ]
        if workout.totalPRs > 0 {
            parts.append("\(workout.totalPRs) personal record\(workout.totalPRs == 1 ? "" : "s")")
        }
        return parts.joined(separator: ", ")
    }

    private func formatWeight(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : String(format: "%.1f", value)
    }

    private func timeRangeString(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }

    // MARK: - Edit Mode (#365)

    /// Seeds the edit view model from the current workout and flips into edit mode.
    private func enterEditMode() {
        editVM = WorkoutDetailViewModel(workout: workout)
        withAnimation(.easeInOut(duration: 0.2)) {
            isEditing = true
        }
    }

    /// Drops out of edit mode without persisting. Caller is expected to have
    /// already called `editVM?.cancel()` when discarding pending changes.
    private func exitEditMode() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isEditing = false
        }
        // Clear the draft so the next pencil tap rebuilds it from `workout`.
        editVM = nil
    }

    /// Pushes the draft through `WorkoutDetailViewModel.save` then notifies the
    /// parent list to refresh its data. The parent re-fetch is what makes the
    /// next push into this detail view show the new values — we keep showing
    /// the original `workout` constant here so the read-only view stays stable.
    private func commitSave() async {
        guard let editVM else { return }
        Haptics.medium()
        let ok = await editVM.save()
        if ok {
            Haptics.success()
            await onUpdated?()
            exitEditMode()
        } else {
            Haptics.error()
        }
    }
}

// MARK: - Share Image Wrapper (#320)

/// `Identifiable` wrapper so we can drive `.sheet(item:)` off the rendered image.
private struct ShareImageWrapper: Identifiable {
    let id = UUID()
    let image: UIImage
}

// MARK: - Edit Mode Body (#365)

/// Top-level container for the edit-mode UI. Kept private to this file so the
/// only entry point stays `WorkoutDetailView.isEditing`. Splits the long edit
/// form into a metadata card, a per-exercise list, and an "Add Exercise"
/// affordance so each leaf view stays well under the 100-line guideline.
private struct WorkoutDetailEditBody: View {
    @Bindable var viewModel: WorkoutDetailViewModel
    let onAddExercise: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            WorkoutEditMetadataCard(viewModel: viewModel)
            WorkoutEditExerciseList(viewModel: viewModel)
            addExerciseButton

            if let error = viewModel.errorMessage {
                errorBanner(error)
            }
        }
    }

    private var addExerciseButton: some View {
        Button {
            onAddExercise()
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

// MARK: - Edit Metadata Card

/// Editable workout metadata: name, date+start, end time, location, notes,
/// rating. Mirrors the layout of `LogPastWorkoutView.metadataCard` so users
/// familiar with that flow recognize this one.
private struct WorkoutEditMetadataCard: View {
    @Bindable var viewModel: WorkoutDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            nameField
            dateRow
            locationField
            ratingRow
            notesField
        }
        .padding(Theme.Spacing.md)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            fieldLabel("Name")
            TextField("Workout", text: $viewModel.draft.name)
                .font(Theme.fontBodyEmphasized)
                .foregroundStyle(Theme.textPrimary)
                .padding(Theme.Spacing.sm)
                .background(Theme.surfaceElevated)
                .clipShape(.rect(cornerRadius: Theme.Radius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                        .strokeBorder(Theme.hairline, lineWidth: 0.5)
                )
                .accessibilityLabel("Workout name")
        }
    }

    private var dateRow: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            fieldLabel("Start")
            DatePicker(
                "",
                selection: $viewModel.draft.startTime,
                displayedComponents: [.date, .hourAndMinute]
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .tint(Theme.accent)
            .accessibilityLabel("Workout start time")

            fieldLabel("End")
            DatePicker(
                "",
                selection: Binding(
                    get: { viewModel.endTimeBinding },
                    set: { viewModel.endTimeBinding = $0 }
                ),
                in: viewModel.draft.startTime...,
                displayedComponents: [.date, .hourAndMinute]
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .tint(Theme.accent)
            .accessibilityLabel("Workout end time")

            Text("Duration: \(viewModel.draft.durationString)")
                .font(Theme.fontCaption)
                .foregroundStyle(Theme.textSecondary)
                .accessibilityLabel("Calculated duration: \(viewModel.draft.durationString)")
        }
    }

    private var locationField: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            fieldLabel("Location")
            TextField("e.g. Home gym", text: Binding(
                get: { viewModel.locationBinding },
                set: { viewModel.locationBinding = $0 }
            ))
            .font(Theme.fontBody)
            .foregroundStyle(Theme.textPrimary)
            .padding(Theme.Spacing.sm)
            .background(Theme.surfaceElevated)
            .clipShape(.rect(cornerRadius: Theme.Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .strokeBorder(Theme.hairline, lineWidth: 0.5)
            )
            .accessibilityLabel("Workout location")
        }
    }

    private var ratingRow: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            fieldLabel("Rating")
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        Haptics.selection()
                        // Tap the active star a second time to clear.
                        let current = viewModel.ratingBinding
                        viewModel.ratingBinding = (current == star) ? 0 : star
                    } label: {
                        Image(systemName: star <= viewModel.ratingBinding ? "star.fill" : "star")
                            .font(.title3)
                            .foregroundStyle(star <= viewModel.ratingBinding ? Theme.accent : Theme.textSecondary.opacity(0.4))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(star) star\(star == 1 ? "" : "s")")
                    .accessibilityAddTraits(star <= viewModel.ratingBinding ? .isSelected : [])
                }
                Spacer()
            }
        }
    }

    private var notesField: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            fieldLabel("Notes")
            TextEditor(text: Binding(
                get: { viewModel.notesBinding },
                set: { viewModel.notesBinding = $0 }
            ))
            .font(Theme.fontBody)
            .scrollContentBackground(.hidden)
            .foregroundStyle(Theme.textPrimary)
            .padding(Theme.Spacing.xs)
            .frame(minHeight: 80)
            .background(Theme.surfaceElevated)
            .clipShape(.rect(cornerRadius: Theme.Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .strokeBorder(Theme.hairline, lineWidth: 0.5)
            )
            .accessibilityLabel("Workout notes")
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(Theme.fontCaption)
            .foregroundStyle(Theme.textSecondary)
    }
}

// MARK: - Edit Exercise List

/// Renders each exercise as an editable card with up/down reorder chevrons,
/// per-set weight/reps fields, add/remove set buttons, and a remove-exercise
/// button. Mirrors `PastExerciseCard` from `LogPastWorkoutView`.
private struct WorkoutEditExerciseList: View {
    @Bindable var viewModel: WorkoutDetailViewModel

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            if viewModel.draft.exercises.isEmpty {
                emptyState
            } else {
                ForEach(viewModel.draft.exercises.indices, id: \.self) { index in
                    WorkoutEditExerciseCard(
                        viewModel: viewModel,
                        index: index,
                        isFirst: index == 0,
                        isLast: index == viewModel.draft.exercises.count - 1
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
            Text("No exercises")
                .font(Theme.fontBody)
                .foregroundStyle(Theme.textSecondary)
            Text("Add at least one to save")
                .font(Theme.fontCaption)
                .foregroundStyle(Theme.textSecondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.lg)
    }
}

private struct WorkoutEditExerciseCard: View {
    @Bindable var viewModel: WorkoutDetailViewModel
    let index: Int
    let isFirst: Bool
    let isLast: Bool

    private var exercise: WorkoutExercise {
        viewModel.draft.exercises[index]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            header
            columnHeader
            setList
            addSetButton
        }
        .padding(Theme.Spacing.md)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: exercise.exercise.icon)
                .font(Theme.fontHeadline)
                .foregroundStyle(Theme.accent)
                .frame(width: Theme.Spacing.xl, height: Theme.Spacing.xl)
                .background(Theme.accentMuted)
                .clipShape(.rect(cornerRadius: 8))

            VStack(alignment: .leading, spacing: Theme.Spacing.tighter) {
                Text(exercise.exercise.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(exercise.exercise.muscleGroups.first?.displayName ?? "")
                    .font(Theme.fontSmall)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            reorderControls
            removeButton
        }
    }

    private var reorderControls: some View {
        VStack(spacing: 0) {
            Button {
                Haptics.selection()
                viewModel.moveExerciseUp(index)
            } label: {
                Image(systemName: "chevron.up")
                    .font(Theme.fontCaption.weight(.bold))
                    .foregroundStyle(isFirst ? Theme.textTertiary : Theme.accent)
                    .frame(width: 30, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isFirst)
            .accessibilityLabel("Move \(exercise.exercise.name) up")

            Button {
                Haptics.selection()
                viewModel.moveExerciseDown(index)
            } label: {
                Image(systemName: "chevron.down")
                    .font(Theme.fontCaption.weight(.bold))
                    .foregroundStyle(isLast ? Theme.textTertiary : Theme.accent)
                    .frame(width: 30, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isLast)
            .accessibilityLabel("Move \(exercise.exercise.name) down")
        }
    }

    private var removeButton: some View {
        Button {
            Haptics.light()
            viewModel.removeExercise(at: index)
        } label: {
            Image(systemName: "trash")
                .font(Theme.fontSubheadline)
                .foregroundStyle(Theme.destructive.opacity(0.8))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove \(exercise.exercise.name)")
    }

    private var columnHeader: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text("SET")
                .frame(width: 36, alignment: .center)
            Text("WEIGHT (LBS)")
                .frame(maxWidth: .infinity)
            Text("REPS")
                .frame(maxWidth: .infinity)
            Color.clear.frame(width: Theme.Spacing.xl)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(Theme.textSecondary)
        .padding(.horizontal, Theme.Spacing.xs)
    }

    private var setList: some View {
        VStack(spacing: Theme.Spacing.xs) {
            ForEach(exercise.sets.indices, id: \.self) { setIdx in
                WorkoutEditSetRow(
                    setNumber: setIdx + 1,
                    workoutSet: exercise.sets[setIdx],
                    onWeightChange: { newWeight in
                        let currentReps = viewModel.draft.exercises[index].sets[setIdx].reps
                        viewModel.updateSet(exerciseIndex: index, setIndex: setIdx, weight: newWeight, reps: currentReps)
                    },
                    onRepsChange: { newReps in
                        let currentWeight = viewModel.draft.exercises[index].sets[setIdx].weight
                        viewModel.updateSet(exerciseIndex: index, setIndex: setIdx, weight: currentWeight, reps: newReps)
                    },
                    onDelete: {
                        viewModel.removeSet(exerciseIndex: index, setIndex: setIdx)
                    }
                )
            }
        }
    }

    private var addSetButton: some View {
        Button {
            Haptics.light()
            viewModel.addSet(to: index)
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
}

// MARK: - Edit Set Row

/// Plain weight + reps row used by the edit-mode card. Mirrors `PastSetRow`
/// from `LogPastWorkoutView` — no rest timer, no complete checkmark, just
/// numeric input + a delete affordance.
private struct WorkoutEditSetRow: View {
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
                .padding(.vertical, Theme.Spacing.sm)
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
                .padding(.vertical, Theme.Spacing.sm)
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
                    .font(Theme.fontHeadline)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete set \(setNumber)")
        }
        .frame(minHeight: 44)
    }
}
