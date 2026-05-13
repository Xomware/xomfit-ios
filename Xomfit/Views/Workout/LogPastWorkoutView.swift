import SwiftUI
import PhotosUI

/// Manual data-entry sheet for logging a workout that already happened.
/// No live timer, no rest timer — just date, optional duration, optional name,
/// and a list of exercises with weight/reps for each set.
struct LogPastWorkoutView: View {
    @Environment(AuthService.self) private var authService
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = LogPastWorkoutViewModel()
    @State private var showExercisePicker = false
    @State private var showDiscardAlert = false
    @State private var manualTrackTitle: String = ""
    @State private var manualTrackArtist: String = ""

    private var userId: String {
        authService.currentUser?.id.uuidString.lowercased() ?? ""
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        return NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.md) {
                        metadataCard
                        exerciseList
                        addExerciseButton
                        detailsCard
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
            || !viewModel.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !viewModel.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || viewModel.rating > 0
            || !viewModel.manualTracks.isEmpty
            || !viewModel.photoImages.isEmpty
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
                    .font(Theme.fontBodyEmphasized)
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
                .font(Theme.fontLargeTitle)
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
        .accessibilityLabel("Add exercise to past workout")
    }

    // MARK: - Details Card (rating / location / notes / soundtrack / photos)

    private var detailsCard: some View {
        @Bindable var viewModel = viewModel

        return VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            ratingSection
            locationSection
            notesSection
            soundtrackSection
            photosSection
        }
        .padding(Theme.Spacing.md)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
    }

    private var ratingSection: some View {
        @Bindable var viewModel = viewModel

        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("How was your workout?")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        Haptics.light()
                        withAnimation(.xomChill) {
                            viewModel.rating = viewModel.rating == star ? 0 : star
                        }
                    } label: {
                        Image(systemName: star <= viewModel.rating ? "star.fill" : "star")
                            .font(Theme.fontTitle2)
                            .foregroundStyle(star <= viewModel.rating ? Theme.accent : Theme.textSecondary.opacity(0.4))
                            .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(star) star\(star > 1 ? "s" : "")")
                }
                Spacer()
            }
        }
    }

    private var locationSection: some View {
        @Bindable var viewModel = viewModel

        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Location")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "location.fill")
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textSecondary)
                TextField("Gym name", text: $viewModel.location)
                    .font(Theme.fontBody)
                    .foregroundStyle(Theme.textPrimary)
                    .textInputAutocapitalization(.words)
            }
            .padding(Theme.Spacing.sm)
            .background(Theme.surfaceElevated)
            .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                    .stroke(Theme.textSecondary.opacity(0.2), lineWidth: 1)
            )
        }
    }

    private var notesSection: some View {
        @Bindable var viewModel = viewModel

        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Caption")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("Optional — appears on your feed post.")
                .font(Theme.fontCaption)
                .foregroundStyle(Theme.textSecondary)
            TextEditor(text: $viewModel.notes)
                .font(Theme.fontBody)
                .foregroundStyle(Theme.textPrimary)
                .scrollContentBackground(.hidden)
                .padding(Theme.Spacing.sm)
                .frame(minHeight: 80, maxHeight: 120)
                .background(Theme.surfaceElevated)
                .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                        .stroke(Theme.textSecondary.opacity(0.2), lineWidth: 1)
                )
                .accessibilityLabel("Workout caption")
        }
    }

    private var soundtrackSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Soundtrack")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("Past workouts don't capture Now Playing automatically. Add songs manually.")
                .font(Theme.fontCaption)
                .foregroundStyle(Theme.textSecondary)

            if !viewModel.manualTracks.isEmpty {
                VStack(spacing: Theme.Spacing.xs) {
                    ForEach(Array(viewModel.manualTracks.enumerated()), id: \.element.id) { index, track in
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "music.note")
                                .font(Theme.fontCaption)
                                .foregroundStyle(Theme.accent)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.title)
                                    .font(Theme.fontBody)
                                    .foregroundStyle(Theme.textPrimary)
                                    .lineLimit(1)
                                if let artist = track.artist, !artist.isEmpty {
                                    Text(artist)
                                        .font(Theme.fontCaption)
                                        .foregroundStyle(Theme.textSecondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                            Button {
                                Haptics.light()
                                withAnimation(.xomChill) {
                                    viewModel.removeManualTrack(at: index)
                                }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(Theme.destructive)
                                    .font(Theme.fontSubheadline)
                                    .frame(minWidth: 44, minHeight: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove \(track.title)")
                        }
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, 6)
                        .background(Theme.surfaceElevated)
                        .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
                    }
                }
            }

            VStack(spacing: Theme.Spacing.xs) {
                TextField("Song title", text: $manualTrackTitle)
                    .font(Theme.fontBody)
                    .foregroundStyle(Theme.textPrimary)
                    .textInputAutocapitalization(.words)
                    .padding(Theme.Spacing.sm)
                    .background(Theme.surfaceElevated)
                    .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                            .stroke(Theme.textSecondary.opacity(0.2), lineWidth: 1)
                    )
                TextField("Artist (optional)", text: $manualTrackArtist)
                    .font(Theme.fontBody)
                    .foregroundStyle(Theme.textPrimary)
                    .textInputAutocapitalization(.words)
                    .padding(Theme.Spacing.sm)
                    .background(Theme.surfaceElevated)
                    .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                            .stroke(Theme.textSecondary.opacity(0.2), lineWidth: 1)
                    )
                Button {
                    Haptics.light()
                    withAnimation(.xomChill) {
                        viewModel.addManualTrack(title: manualTrackTitle, artist: manualTrackArtist)
                        manualTrackTitle = ""
                        manualTrackArtist = ""
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("Add Song")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Theme.accent.opacity(0.1))
                    .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
                }
                .disabled(manualTrackTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(manualTrackTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                .accessibilityLabel("Add song to soundtrack")
            }
        }
    }

    private var photosSection: some View {
        @Bindable var viewModel = viewModel

        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Photos")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("Add up to 4 photos from this workout.")
                .font(Theme.fontCaption)
                .foregroundStyle(Theme.textSecondary)

            if !viewModel.photoImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(viewModel.photoImages.indices, id: \.self) { index in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: viewModel.photoImages[index])
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(.rect(cornerRadius: 8))

                                Button {
                                    Haptics.light()
                                    viewModel.removePhoto(at: index)
                                } label: {
                                    // 44pt hit target sits behind the compact glyph so the
                                    // visual stays compact while the touch area meets HIG.
                                    ZStack {
                                        Color.clear
                                            .frame(width: 44, height: 44)
                                        Image(systemName: "xmark.circle.fill")
                                            .font(Theme.fontCaption)
                                            .foregroundStyle(.white)
                                            .shadow(radius: 2)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .offset(x: 14, y: -14)
                                .accessibilityLabel("Remove photo \(index + 1)")
                            }
                        }
                    }
                }
            }

            PhotosPicker(
                selection: $viewModel.selectedPhotos,
                maxSelectionCount: 4,
                matching: .images
            ) {
                HStack(spacing: 6) {
                    Image(systemName: "photo.on.rectangle.angled")
                    Text(viewModel.photoImages.isEmpty ? "Add Photos" : "Change Photos")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, Theme.Spacing.sm)
                .background(Theme.accent.opacity(0.12))
                .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
            }
            .onChange(of: viewModel.selectedPhotos) { _, _ in
                Task { await viewModel.loadPhotos() }
            }
        }
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

                Button {
                    Haptics.light()
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(Theme.fontSubheadline)
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
                Color.clear.frame(width: Theme.Spacing.xl)
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
