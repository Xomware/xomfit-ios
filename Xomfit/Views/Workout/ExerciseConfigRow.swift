import SwiftUI

/// Horizontally scrollable rows of config pills for grip, attachment, position, and laterality.
/// Shared between ExerciseCard (list mode) and WorkoutFocusView (focus mode).
struct ExerciseConfigRow: View {
    let exercise: WorkoutExercise
    let onGripChanged: (GripType) -> Void
    let onAttachmentChanged: (CableAttachment) -> Void
    let onPositionChanged: (ExercisePosition) -> Void
    var onLateralityChanged: ((Laterality) -> Void)? = nil
    /// Optional notes handler. Pass nil/empty to clear. When omitted, the notes pill is hidden.
    var onNotesChanged: ((String?) -> Void)? = nil
    /// Optional per-exercise rest override handler. Pass nil to clear (use global). When omitted,
    /// the rest pill is hidden.
    var onRestSecondsChanged: ((Int?) -> Void)? = nil
    /// Global default surfaced inside the rest sheet so the user can compare/reset.
    /// Defaults to 90s — the same fallback used by `WorkoutLoggerViewModel`.
    var defaultRestSeconds: Int = 90

    @State private var showNotesSheet = false
    @State private var showRestSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.tight) {
            if let grips = exercise.exercise.supportedGrips {
                configSection(label: "Grip") {
                    ForEach(grips) { grip in
                        configPill(
                            label: grip.displayName,
                            isSelected: exercise.selectedGrip == grip
                        ) { onGripChanged(grip) }
                    }
                }
            }
            if let attachments = exercise.exercise.supportedAttachments {
                configSection(label: "Attachment") {
                    ForEach(attachments) { attachment in
                        configPill(
                            label: attachment.displayName,
                            isSelected: exercise.selectedAttachment == attachment
                        ) { onAttachmentChanged(attachment) }
                    }
                }
            }
            if let positions = exercise.exercise.supportedPositions {
                configSection(label: "Position") {
                    ForEach(positions) { position in
                        configPill(
                            label: position.displayName,
                            isSelected: exercise.selectedPosition == position
                        ) { onPositionChanged(position) }
                    }
                }
            }
            if exercise.exercise.supportsUnilateral, let lateralityHandler = onLateralityChanged {
                configSection(label: "Laterality") {
                    ForEach(Laterality.allCases) { lat in
                        configPill(
                            label: lat.displayName,
                            isSelected: exercise.selectedLaterality == lat
                        ) { lateralityHandler(lat) }
                    }
                }
            }

            // Notes + rest extras row — only rendered when at least one handler is wired up.
            if onNotesChanged != nil || onRestSecondsChanged != nil {
                extrasRow
            }
        }
        .sheet(isPresented: $showNotesSheet) {
            if let onNotesChanged {
                ExerciseNotesSheet(
                    exerciseName: exercise.exercise.name,
                    initialNotes: exercise.notes ?? "",
                    onSave: { onNotesChanged($0) }
                )
                .presentationDetents([.medium, .large])
            }
        }
        .sheet(isPresented: $showRestSheet) {
            if let onRestSecondsChanged {
                ExerciseRestSheet(
                    exerciseName: exercise.exercise.name,
                    initialRestSeconds: exercise.restSeconds ?? defaultRestSeconds,
                    isCustomized: exercise.restSeconds != nil,
                    defaultRestSeconds: defaultRestSeconds,
                    onSave: { onRestSecondsChanged($0) }
                )
                .presentationDetents([.medium])
            }
        }
    }

    // MARK: - Extras Row (Notes + Rest)

    private var extrasRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if onNotesChanged != nil {
                    notesPill
                }
                if onRestSecondsChanged != nil {
                    restPill
                }
            }
        }
    }

    private var notesPill: some View {
        let hasNote = (exercise.notes?.isEmpty == false)
        return Button {
            Haptics.selection()
            showNotesSheet = true
        } label: {
            HStack(spacing: Theme.Spacing.tight) {
                Image(systemName: hasNote ? "note.text" : "plus")
                    .font(.caption2.weight(.semibold))
                if hasNote, let preview = notePreview(exercise.notes) {
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
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(hasNote ? "Edit note: \(exercise.notes ?? "")" : "Add note")
        .accessibilityHint("Opens the per-exercise note editor")
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
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Rest \(formatRest(seconds))\(isCustom ? ", custom" : ", default")")
        .accessibilityHint("Adjusts rest time for this exercise")
    }

    private func notePreview(_ notes: String?) -> String? {
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

    // MARK: - Section / Pill helpers

    private func configSection<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.textSecondary)
                    .textCase(.uppercase)
                content()
            }
        }
    }

    private func configPill(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isSelected ? .black : Theme.textSecondary)
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, Theme.Spacing.tight)
                .background(isSelected ? Theme.accent : Theme.surfaceSecondary)
                .clipShape(.capsule)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Notes Sheet

