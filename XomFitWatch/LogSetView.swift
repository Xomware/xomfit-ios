import SwiftUI

/// Quick set logging with Digital Crown for weight/reps.
struct LogSetView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    @Environment(\.dismiss) private var dismiss

    @State private var weight: Double = 135
    @State private var reps: Int = 10
    @State private var isFineWeight = false // Long press toggles 1lb increments
    @State private var focusedField: Field? = .weight

    enum Field: Hashable {
        case weight, reps
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // Weight
                VStack(spacing: 2) {
                    Text("WEIGHT")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(weight, specifier: weight.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f") lbs")
                        .font(.system(.title2, design: .rounded).monospacedDigit())
                        .foregroundStyle(focusedField == .weight ? .green : .primary)
                        .focusable(true)
                        .digitalCrownRotation(
                            $weight,
                            from: 0, through: 1000,
                            by: isFineWeight ? 1 : 5,
                            sensitivity: .medium,
                            isContinuous: false,
                            isHapticFeedbackEnabled: true
                        )
                        .onTapGesture { focusedField = .weight }
                        .onLongPressGesture {
                            isFineWeight.toggle()
                            WKInterfaceDevice.current().play(.click)
                        }
                }

                // Reps
                VStack(spacing: 2) {
                    Text("REPS")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    HStack {
                        Button { if reps > 1 { reps -= 1 } } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)

                        Text("\(reps)")
                            .font(.system(.title2, design: .rounded).monospacedDigit())
                            .frame(minWidth: 40)

                        Button { reps += 1 } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Same as last
                if workoutManager.lastLoggedWeight > 0 {
                    Button {
                        weight = workoutManager.lastLoggedWeight
                        reps = workoutManager.lastLoggedReps
                    } label: {
                        Text("Same as last (\(workoutManager.lastLoggedWeight, specifier: "%.0f")×\(workoutManager.lastLoggedReps))")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                }

                // LOG SET
                Button {
                    _ = workoutManager.logSet(weight: weight, reps: reps)
                    dismiss()
                } label: {
                    Text("LOG SET")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Log Set")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            weight = workoutManager.lastLoggedWeight
            reps = workoutManager.lastLoggedReps
        }
    }
}

#Preview {
    LogSetView()
        .environmentObject(WatchWorkoutManager())
}
