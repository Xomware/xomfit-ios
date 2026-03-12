import SwiftUI

struct SetRowView: View {
    let setNumber: Int
    let workoutSet: WorkoutSet
    let onWeightChange: (Double) -> Void
    let onRepsChange: (Int) -> Void
    let onComplete: () -> Void
    let onDelete: () -> Void

    @State private var weightText: String
    @State private var repsText: String

    private var isCompleted: Bool {
        workoutSet.completedAt != Date.distantPast
    }

    init(
        setNumber: Int,
        workoutSet: WorkoutSet,
        onWeightChange: @escaping (Double) -> Void,
        onRepsChange: @escaping (Int) -> Void,
        onComplete: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.setNumber = setNumber
        self.workoutSet = workoutSet
        self.onWeightChange = onWeightChange
        self.onRepsChange = onRepsChange
        self.onComplete = onComplete
        self.onDelete = onDelete

        let w = workoutSet.weight
        let r = workoutSet.reps
        _weightText = State(initialValue: w > 0 ? w.formattedWeight : "")
        _repsText   = State(initialValue: r > 0 ? "\(r)" : "")
    }

    var body: some View {
        HStack(spacing: Theme.paddingSmall) {
            // Set number
            Text("\(setNumber)")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(isCompleted ? Theme.accent : Theme.textSecondary)
                .frame(width: 24, alignment: .center)

            // Weight field
            TextField("0", text: $weightText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .padding(.vertical, 8)
                .padding(.horizontal, 6)
                .background(Theme.cardBackground)
                .cornerRadius(Theme.cornerRadiusSmall)
                .foregroundColor(isCompleted ? Theme.accent : Theme.textPrimary)
                .frame(maxWidth: .infinity)
                .onChange(of: weightText) { _, newValue in
                    if let w = Double(newValue) {
                        onWeightChange(w)
                    }
                }

            Text("lbs  ×")
                .font(Theme.fontCaption)
                .foregroundColor(Theme.textSecondary)

            // Reps field
            TextField("0", text: $repsText)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .padding(.vertical, 8)
                .padding(.horizontal, 6)
                .background(Theme.cardBackground)
                .cornerRadius(Theme.cornerRadiusSmall)
                .foregroundColor(isCompleted ? Theme.accent : Theme.textPrimary)
                .frame(maxWidth: .infinity)
                .onChange(of: repsText) { _, newValue in
                    if let r = Int(newValue) {
                        onRepsChange(r)
                    }
                }

            // Complete checkmark button
            Button(action: onComplete) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "checkmark.circle")
                    .font(.system(size: 24))
                    .foregroundColor(isCompleted ? Theme.accent : Theme.textSecondary)
            }
            .frame(width: 36)
        }
        .padding(.horizontal, Theme.paddingMedium)
        .padding(.vertical, 6)
        .background(isCompleted ? Theme.accent.opacity(0.08) : Color.clear)
        .cornerRadius(Theme.cornerRadiusSmall)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
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
