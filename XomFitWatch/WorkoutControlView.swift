import SwiftUI

/// Main watch face — start/end workout, see current exercise, set count, heart rate, rest timer.
struct WorkoutControlView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    @State private var showLogSet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    if workoutManager.isWorkoutActive {
                        activeWorkoutView
                    } else {
                        idleView
                    }
                }
                .padding(.horizontal, 4)
            }
            .navigationTitle("XomFit")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showLogSet) {
            LogSetView()
                .environmentObject(workoutManager)
        }
    }

    // MARK: - Idle

    private var idleView: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 40))
                .foregroundStyle(.green)

            Button {
                workoutManager.startWorkout()
            } label: {
                Text("Start Workout")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding(.top, 20)
    }

    // MARK: - Active Workout

    private var activeWorkoutView: some View {
        VStack(spacing: 6) {
            // Exercise name
            if !workoutManager.currentExercise.isEmpty {
                Text(workoutManager.currentExercise)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            // Set counter
            if workoutManager.totalSets > 0 {
                Text("Set \(workoutManager.currentSetNumber) of \(workoutManager.totalSets)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Heart rate
            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                    .font(.caption2)
                Text("\(Int(workoutManager.heartRate)) BPM")
                    .font(.system(.body, design: .rounded).monospacedDigit())
            }
            .padding(.vertical, 4)

            // Rest timer (inline)
            if workoutManager.isRestTimerRunning {
                RestTimerView()
                    .environmentObject(workoutManager)
            }

            // Log Set button
            Button {
                showLogSet = true
            } label: {
                Label("Log Set", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)

            // End Workout
            Button(role: .destructive) {
                workoutManager.endWorkout()
            } label: {
                Text("End Workout")
                    .font(.footnote)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.top, 4)
        }
    }
}

#Preview {
    WorkoutControlView()
        .environmentObject(WatchWorkoutManager())
}
