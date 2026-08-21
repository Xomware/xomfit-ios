import SwiftUI

/// Shared column geometry for the set table.
///
/// `SetTableHeader` and `SetRowView` previously hardcoded their own widths and
/// had already drifted apart — the header still reserved a 44pt column for a
/// weight-mode button that no longer exists, so every label sat one column left
/// of the field it named. Both now read from here.
enum SetRowLayout {
    /// Leading inset before the set-number column.
    static let leadingInset: CGFloat = Theme.Spacing.xs
    /// Set number / status glyph column. Wide enough for the "SET" header
    /// without wrapping.
    static let numberWidth: CGFloat = 26
    /// Previous-session reference column.
    static let previousWidth: CGFloat = 58
    /// The "x" separator between weight and reps.
    static let separatorWidth: CGFloat = 10
    /// Trailing complete-checkmark column.
    static let completeWidth: CGFloat = 44
    /// Gap between columns.
    static let columnSpacing: CGFloat = Theme.Spacing.sm
}


struct SetRowView: View {
    let setNumber: Int
    let workoutSet: WorkoutSet
    let onWeightChange: (Double) -> Void
    let onRepsChange: (Int) -> Void
    let onComplete: () -> Void
    let onDelete: () -> Void
    let onToggleWeightMode: () -> Void
    var onMarkDropSet: (() -> Void)? = nil
    var onFillMax: (() -> Void)? = nil
    var onFillMaxPlus5: (() -> Void)? = nil
    /// Fired when the lifter touches this row — taps it, or focuses either
    /// numeric field. Moves the shared workout cursor so list mode and focus
    /// mode agree on "where am I", which is what makes zooming in a resume
    /// rather than a guess.
    var onBecomeActive: (() -> Void)? = nil
    /// Toggles "not doing this one". Skipped sets stop counting as work
    /// remaining and are dropped at save.
    var onToggleSkip: (() -> Void)? = nil
    var lateralityLabel: String? = nil
    /// Most recent set the user has logged for this exercise from history.
    /// Drives the "Last: 135×8" hint on the active row. nil = first time doing this exercise.
    var lastSet: WorkoutSet? = nil
    /// The set in this same position from the last session containing this
    /// exercise. Rendered as the greyed reference column every serious tracker
    /// shows — without it there is nothing telling the lifter whether today's
    /// number is progress. Tapping it copies the values into the row.
    var previousSet: WorkoutSet? = nil
    /// Heaviest set the user has ever logged for this exercise (history only).
    /// Drives the "PR: 145×6" hint and the inline "NEW PR" badge when beat.
    var personalRecord: WorkoutSet? = nil
    /// True when this row is the workout cursor — the set the lifter is on.
    /// Drives the accent border, the tint, and (deliberately) the *only* row
    /// allowed to show the hint/quick-action subline.
    var isCurrentSet: Bool = false

    @State private var weightText: String
    @State private var repsText: String
    @FocusState private var isWeightFocused: Bool
    @FocusState private var isRepsFocused: Bool
    /// Confirmation dialog presented after long-pressing the weight field.
    /// Also now hosts the per-side weight-mode toggle, which used to cost a
    /// permanent 44pt column in a row that had none to spare.
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

