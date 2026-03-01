import SwiftUI

struct WorkoutCompletionView: View {
    let workout: Workout
    let userName: String
    @Environment(\.dismiss) private var dismiss
    @State private var showSharePreview = false
    @State private var animateIn = false

    private var completedWorkout: CompletedWorkout {
        WorkoutCardViewModel.buildCompletedWorkout(from: workout, userName: userName)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Celebration
                VStack(spacing: 12) {
                    Text("💪")
                        .font(.system(size: 64))
                        .scaleEffect(animateIn ? 1.0 : 0.3)
                        .opacity(animateIn ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.5).delay(0.2), value: animateIn)

                    Text("Workout Complete!")
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(.white)
                        .opacity(animateIn ? 1 : 0)
                        .animation(.easeOut(duration: 0.5).delay(0.4), value: animateIn)
                }

                // Quick stats
                HStack(spacing: 20) {
                    quickStat(value: workout.durationString, label: "Duration")
                    quickStat(value: "\(workout.totalSets)", label: "Sets")
                    quickStat(value: workout.formattedVolume + " lbs", label: "Volume")
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .background(Theme.cardBackground)
                .cornerRadius(16)
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 20)
                .animation(.easeOut(duration: 0.5).delay(0.6), value: animateIn)

                // PR callout
                if workout.totalPRs > 0 {
                    HStack(spacing: 8) {
                        Text("🏆")
                            .font(.system(size: 20))
                        Text("\(workout.totalPRs) New Personal Record\(workout.totalPRs == 1 ? "" : "s")!")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Theme.prGold)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 20)
                    .background(Theme.prGold.opacity(0.12))
                    .cornerRadius(12)
                }

                Spacer()

                // Share button
                Button(action: { showSharePreview = true }) {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Share Your Workout")
                            .font(.system(size: 17, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Theme.accent, Theme.accent.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(14)
                }
                .opacity(animateIn ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.8), value: animateIn)

                Button(action: { dismiss() }) {
                    Text("Done")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
        }
        .fullScreenCover(isPresented: $showSharePreview) {
            WorkoutSharePreviewView(
                viewModel: WorkoutCardViewModel(completedWorkout: completedWorkout)
            )
        }
        .onAppear {
            animateIn = true
        }
    }

    private func quickStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