/// Sheet with a TextEditor for editing per-exercise notes.
/// Caps input at 500 characters and shows a live counter.
struct ExerciseNotesSheet: View {
    let exerciseName: String
    let initialNotes: String
    let onSave: (String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""
    @FocusState private var editorFocused: Bool

    private static let maxLength = 500

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    Text("Notes for this exercise stay with the workout — perfect for form cues, weight setups, or how it felt.")
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)

                    TextEditor(text: $text)
                        .font(Theme.fontBody)
                        .foregroundStyle(Theme.textPrimary)
                        .scrollContentBackground(.hidden)
                        .padding(Theme.Spacing.sm)
                        .frame(minHeight: 140, maxHeight: 240)
                        .background(Theme.surface)
                        .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                                .stroke(Theme.textSecondary.opacity(0.2), lineWidth: 1)
                        )
                        .focused($editorFocused)
                        .onChange(of: text) { _, newValue in
                            if newValue.count > Self.maxLength {
                                text = String(newValue.prefix(Self.maxLength))
                            }
                        }

                    HStack {
                        Spacer()
                        Text("\(text.count) / \(Self.maxLength)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(text.count >= Self.maxLength ? Theme.destructive : Theme.textSecondary)
                            .accessibilityLabel("\(text.count) of \(Self.maxLength) characters used")
                    }

                    Spacer()
                }
                .padding(Theme.Spacing.md)
            }
            .navigationTitle(exerciseName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.accent)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Haptics.success()
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(trimmed.isEmpty ? nil : trimmed)
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.accent)
                }
            }
        }
        .onAppear {
            text = initialNotes
            // Defer focus a tick so the sheet can settle before the keyboard slides up.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                editorFocused = true
            }
        }
    }
}

// MARK: - Rest Sheet

/// Sheet with a slider for picking a per-exercise rest override (60-600s in 30s steps).
struct ExerciseRestSheet: View {
    let exerciseName: String
    let initialRestSeconds: Int
    let isCustomized: Bool
    let defaultRestSeconds: Int
    let onSave: (Int?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var seconds: Double = 90

    private static let minSeconds: Double = 60
    private static let maxSeconds: Double = 600
    private static let step: Double = 30

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    Text("Override the workout's default rest just for this exercise. Range: 1m–10m in 30s steps.")
                        .font(Theme.fontCaption)
                        .foregroundStyle(Theme.textSecondary)

                    VStack(spacing: Theme.Spacing.sm) {
                        Text(formatRest(Int(seconds)))
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.accent)
                            .accessibilityLabel("Rest \(formatRest(Int(seconds)))")

                        Slider(
                            value: $seconds,
                            in: Self.minSeconds...Self.maxSeconds,
                            step: Self.step
                        ) {
                            Text("Rest seconds")
                        }
                        .tint(Theme.accent)
                        .onChange(of: seconds) { _, _ in
                            Haptics.selection()
                        }

                        HStack {
                            Text(formatRest(Int(Self.minSeconds)))
                            Spacer()
                            Text(formatRest(Int(Self.maxSeconds)))
                        }
                        .font(.caption2.monospaced())
                        .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(Theme.Spacing.md)
                    .frame(maxWidth: .infinity)
                    .background(Theme.surface)
                    .clipShape(.rect(cornerRadius: Theme.cornerRadius))

                    if isCustomized {
                        Button {
                            Haptics.medium()
                            onSave(nil)
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.uturn.backward")
                                Text("Reset to default (\(formatRest(defaultRestSeconds)))")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .foregroundStyle(Theme.destructive)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Theme.destructive.opacity(0.1))
                            .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Reset rest to default \(formatRest(defaultRestSeconds))")
                    } else {
                        Text("Default: \(formatRest(defaultRestSeconds))")
                            .font(Theme.fontCaption)
                            .foregroundStyle(Theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }

                    Spacer()
                }
                .padding(Theme.Spacing.md)
            }
            .navigationTitle(exerciseName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.accent)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Haptics.success()
                        onSave(Int(seconds))
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.accent)
                }
            }
        }
        .onAppear {
            // Snap initial value onto the slider step grid.
            let snapped = (Double(initialRestSeconds) / Self.step).rounded() * Self.step
            seconds = min(max(snapped, Self.minSeconds), Self.maxSeconds)
        }
    }

    private func formatRest(_ seconds: Int) -> String {
        if seconds >= 60 && seconds % 60 == 0 { return "\(seconds / 60)m" }
        if seconds < 60 { return "\(seconds)s" }
        let m = seconds / 60
        let s = seconds % 60
        return "\(m)m \(s)s"
    }
}