    private var isSkipped: Bool {
        workoutSet.isSkipped
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

    /// The hint/quick-action subline renders on the cursor row only.
    ///
    /// It used to render on *every* row that had history, which meant a 4-set
    /// exercise stacked four hint rows plus a quick-action row plus a drop-set
    /// row on top of the four actual set rows. Non-active rows are now exactly
    /// one line tall, which is most of the density win in list mode.
    private var showsSubline: Bool {
        guard !isSkipped else { return false }
        if isCurrentSet && !isCompleted { return true }
        return beatsPriorPR
    }

    /// Background tint based on row state. Completed > current > default.
    /// The current-set tint is a low-alpha accent fill so the row is
    /// unmistakable even when surrounded by similar rows (#411 bug 4).
    private var rowBackground: Color {
        if isSkipped { return .clear }
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
        onMarkDropSet: (() -> Void)? = nil,
        onFillMax: (() -> Void)? = nil,
        onFillMaxPlus5: (() -> Void)? = nil,
        onBecomeActive: (() -> Void)? = nil,
        onToggleSkip: (() -> Void)? = nil,
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
        self.onMarkDropSet = onMarkDropSet
        self.onFillMax = onFillMax
        self.onFillMaxPlus5 = onFillMaxPlus5
        self.onBecomeActive = onBecomeActive
        self.onToggleSkip = onToggleSkip
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
            if showsSubline {
                subline
            }
        }
        .padding(.leading, isDropSet ? Theme.Spacing.lg : 0)
        .frame(minHeight: 44)
        // Non-clipping rounded background. Previously `.background(rowBackground)`
        // + `.clipShape(.rect(...))` cropped the row's content to its frame,
        // cutting off the subline on the active set. A RoundedRectangle fill
        // rounds the corners without clipping, so the row grows (via
        // `minHeight`) to contain its content.
        .background(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall).fill(rowBackground))
        .overlay(
            // Accent border around the active set so the lifter can see which
            // set they're on at a glance in list mode (#411 bug 4). Only
            // applied to incomplete, unskipped sets — once completed the tint
            // already disambiguates it, and a skipped set is not "where you are".
            RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                .strokeBorder(
                    isCurrentSet && !isCompleted && !isSkipped ? Theme.accent : Color.clear,
                    lineWidth: 1.5
                )
        )
        // Skipped sets stay legible but visibly out of play.
        .opacity(isSkipped ? 0.4 : 1)
        .animation(.xomSnappy, value: isSkipped)
        .animation(nil, value: workoutSet.completedAt)
        .contentShape(Rectangle())
        .onTapGesture {
            // Tap anywhere on the row to make it the cursor. A plain tap
            // recognizer (no drag) yields to the ScrollView pan, unlike the
            // custom DragGestures this file has twice had to remove.
            onBecomeActive?()
        }
        .onChange(of: isWeightFocused) { _, focused in
            if focused { onBecomeActive?() }
        }
        .onChange(of: isRepsFocused) { _, focused in
            if focused { onBecomeActive?() }
        }
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
            // Both of these are set-once-a-year controls that used to occupy
            // permanent horizontal space in the row.
            Button(workoutSet.weightMode == .perSide ? "Use total weight" : "Use per-side weight") {
                Haptics.light()
                onToggleWeightMode()
            }
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

            HStack(spacing: SetRowLayout.columnSpacing) {
                // Set deletion and skip live in the row's context menu (long-press)
                // wired at the call site in `ActiveWorkoutView`. No leading button
                // column, and no swipe recognizer — the earlier swipe-to-delete was
                // removed because its `DragGesture` fought the ScrollView pan.
                // Keep a small leading inset so the remaining content stays
                // visually anchored where it was.
                Spacer().frame(width: SetRowLayout.leadingInset)

                // PR trophy / SKIP / DROP badge / set number
                if isSkipped {
                    Image(systemName: "minus.circle")
                        .font(Theme.fontCaption2)
                        .foregroundStyle(Theme.textTertiary)
                        .frame(width: SetRowLayout.numberWidth)
                        .accessibilityLabel("Skipped")
                } else if isPR {
                    Image(systemName: "trophy.fill")
                        .font(Theme.fontCaption2)
                        .foregroundStyle(Theme.prGold)
                        .frame(width: SetRowLayout.numberWidth)
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
                        .frame(width: SetRowLayout.numberWidth, alignment: .center)
                }

                // Previous-session reference. This replaced the per-row lbs/kg
                // toggle, which spent 44pt of a cramped row on a setting nobody
                // changes mid-set. What belongs here is the number the lifter is
                // actually trying to beat.
                Button {
                    guard let previousSet else { return }
                    Haptics.light()
                    onBecomeActive?()
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
                    .frame(width: SetRowLayout.previousWidth, alignment: .center)
                    .frame(minHeight: 40)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(previousSet == nil || isSkipped)
                .accessibilityLabel(
                    previousSet.map { "Last time: \($0.weight.formattedWeight) for \($0.reps) reps" }
                        ?? "No previous set"
                )
                .accessibilityHint("Copies last session's numbers into this set")

                // Weight field
                numericField(
                    text: $weightText,
                    keyboard: .decimalPad,
                    focus: $isWeightFocused,
                    onEdit: { newValue in
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
                )
                // Long-press surfaces the weight actions without breaking text input.
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.45)
                        .onEnded { _ in
                            Haptics.medium()
                            isWeightFocused = false
                            showWeightActions = true
                        }
                )
                .accessibilityAction(named: Text("Weight options")) {
                    showWeightActions = true
                }

                Text("×")
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: SetRowLayout.separatorWidth)

