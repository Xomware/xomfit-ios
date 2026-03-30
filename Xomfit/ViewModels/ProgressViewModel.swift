import Foundation

@MainActor
@Observable
final class ProgressViewModel {

    // MARK: - State

    var isLoading = false
    var errorMessage: String?

    // Summary
    var totalWorkouts = 0
    var currentStreak = 0
    var totalVolume: Double = 0
    var totalPRs = 0

    // Charts
    var strengthDataPoints: [StrengthDataPoint] = []
    var weeklyVolumes: [(label: String, volume: Double)] = []
    var muscleGroupSets: [(group: String, sets: Int)] = []

    // Exercise picker
    var availableExercises: [String] = []
    var selectedExercise: String = ""

    // Recent PRs
    var recentPRs: [PersonalRecord] = []

    // MARK: - Computed

    var filteredStrengthData: [StrengthDataPoint] {
        strengthDataPoints.filter { $0.exerciseName == selectedExercise }
    }

    var formattedTotalVolume: String {
        if totalVolume >= 1_000_000 {
            return String(format: "%.1fM", totalVolume / 1_000_000)
        } else if totalVolume >= 1000 {
            return String(format: "%.1fk", totalVolume / 1000)
        }
        return "\(Int(totalVolume))"
    }

    // MARK: - Load

    func loadData(userId: String) async {
        guard !userId.isEmpty else { return }
        isLoading = true
        errorMessage = nil

        let workouts = WorkoutService.shared.fetchWorkouts(userId: userId)

        var prs: [PersonalRecord] = []
        do {
            prs = try await PRService.shared.fetchPRs(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }

        computeSummary(workouts: workouts, prs: prs)
        computeStrengthData(workouts: workouts)
        computeWeeklyVolume(workouts: workouts)
        computeMuscleGroups(workouts: workouts)

        recentPRs = Array(prs.prefix(5))
        isLoading = false
    }

    // MARK: - Private Compute

    private func computeSummary(workouts: [Workout], prs: [PersonalRecord]) {
        totalWorkouts = workouts.count
        totalVolume = workouts.reduce(0) { $0 + $1.totalVolume }
        totalPRs = prs.count

        // Streak: consecutive calendar days with workouts looking back from today
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let workoutDays = Set(workouts.map { calendar.startOfDay(for: $0.startTime) })

        var streak = 0
        for offset in 0..<365 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { break }
            if workoutDays.contains(day) {
                streak += 1
            } else if offset == 0 {
                // Today doesn't have a workout yet -- check from yesterday
                continue
            } else {
                break
            }
        }
        currentStreak = streak
    }

    private func computeStrengthData(workouts: [Workout]) {
        // For each exercise in each workout, find the best estimated 1RM
        var exerciseFrequency: [String: Int] = [:]
        var dataPoints: [StrengthDataPoint] = []

        for workout in workouts {
            for workoutExercise in workout.exercises {
                let name = workoutExercise.exercise.name
                exerciseFrequency[name, default: 0] += 1

                guard let bestSet = workoutExercise.sets.max(by: { $0.estimated1RM < $1.estimated1RM }) else {
                    continue
                }

                dataPoints.append(
                    StrengthDataPoint(
                        date: workout.startTime,
                        value: bestSet.weight,
                        reps: bestSet.reps,
                        exerciseName: name
                    )
                )
            }
        }

        strengthDataPoints = dataPoints.sorted { $0.date < $1.date }
        availableExercises = exerciseFrequency
            .sorted { $0.value > $1.value }
            .map(\.key)

        if selectedExercise.isEmpty || !availableExercises.contains(selectedExercise) {
            selectedExercise = availableExercises.first ?? ""
        }
    }

    private func computeWeeklyVolume(workouts: [Workout]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"

        var buckets: [(label: String, volume: Double)] = []

        for weekOffset in stride(from: 7, through: 0, by: -1) {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: today) else {
                continue
            }
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: weekStart)?.start ?? weekStart
            guard let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek) else {
                continue
            }

            let weekWorkouts = workouts.filter {
                $0.startTime >= startOfWeek && $0.startTime < endOfWeek
            }
            let volume = weekWorkouts.reduce(0.0) { $0 + $1.totalVolume }
            let label = dateFormatter.string(from: startOfWeek)
            buckets.append((label: label, volume: volume))
        }

        weeklyVolumes = buckets
    }

    private func computeMuscleGroups(workouts: [Workout]) {
        var groupSets: [MuscleGroup: Int] = [:]

        for workout in workouts {
            for workoutExercise in workout.exercises {
                let setCount = workoutExercise.sets.count
                for muscle in workoutExercise.exercise.muscleGroups {
                    groupSets[muscle, default: 0] += setCount
                }
            }
        }

        muscleGroupSets = groupSets
            .sorted { $0.value > $1.value }
            .map { (group: $0.key.displayName, sets: $0.value) }
    }
}
