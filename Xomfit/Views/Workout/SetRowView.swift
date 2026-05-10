import SwiftUI

struct SetRowView: View {
    let setNumber: Int
    let workoutSet: WorkoutSet
    let onWeightChange: (Double) -> Void
    let onRepsChange: (Int) -> Void
    let onComplete: () -> Void
    let onDelete: () -> Void
    let onToggleWeightMode: () -> Void
    let onAddDropSet: (() -> Void)?
    var lateralityLabel: String? = nil
    /// Most recent set the user has logged for this exercise from history.
    /// Drives the "Last: 135×8" hint below the row. nil = first time doing this exercise.
    var lastSet: WorkoutSet? = nil
    /// Heaviest set the user has ever logged for this exercise (history only).
    /// Drives the "PR: 145×6" hint and the inline "NEW PR" badge when beat.
    var personalRecord: WorkoutSet? = nil

    @State private var weightText: String
    @State private var repsText: String
    @FocusState private var isWeightFocused: Bool
    @FocusState private var isRepsFocused: Bool
    /// Confirmation dialog presented after long-pressing the weight field.
    @State private var showWeightActions: Bool = false
    /// Plate calculator sheet, opened from the weight field action sheet.
    @State private var showPlateCalculator: Bool = false

    /// Display-only weight unit. Edits stay in lbs internally regardless.
    @AppStorage("weightUnit") private var weightUnitRaw: String = WeightUnit.lbs.rawValue
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .lbs }

    private var isCompleted: Bool {
        workoutSet.completedAt != Date.distantPast
    }

    private var isPR: Bool {
        workoutSet.isPersonalRecord
    }

    private var isDropSet: Bool {
        workoutSet.isDropSet
    }

    /// Live "did this completed set just beat the prior PR?" check.
    /// Compares against the historical PR (passed in), so we don't false-positive
    /// after PRService flips `isPersonalRecord` on the row itself.
    private var beatsPriorPR: Bool {
        guard isCompleted, workoutSet.weight > 0, workoutSet.reps > 0 else { return false }
        guard let pr = personalRecord else { return false } // unknown history -> don't celebrate
        if workoutSet.weight > pr.weight { return true }
        if workoutSet.weight == pr.weight && workoutSet.reps > pr.reps { return true }
        return false
    }

    /// True when we have at least one of last / PR to surface as a subtitle.
    private var hasHints: Bool {
        lastSet != nil || personalRecord != nil
    }

    init(
        setNumber: Int,
        workoutSet: WorkoutSet,
        onWeightChange: @escaping (Double) -> Void,
        onRepsChange: @escaping (Int) -> Void,
        onComplete: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onToggleWeightMode: @escaping () -> Void = {},
        onAddDropSet: (() -> Void)? = nil,
        lateralityLabel: String? = nil,
        lastSet: WorkoutSet? = nil,
        personalRecord: WorkoutSet? = nil
    ) {
        self.setNumber = setNumber
        self.workoutSet = workoutSet
        self.onWeightChange = onWeightChange
        self.onRepsChange = onRepsChange
        self.onComplete = onComplete
        self.onDelete = onDelete
        self.onToggleWeightMode = onToggleWeightMode
        self.onAddDropSet = onAddDropSet
        self.lateralityLabel = lateralityLabel
        self.lastSet = lastSet
        self.personalRecord = personalRecord

        let w = workoutSet.weight
        let r = workoutSet.reps
        _weightText = State(initialValue: w > 0 ? w.formattedWeight : "")
        _repsText   = State(initialValue: r > 0 ? "\(r)" : "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            mainRow
            if hasHints || beatsPriorPR {
                hintRow
            }
            if isCompleted, !isDropSet, let onAddDropSet {
                addDropSetButton(onAddDropSet)
            }
        }
        .padding(.leading, isDropSet ? Theme.Spacing.lg : 0)
        .frame(minHeight: isDropSet ? 44 : 52)
        .background(isCompleted ? Theme.accent.opacity(0.08) : Color.clear)
        .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
        .animation(nil, value: workoutSet.completedAt)
        .onChange(of: workoutSet.weight) { _, newWeight in
            let formatted = newWeight > 0 ? newWeight.formattedWeight : ""
            if weightText != formatted { weightText = formatted }
        }
        .onChange(of: workoutSet.reps) { _, newReps in
            let formatted = newReps > 0 ? "\(newReps)" : ""
            if repsText != formatted { repsText = formatted }
        }
        .confirmationDialog("Weight", isPresented: $showWeightActions, titleVisibility: .hidden) {
            Button("Plate Calculator") {
                showPlateCalculator = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showPlateCalculator) {
            PlateCalculatorView(initialTargetWeight: Double(weightText))
                .presentationDetents([.large])
        }
    }

    // MARK: - Main row (weight / reps / complete)

    private var mainRow: some View {
        HStack(spacing: 0) {
            // PR indicator: 3pt gold leading stripe (only when it's a PR)
            if isPR {
                Rectangle()
                    .fill(Theme.prGold)
                    .frame(width: 3)
                    .clipShape(.rect(topLeadingRadius: 3, bottomLeadingRadius: 3))
            }

            HStack(spacing: Theme.Spacing.sm) {
                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(Theme.destructive)
                        .font(isDropSet ? .subheadline : .headline)
                }
                .buttonStyle(.plain)
                .frame(width: 30)
                .accessibilityLabel("Delete set \(setNumber)")

                // PR trophy / DROP badge / set number
                if isPR {
                    Image(systemName: "trophy.fill")
                        .font(.caption2)
                        .foregroundStyle(Theme.prGold)
                        .frame(width: 16)
                } else if isDropSet {
                    Text("DROP")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Theme.accent.opacity(0.18))
                        .clipShape(.capsule)
                } else {
                    Text("\(setNumber)")
                        .font(.subheadline.weight(.bold).monospaced())
                        .foregroundStyle(isCompleted ? Theme.accent : Theme.textSecondary)
                        .frame(width: 24, alignment: .center)
                }

                // Weight field
                TextField("0", text: $weightText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(isDropSet ? .footnote.weight(.semibold).monospacedDigit() : Theme.fontNumberMedium)
                    .padding(.vertical, isDropSet ? 6 : 8)
                    .padding(.horizontal, 6)
                    .background(Theme.surfaceElevated)
                    .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                            .strokeBorder(isWeightFocused ? Theme.hairlineStrong : Theme.hairline, lineWidth: 0.5)
                    )
                    .foregroundStyle(isCompleted ? Theme.accent : Theme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .focused($isWeightFocused)
                    .onChange(of: weightText) { _, newValue in
                        if let w = Double(newValue) {
                            onWeightChange(w)
                        }
                    }
                    // Long-press surfaces the plate calculator without breaking text input.
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.45)
                            .onEnded { _ in
                                Haptics.medium()
                                isWeightFocused = false
                                showWeightActions = true
                            }
                    )
                    .accessibilityAction(named: Text("Plate Calculator")) {
                        showWeightActions = true
                    }

                Button(action: onToggleWeightMode) {
                    Text(workoutSet.weightMode == .perSide ? "\(weightUnit.displayName) ×2  ×" : "\(weightUnit.displayName)  ×")
                        .font(Theme.fontCaption)
                        .foregroundStyle(workoutSet.weightMode == .perSide ? Theme.accent : Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(workoutSet.weightMode == .perSide ? "Per side weight, tap to switch to total" : "Total weight, tap to switch to per side")

                // Reps field
                TextField("0", text: $repsText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(isDropSet ? .footnote.weight(.semibold).monospacedDigit() : Theme.fontNumberMedium)
                    .padding(.vertical, isDropSet ? 6 : 8)
                    .padding(.horizontal, 6)
                    .background(Theme.surfaceElevated)
                    .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                            .strokeBorder(isRepsFocused ? Theme.hairlineStrong : Theme.hairline, lineWidth: 0.5)
                    )
                    .foregroundStyle(isCompleted ? Theme.accent : Theme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .focused($isRepsFocused)
                    .onChange(of: repsText) { _, newValue in
                        if let r = Int(newValue) {
                            onRepsChange(r)
                        }
                    }

                if let label = lateralityLabel {
                    Text(label)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 30)
                }

                // Complete checkmark
                Button(action: {
                    Haptics.success()
                    onComplete()
                }) {
                    ZStack {
                        Circle()
                            .fill(isCompleted ? Theme.accent : Theme.surfaceElevated)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle().strokeBorder(isCompleted ? Color.clear : Theme.hairlineStrong, lineWidth: 0.5)
                            )
                        if isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.black)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isCompleted ? "Mark set \(setNumber) incomplete" : "Complete set \(setNumber)")
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, isDropSet ? 4 : 6)
        }
    }

    // MARK: - Hint row (Last / PR / NEW PR badge)

    private var hintRow: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // align under the weight/reps fields, past the delete + set number columns
            Spacer().frame(width: 30 + Theme.Spacing.sm + 24)

            if let last = lastSet, last.weight > 0, last.reps > 0 {
                hintChip(
                    label: "Last",
                    value: "\(last.weight.formattedWeight(unit: weightUnit))×\(last.reps)",
                    color: Theme.textSecondary
                )
            }

            if let pr = personalRecord, pr.weight > 0, pr.reps > 0 {
                hintChip(
                    label: "PR",
                    value: "\(pr.weight.formattedWeight(unit: weightUnit))×\(pr.reps)",
                    color: Theme.prGold
                )
            }

            if beatsPriorPR {
                Text("NEW PR")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.prGold)
                    .clipShape(.capsule)
                    .accessibilityLabel("New personal record")
            }

            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.bottom, 4)
    }

    private func hintChip(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.textTertiary)
            Text(value)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value)")
    }

    // MARK: - Drop set button

    private func addDropSetButton(_ action: @escaping () -> Void) -> some View {
        Button {
            Haptics.light()
            action()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.down.right")
                    .font(.caption2.weight(.bold))
                Text("drop set")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Theme.accent.opacity(0.10))
            .clipShape(.capsule)
        }
        .buttonStyle(.plain)
        .padding(.leading, Theme.Spacing.xl + 30)
        .accessibilityLabel("Add drop set after set \(setNumber)")
    }
}
