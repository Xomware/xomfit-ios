import SwiftUI

struct SetRowView: View {
    let setNumber: Int
    let workoutSet: WorkoutSet
    let onWeightChange: (Double) -> Void
    let onRepsChange: (Int) -> Void
    let onComplete: () -> Void
    let onDelete: () -> Void
    let onToggleWeightMode: () -> Void
    var lateralityLabel: String? = nil

    @State private var weightText: String
    @State private var repsText: String
    @FocusState private var isWeightFocused: Bool
    @FocusState private var isRepsFocused: Bool

    private var isCompleted: Bool {
        workoutSet.completedAt != Date.distantPast
    }

    private var isPR: Bool {
        workoutSet.isPersonalRecord
    }

    init(
        setNumber: Int,
        workoutSet: WorkoutSet,
        onWeightChange: @escaping (Double) -> Void,
        onRepsChange: @escaping (Int) -> Void,
        onComplete: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onToggleWeightMode: @escaping () -> Void = {},
        lateralityLabel: String? = nil
    ) {
        self.setNumber = setNumber
        self.workoutSet = workoutSet
        self.onWeightChange = onWeightChange
        self.onRepsChange = onRepsChange
        self.onComplete = onComplete
        self.onDelete = onDelete
        self.onToggleWeightMode = onToggleWeightMode
        self.lateralityLabel = lateralityLabel

        let w = workoutSet.weight
        let r = workoutSet.reps
        _weightText = State(initialValue: w > 0 ? w.formattedWeight : "")
        _repsText   = State(initialValue: r > 0 ? "\(r)" : "")
    }

    var body: some View {
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
                        .font(.headline)
                }
                .buttonStyle(.plain)
                .frame(width: 30)
                .accessibilityLabel("Delete set \(setNumber)")

                // PR trophy icon (replaces tinted row background)
                if isPR {
                    Image(systemName: "trophy.fill")
                        .font(.caption2)
                        .foregroundStyle(Theme.prGold)
                        .frame(width: 16)
                } else {
                    // Set number
                    Text("\(setNumber)")
                        .font(.subheadline.weight(.bold).monospaced())
                        .foregroundStyle(isCompleted ? Theme.accent : Theme.textSecondary)
                        .frame(width: 24, alignment: .center)
                }

                // Weight field
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
                    .foregroundStyle(isCompleted ? Theme.accent : Theme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .focused($isWeightFocused)
                    .onChange(of: weightText) { _, newValue in
                        if let w = Double(newValue) {
                            onWeightChange(w)
                        }
                    }

                Button(action: onToggleWeightMode) {
                    Text(workoutSet.weightMode == .perSide ? "lbs ×2  ×" : "lbs  ×")
                        .font(Theme.fontCaption)
                        .foregroundStyle(workoutSet.weightMode == .perSide ? Theme.accent : Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(workoutSet.weightMode == .perSide ? "Per side weight, tap to switch to total" : "Total weight, tap to switch to per side")

                // Reps field
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

                // Complete checkmark — accent fill when done, 28pt target
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
            .padding(.vertical, 6)
        }
        .frame(minHeight: 52)
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
    }
}