                // Reps field
                numericField(
                    text: $repsText,
                    keyboard: .numberPad,
                    focus: $isRepsFocused,
                    onEdit: { newValue in
                        if let r = Int(newValue) { onRepsChange(r) }
                    }
                )

                if let label = lateralityLabel {
                    Text(label)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 26)
                }

                // Complete checkmark
                Button(action: {
                    Haptics.success()
                    onBecomeActive?()
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
                    .frame(width: SetRowLayout.completeWidth, height: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isSkipped)
                // Bounce the checkmark as it fills — a small confirmation that
                // the tap registered without stealing attention from the lift.
                .symbolEffect(.bounce, value: isCompleted)
                .accessibilityLabel(isCompleted ? "Mark set \(setNumber) incomplete" : "Complete set \(setNumber)")
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, isDropSet ? 4 : 6)
        }
    }

    /// Shared weight/reps entry field. Both were 20 near-identical lines of
    /// modifiers; the only real differences are the keyboard and the commit.
    private func numericField(
        text: Binding<String>,
        keyboard: UIKeyboardType,
        focus: FocusState<Bool>.Binding,
        onEdit: @escaping (String) -> Void
    ) -> some View {
        TextField("0", text: text)
            .keyboardType(keyboard)
            .multilineTextAlignment(.center)
            .font(isDropSet ? .footnote.weight(.semibold).monospacedDigit() : Theme.fontNumberMedium)
            .padding(.vertical, isDropSet ? 6 : 8)
            .padding(.horizontal, 6)
            .background(Theme.surfaceElevated)
            .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                    .strokeBorder(focus.wrappedValue ? Theme.hairlineStrong : Theme.hairline, lineWidth: 0.5)
            )
            .foregroundStyle(isCompleted ? Theme.accent : Theme.textPrimary)
            .strikethrough(isSkipped, color: Theme.textTertiary)
            .frame(maxWidth: .infinity)
            .focused(focus)
            .disabled(isSkipped)
            .onChange(of: text.wrappedValue) { _, newValue in onEdit(newValue) }
    }

    // MARK: - Subline (hints + quick actions, cursor row only)

    /// One combined line replacing what used to be three stacked rows: the
    /// Last/PR hint row, the Drop/Max/+5 quick-action row, and the drop-set
    /// button row. Rendering it only on the cursor set is what collapses a
    /// 4-set exercise from ~600pt to roughly half that.
    private var subline: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
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

                if isCurrentSet && !isCompleted {
                    if let onMarkDropSet, !isDropSet {
                        actionChip(label: "Drop", icon: "arrow.down") {
                            onMarkDropSet()
                        }
                        .accessibilityLabel("Mark as drop set")
                    }
                    if let onFillMax {
                        actionChip(label: "Max", icon: "trophy") {
                            onFillMax()
                        }
                        .accessibilityLabel("Fill with PR weight")
                    }
                    if let onFillMaxPlus5 {
                        actionChip(label: "+5", icon: nil) {
                            onFillMaxPlus5()
                        }
                        .accessibilityLabel("Fill with PR weight plus 5 pounds")
                    }
                    if let onToggleSkip {
                        actionChip(label: "Skip", icon: "forward.end") {
                            onToggleSkip()
                        }
                        .accessibilityLabel("Skip set \(setNumber)")
                    }
                }
            }
            .padding(.leading, SetRowLayout.leadingInset + SetRowLayout.columnSpacing + SetRowLayout.numberWidth + Theme.Spacing.md)
            .padding(.trailing, Theme.Spacing.md)
        }
        .scrollBounceBehavior(.basedOnSize)
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
        .fixedSize()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value)")
    }

    private func actionChip(label: String, icon: String?, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.light()
            action()
        } label: {
            HStack(spacing: 3) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption2.weight(.bold))
                }
                Text(label)
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, 4)
            .background(Theme.accent.opacity(0.10))
            .clipShape(.capsule)
            .fixedSize()
        }
        .buttonStyle(.plain)
    }
}
