import SwiftUI

struct WorkoutSharePreviewView: View {
    @StateObject var viewModel: WorkoutCardViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var currentScale: CGFloat = 1.0
    @State private var savedToPhotos = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Close button
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Spacer()

                // Card preview
                if let image = viewModel.previewImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: viewModel.selectedTheme.accentColor.opacity(0.3), radius: 20)
                        .scaleEffect(currentScale)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    currentScale = min(max(value, 0.5), 3.0)
                                }
                                .onEnded { _ in
                                    withAnimation(.spring()) {
                                        currentScale = 1.0
                                    }
                                }
                        )
                } else {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                }

                Spacer().frame(height: 24)

                // Theme selector
                HStack(spacing: 12) {
                    ForEach(CardTheme.allCases) { theme in
                        themeChip(theme)
                    }
                }
                .padding(.horizontal, 20)

                Spacer().frame(height: 24)

                // Action buttons
                VStack(spacing: 12) {
                    Button(action: { viewModel.shareWorkout() }) {
                        HStack(spacing: 8) {
                            Text("Share")
                                .font(.system(size: 17, weight: .bold))
                            Text("🚀")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(viewModel.selectedTheme.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }

                    Button(action: {
                        viewModel.saveToPhotos()
                        withAnimation { savedToPhotos = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { savedToPhotos = false }
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: savedToPhotos ? "checkmark" : "square.and.arrow.down")
                            Text(savedToPhotos ? "Saved!" : "Save to Photos")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .sheet(isPresented: $viewModel.showShareSheet) {
            ShareSheet(items: viewModel.shareItems)
        }
        .task {
            _ = await viewModel.renderAsImage()
        }
    }

    private func themeChip(_ theme: CardTheme) -> some View {
        Button(action: { viewModel.updateTheme(theme) }) {
            VStack(spacing: 6) {
                Image(systemName: theme.icon)
                    .font(.system(size: 16))
                Text(theme.rawValue)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(viewModel.selectedTheme == theme ? .white : .white.opacity(0.4))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                viewModel.selectedTheme == theme
                    ? theme.accentColor.opacity(0.3)
                    : Color.white.opacity(0.05)
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        viewModel.selectedTheme == theme ? theme.accentColor : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
    }
}

#Preview {
    WorkoutSharePreviewView(
        viewModel: WorkoutCardViewModel(
            completedWorkout: CompletedWorkout(
                name: "Push Day",
                date: Date(),
                duration: 4980,
                exercises: [
                    ExerciseSummary(name: "Squat", bestSetWeight: 225, bestSetReps: 5, setCount: 5),
                    ExerciseSummary(name: "Bench Press", bestSetWeight: 185, bestSetReps: 5, setCount: 4),
                    ExerciseSummary(name: "Deadlift", bestSetWeight: 275, bestSetReps: 5, setCount: 3),
                ],
                totalVolume: 24500,
                totalSets: 18,
                totalReps: 72,
                newPRs: [PRRecord(exerciseName: "Squat", weight: 225, previousBest: 215)],
                caloriesBurned: 340,
                userName: "domgiordano"
            )
        )
    )
}
