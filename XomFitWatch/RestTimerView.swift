import SwiftUI

/// Countdown ring with skip / +30s controls.
struct RestTimerView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager

    private var progress: Double {
        guard workoutManager.restDuration > 0 else { return 0 }
        return 1 - (workoutManager.restTimeRemaining / workoutManager.restDuration)
    }

    private var timeString: String {
        let mins = Int(workoutManager.restTimeRemaining) / 60
        let secs = Int(workoutManager.restTimeRemaining) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 6)

                // Progress ring
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        Color.orange,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)

                // Time
                Text(timeString)
                    .font(.system(.title3, design: .rounded).monospacedDigit())
                    .foregroundStyle(.orange)
            }
            .frame(width: 80, height: 80)

            // Controls
            HStack(spacing: 12) {
                Button {
                    workoutManager.stopRestTimer()
                } label: {
                    Text("Skip")
                        .font(.caption)
                }
                .buttonStyle(.bordered)

                Button {
                    workoutManager.addRestTime(30)
                } label: {
                    Text("+30s")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    RestTimerView()
        .environmentObject(WatchWorkoutManager())
}
