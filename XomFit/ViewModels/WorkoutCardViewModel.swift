import Foundation
import SwiftUI

@MainActor
class WorkoutCardViewModel: ObservableObject {
    @Published var selectedTheme: CardTheme = .default
    @Published var previewImage: UIImage?
    @Published var showShareSheet = false
    @Published var shareItems: [Any] = []
    @Published var completedWorkout: CompletedWorkout

    init(completedWorkout: CompletedWorkout) {
        self.completedWorkout = completedWorkout
        self.selectedTheme = completedWorkout.newPRs.isEmpty ? .default : .fire
    }

    // MARK: - Build from Workout model

    static func buildCompletedWorkout(from workout: Workout, userName: String = "xomfit_user") -> CompletedWorkout {
        // Extract exercise summaries sorted by volume (descending), top 3
        let exerciseSummaries: [ExerciseSummary] = workout.exercises
            .map { we in
                let bestSet = we.bestSet
                return ExerciseSummary(
                    name: we.exercise.name,
                    bestSetWeight: bestSet?.weight ?? 0,
                    bestSetReps: bestSet?.reps ?? 0,
                    setCount: we.sets.count
                )
            }
            .sorted { ($0.bestSetWeight * Double($0.bestSetReps)) > ($1.bestSetWeight * Double($1.bestSetReps)) }

        let topExercises = Array(exerciseSummaries.prefix(3))

        // Extract PRs
        let prRecords: [PRRecord] = workout.exercises.flatMap { we in
            we.sets.filter { $0.isPersonalRecord }.map { set in
                PRRecord(
                    exerciseName: we.exercise.name,
                    weight: set.weight,
                    previousBest: nil
                )
            }
        }

        let totalReps = workout.exercises.flatMap { $0.sets }.reduce(0) { $0 + $1.reps }

        return CompletedWorkout(
            name: workout.name,
            date: workout.startTime,
            duration: workout.duration,
            exercises: topExercises,
            totalVolume: workout.totalVolume,
            totalSets: workout.totalSets,
            totalReps: totalReps,
            newPRs: prRecords,
            caloriesBurned: nil,
            userName: userName
        )
    }

    // MARK: - Rendering

    func renderAsImage() async -> UIImage? {
        let cardView = WorkoutSummaryCardView(workout: completedWorkout, theme: selectedTheme)
        let renderer = ImageRenderer(content: cardView)
        renderer.scale = 3.0
        renderer.proposedSize = ProposedViewSize(
            width: WorkoutSummaryCardView.cardWidth,
            height: WorkoutSummaryCardView.cardHeight
        )
        let image = renderer.uiImage
        previewImage = image
        return image
    }

    func shareWorkout() {
        Task {
            if let image = await renderAsImage() {
                shareItems = [image]
                showShareSheet = true
            }
        }
    }

    func saveToPhotos() {
        Task {
            if let image = await renderAsImage() {
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            }
        }
    }

    func updateTheme(_ theme: CardTheme) {
        selectedTheme = theme
        Task {
            _ = await renderAsImage()
        }
    }
}
