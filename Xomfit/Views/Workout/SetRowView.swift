import SwiftUI

struct SetRowView: View {
    let setNumber: Int
    let workoutSet: WorkoutSet
    let onWeightChange: (Double) -> Void
    let onRepsChange: (Int) -> Void
    let onComplete: () -> Void
    let onDelete: () -> Void
    let onToggleWeightMode: () -> Void

    @State private var weightText: String
    @State private var repsText: String
    @FocusState private var isWeightFocused: Bool
    @FocusState private var isRepsFocused: Bool

    private var isCompleted: Bool {
        workoutSet.completedAt != Date.distantPast
    }

    init(
        setNumber: Int,
        workoutSet: WorkoutSet,
        onWeightChange: @escaping (Double) -> Void,
        onRepsChange: @escaping (Int) -> Void,
        onComplete: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onToggleWeightMode: @escaping () -> Void = {}
    ) {
        self.setNumber = setNumber
        self.workoutSet = workoutSet
        self.onWeightChange = onWeightChange
        self.onRepsChange = onRepsChange
        self.onComplete = onComplete
        self.onDelete = onDelete
        self.onToggleWeightMode = onToggleWeightMode

        let w = workoutSet.weight
        let r = workoutSet.reps
        _weightText = State(initialValue: w > 0 ? w.formattedWeight : "")
        _repsText   = State(initialValue: r > 0 ? "\(r)" : "")
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // Delete button (visible, since swipeActions don't work outside List)
            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(Theme.destructive)
                    .font(.headline)
            }
            .buttonStyle(.plain)
            .frame(width: 30)
            .accessibilityLabel("Delete set \(setNumber)")

            // Set number
            Text("\(setNumber)")
                .font(.subheadline.weight(.bold).monospaced())
                .foregroundStyle(isCompleted ? Theme.accent : Theme.textSecondary)
                .frame(width: 24, alignment: .center)

            // Weight field
            TextField("0", text: $weightText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .padding(.vertical, 8)
                .padding(.horizontal, 6)
                .background(Theme.surface)
                .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
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
                .padding(.vertical, 8)
                .padding(.horizontal, 6)
                .background(Theme.surface)
                .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
                .foregroundStyle(isCompleted ? Theme.accent : Theme.textPrimary)
                .frame(maxWidth: .infinity)
                .focused($isRepsFocused)
                .onChange(of: repsText) { _, newValue in
                    if let r = Int(newValue) {
                        onRepsChange(r)
                    }
                }

            // Complete checkmark button
            Button(action: {
                Haptics.success()
                onComplete()
            }) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "checkmark.circle")
                    .font(.title2)
                    .foregroundStyle(isCompleted ? Theme.accent : Theme.textSecondary.opacity(0.6))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isCompleted ? "Mark set \(setNumber) incomplete" : "Complete set \(setNumber)")
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 6)
        .background(isCompleted ? Theme.accent.opacity(0.12) : Color.clear)
        .clipShape(.rect(cornerRadius: Theme.cornerRadiusSmall))
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isWeightFocused = false
                    isRepsFocused = false
                }
            }
        }
        .animation(nil, value: workoutSet.completedAt)
        // Keep local text state in sync if set is reset externally
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
