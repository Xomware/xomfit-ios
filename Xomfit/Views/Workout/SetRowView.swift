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
    var onMarkDropSet: (() -> Void)? = nil
    var onFillMax: (() -> Void)? = nil
    var onFillMaxPlus5: (() -> Void)? = nil
    var lateralityLabel: String? = nil
    /// Most recent set the user has logged for this exercise from history.
    /// Drives the "Last: 135×8" hint below the row. nil = first time doing this exercise.
    var lastSet: WorkoutSet? = nil
    /// The set in this same position from the last session containing this
    /// exercise. Rendered as the greyed reference column every serious tracker
    /// shows — without it there is nothing telling the lifter whether today's
    /// number is progress. Tapping it copies the values into the row.
    var previousSet: WorkoutSet? = nil
    /// Heaviest set the user has ever logged for this exercise (history only).
    /// Drives the "PR: 145×6" hint and the inline "NEW PR" badge when beat.
    var personalRecord: WorkoutSet? = nil
    /// True when this row is the user's *active* set in the parent exercise —
    /// the first incomplete set (or the last set if everything is complete).
    /// Drives the accent border + tint so the lifter always knows where they
    /// are in list mode (#411 bug 4).
    var isCurrentSet: Bool = false

    @State private var weightText: String
    @State private var repsText: String
    @FocusState private var isWeightFocused: Bool
    @FocusState private var isRepsFocused: Bool
    /// Confirmation dialog presented after long-pressing the weight field.
    @State private var showWeightActions: Bool = false
    /// Plate calculator sheet, opened from the weight field action sheet.
    @State private var showPlateCalculator: Bool = false
    /// Set true right before a *programmatic* `weightText` change (external
    /// weight update or unit switch) so the resulting `onChange(of: weightText)`
    /// doesn't re-store the value — otherwise kg rounding would drift the stored
    /// lbs on every reformat. Only genuine user typing stores. (#470)
    @State private var suppressNextWeightStore: Bool = false

    /// Display weight unit (lbs/kg). Storage is always lbs — this only controls
    /// what the user sees/enters. Persisted app-wide via AppStorage.
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

    /// Background tint based on row state. Completed > current > default.
    /// The current-set tint is a low-alpha accent fill so the row is
    /// unmistakable even when surrounded by similar rows (#411 bug 4).
    private var rowBackground: Color {
        if isCompleted { return Theme.accent.opacity(0.08) }
        if isCurrentSet { return Theme.accent.opacity(0.12) }
        return .clear
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
        onMarkDropSet: (() -> Void)? = nil,
        onFillMax: (() -> Void)? = nil,
        onFillMaxPlus5: (() -> Void)? = nil,
        lateralityLabel: String? = nil,
        lastSet: WorkoutSet? = nil,
        previousSet: WorkoutSet? = nil,
        personalRecord: WorkoutSet? = nil,
        isCurrentSet: Bool = false
    ) {
        self.setNumber = setNumber
        self.workoutSet = workoutSet
        self.onWeightChange = onWeightChange
        self.onRepsChange = onRepsChange
        self.onComplete = onComplete
        self.onDelete = onDelete
        self.onToggleWeightMode = onToggleWeightMode
        self.onAddDropSet = onAddDropSet
        self.onMarkDropSet = onMarkDropSet
        self.onFillMax = onFillMax
        self.onFillMaxPlus5 = onFillMaxPlus5
        self.lateralityLabel = lateralityLabel
        self.lastSet = lastSet
        self.previousSet = previousSet
        self.personalRecord = personalRecord
        self.isCurrentSet = isCurrentSet

        let w = workoutSet.weight
        let r = workoutSet.reps
        // Show the stored lbs value converted into the user's preferred unit.
        // `currentWeightUnit()` reads the same AppStorage key at init time.
        _weightText = State(initialValue: w > 0 ? w.formattedWeight(unit: currentWeightUnit()) : "")
        _repsText   = State(initialValue: r > 0 ? "\(r)" : "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.tighter) {
            mainRow
            if hasHints || beatsPriorPR {
                hintRow
            }
            if isCurrentSet && !isCompleted {
                quickActionButtons
            }
            if isCompleted, !isDropSet, let onAddDropSet {
                addDropSetButton(onAddDropSet)
            }
        }
        .padding(.leading, isDropSet ? Theme.Spacing.lg : 0)
        .frame(minHeight: isDropSet ? 44 : 52)
        // Non-clipping rounded background. Previously `.background(rowBackground)`
        // + `.clipShape(.rect(...))` cropped the row's content to its frame,
        // cutting off the Drop/Max/+5 quick-action row on the active set. A
        // RoundedRectangle fill rounds the corners without clipping, so the
        // row grows (via `minHeight`) to contain its content.
        .background(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall).fill(rowBackground))
        .overlay(
            // Accent border around the active set so the lifter can see which
            // set they're on at a glance in list mode (#411 bug 4). Only
            // applied to incomplete sets — once completed, the green tint
            // already disambiguates it.
            RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                .strokeBorder(
                    isCurrentSet && !isCompleted ? Theme.accent : Color.clear,
                    lineWidth: 1.5
                )
        )
        .animation(nil, value: workoutSet.completedAt)
        .onChange(of: workoutSet.weight) { _, newWeight in
            let formatted = newWeight > 0 ? newWeight.formattedWeight(unit: weightUnit) : ""
            if weightText != formatted {
                suppressNextWeightStore = true
                weightText = formatted
            }
        }
        .onChange(of: weightUnitRaw) { _, _ in
            // Re-render the field in the newly selected unit from the canonical
            // stored lbs value (not from the displayed text, to avoid drift).
            let formatted = workoutSet.weight > 0 ? workoutSet.weight.formattedWeight(unit: weightUnit) : ""
            if weightText != formatted {
                suppressNextWeightStore = true
                weightText = formatted
            }
        }
        .onChange(of: workoutSet.reps) { _, newReps in
            let formatted = newReps > 0 ? "\(newReps)" : ""
            if repsText != formatted { repsText = formatted }
        }
        .confirmationDialog("Weight", isPresented: $showWeightActions, titleVisibility: .hidden) {
            Button("Plate Calculator") {
                showPlateCalculator = true
            }
            // Moved off the row itself — it was costing 44pt of horizontal space
            // per set for a setting that changes once a year, if ever.
            Button("Switch to \(weightUnit == .lbs ? "kg" : "lbs")") {
                Haptics.light()
                weightUnitRaw = (weightUnit == .lbs ? WeightUnit.kg : WeightUnit.lbs).rawValue
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showPlateCalculator) {
            // weightText is in the display unit; the plate calculator works in
            // lbs, so convert the entered value back before seeding it. (#470)
            PlateCalculatorView(initialTargetWeight: Double(weightText).map { $0 / weightUnit.multiplierFromLbs })
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
                // Set deletion lives in the row's context menu (long-press) wired
                // at the call site in `ActiveWorkoutView`. The leading red
                // minus.circle.fill button is gone, and the earlier swipe-to-delete
                // was removed because its `DragGesture` fought the ScrollView pan.
                // Keep a small leading inset so the remaining content stays
                // visually anchored where it was.
                Spacer().frame(width: Theme.Spacing.xs)

                // PR trophy / DROP badge / set number
                if isPR {
                    Image(systemName: "trophy.fill")
                        .font(Theme.fontCaption2)
                        .foregroundStyle(Theme.prGold)
                        .frame(width: Theme.Spacing.md)
                } else if isDropSet {
                    Text("DROP")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, Theme.Spacing.tight)
                        .padding(.vertical, 1)
                        .background(Theme.accent.opacity(0.18))
                        .clipShape(.capsule)
                } else {
                    Text("\(setNumber)")
                        .font(.subheadline.weight(.bold).monospaced())
                        .foregroundStyle(isCompleted ? Theme.accent : Theme.textSecondary)
                        .frame(width: Theme.Spacing.lg, alignment: .center)
                }

                // Previous-session reference. This replaced the per-row lbs/kg
                // toggle, which spent 44pt of a cramped row on a setting nobody
                // changes mid-set — it now lives in the weight field's
                // long-press menu. What belongs here is the number the lifter is
                // actually trying to beat.
                Button {
                    guard let previousSet else { return }
                    Haptics.light()
                    suppressNextWeightStore = true
                    weightText = previousSet.weight > 0
                        ? previousSet.weight.formattedWeight(unit: weightUnit) : ""
                    repsText = previousSet.reps > 0 ? "\(previousSet.reps)" : ""
                    onWeightChange(previousSet.weight)
                    onRepsChange(previousSet.reps)
                } label: {
                    Group {
                        if let previousSet, previousSet.weight > 0 || previousSet.reps > 0 {
                            Text("\(previousSet.weight.formattedWeight(unit: weightUnit))×\(previousSet.reps)")
                                .font(Theme.fontTablePrevious)
                                .foregroundStyle(Theme.textTertiary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        } else {
                            Text("—")
                                .font(Theme.fontTablePrevious)
                                .foregroundStyle(Theme.textTertiary.opacity(0.6))
                        }
                    }
                    .frame(width: 58, alignment: .center)
                    .frame(minHeight: 40)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(previousSet == nil)
                .accessibilityLabel(
                    previousSet.map { "Last time: \($0.weight.formattedWeight) for \($0.reps) reps" }
                        ?? "No previous set"
                )
                .accessibilityHint("Copies last session's numbers into this set")

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
                        // Ignore programmatic reformats (external update / unit
                        // switch) — only persist genuine user edits. (#470)
                        if suppressNextWeightStore {
                            suppressNextWeightStore = false
                            return
                        }
                        if let entered = Double(newValue) {
                            // Convert the entered display-unit value back to lbs
                            // for storage (÷ multiplier; no-op for lbs).
                            onWeightChange(entered / weightUnit.multiplierFromLbs)
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
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(workoutSet.weightMode == .perSide ? "Per side weight" : "Total weight")
                .accessibilityHint(workoutSet.weightMode == .perSide ? "Switches to total weight" : "Switches to per-side weight")

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
            // align under the weight field, past the (now-removed delete column),
            // the leading inset, and the set-number column.
            Spacer().frame(width: Theme.Spacing.xs + Theme.Spacing.sm + Theme.Spacing.lg)

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
                    .padding(.vertical, Theme.Spacing.tighter)
                    .background(Theme.prGold)
                    .clipShape(.capsule)
                    .accessibilityLabel("New personal record")
            }

            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.tight)
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

    // MARK: - Quick action buttons

    @ViewBuilder
    private var quickActionButtons: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Spacer().frame(width: Theme.Spacing.xs + Theme.Spacing.sm + Theme.Spacing.lg)

            if let onMarkDropSet, !isDropSet {
                Button {
                    Haptics.light()
                    onMarkDropSet()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down")
                            .font(.caption2.weight(.bold))
                        Text("Drop")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, 4)
                    .background(Theme.accent.opacity(0.10))
                    .clipShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Mark as drop set")
            }

            if let onFillMax {
                Button {
                    Haptics.light()
                    onFillMax()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "trophy")
                            .font(.caption2.weight(.bold))
                        Text("Max")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, 4)
                    .background(Theme.accent.opacity(0.10))
                    .clipShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Fill with PR weight")
            }

            if let onFillMaxPlus5 {
                Button {
                    Haptics.light()
                    onFillMaxPlus5()
                } label: {
                    Text("+5")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, 4)
                        .background(Theme.accent.opacity(0.10))
                        .clipShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Fill with PR weight plus 5 pounds")
            }

            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.tight)
    }

    // MARK: - Drop set button

    private func addDropSetButton(_ action: @escaping () -> Void) -> some View {
        Button {
            Haptics.light()
            action()
        } label: {
            HStack(spacing: Theme.Spacing.tight) {
                Image(systemName: "arrow.down.right")
                    .font(.caption2.weight(.bold))
                Text("drop set")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, 3)
            .background(Theme.accent.opacity(0.10))
            .clipShape(.capsule)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.leading, Theme.Spacing.xl + Theme.Spacing.xs)
        .accessibilityLabel("Add drop set after set \(setNumber)")
    }
}
