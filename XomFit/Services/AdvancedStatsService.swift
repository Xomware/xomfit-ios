import Foundation

class AdvancedStatsService {
    static let shared = AdvancedStatsService()
    private let workoutStore = WorkoutStore.shared
    
    // MARK: - Strength Curves
    func strengthCurve(for exercise: String, days: Int = 90) -> [StrengthDataPoint] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        return workoutStore.workouts
            .filter { $0.startDate >= cutoff }
            .flatMap { workout in
                workout.sets
                    .filter { $0.exerciseName?.lowercased() == exercise.lowercased() }
                    .compactMap { set -> StrengthDataPoint? in
                        guard let w = set.weight, let r = set.reps else { return nil }
                        return StrengthDataPoint(date: workout.startDate, value: w, reps: r, exerciseName: exercise)
                    }
            }
            .sorted { $0.date < $1.date }
    }
    
    // Get best set per workout day for a given exercise
    func bestSetsPerDay(for exercise: String, days: Int = 90) -> [StrengthDataPoint] {
        let curve = strengthCurve(for: exercise, days: days)
        let grouped = Dictionary(grouping: curve) { point in
            Calendar.current.startOfDay(for: point.date)
        }
        return grouped.compactMap { (day, points) in
            points.max(by: { $0.estimated1RM < $1.estimated1RM })
        }.sorted { $0.date < $1.date }
    }
    
    // MARK: - Muscle Heatmap
    func muscleHeatmap(days: Int = 7) -> [MuscleHeatmapData] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let recentSets = workoutStore.workouts
            .filter { $0.startDate >= cutoff }
            .flatMap { $0.sets }
        
        let muscleKeywords: [(String, [String])] = [
            ("Chest", ["bench", "push", "fly", "dip", "chest"]),
            ("Back", ["row", "pull", "lat", "deadlift", "back"]),
            ("Quads", ["squat", "leg press", "lunge", "quad", "extension"]),
            ("Hamstrings", ["hamstring", "leg curl", "rdl", "romanian"]),
            ("Shoulders", ["press", "lateral", "front raise", "shoulder", "military"]),
            ("Biceps", ["curl", "bicep", "hammer"]),
            ("Triceps", ["tricep", "pushdown", "extension", "dip"]),
            ("Glutes", ["glute", "hip thrust", "bridge", "rdl"]),
            ("Core", ["plank", "crunch", "ab", "core", "sit"])
        ]
        
        let volumes: [(String, Int)] = muscleKeywords.map { (muscle, keywords) in
            let count = recentSets.filter { set in
                guard let name = set.exerciseName?.lowercased() else { return false }
                return keywords.contains(where: { name.contains($0) })
            }.count
            return (muscle, count)
        }
        
        let maxVolume = volumes.map { $0.1 }.max() ?? 1
        return volumes.map { (muscle, volume) in
            MuscleHeatmapData(muscleGroup: muscle, weeklyVolume: volume,
                             intensity: Double(volume) / Double(max(maxVolume, 1)))
        }
    }
    
    // MARK: - Balance Ratios
    func muscleBalanceRatios(days: Int = 30) -> [MusclePairBalance] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let recentSets = workoutStore.workouts
            .filter { $0.startDate >= cutoff }
            .flatMap { $0.sets }
        
        func countSets(_ keywords: [String]) -> Int {
            recentSets.filter { set in
                guard let name = set.exerciseName?.lowercased() else { return false }
                return keywords.contains(where: { name.contains($0) })
            }.count
        }
        
        let pushSets = countSets(["bench", "push", "fly", "chest", "tricep", "shoulder press"])
        let pullSets = countSets(["row", "pull", "lat", "deadlift", "curl", "bicep"])
        let quadSets = countSets(["squat", "leg press", "lunge", "extension"])
        let hamSets = countSets(["hamstring", "leg curl", "rdl"])
        
        return [
            MusclePairBalance(primaryMuscle: "Push", antagonistMuscle: "Pull",
                             primaryVolume: pushSets, antagonistVolume: pullSets),
            MusclePairBalance(primaryMuscle: "Quads", antagonistMuscle: "Hamstrings",
                             primaryVolume: quadSets, antagonistVolume: hamSets)
        ]
    }
    
    // MARK: - Frequency Heatmap (365 days)
    func workoutFrequencyHeatmap(days: Int = 364) -> [WorkoutFrequencyDay] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let workouts = workoutStore.workouts.filter { $0.startDate >= cutoff }
        
        let grouped = Dictionary(grouping: workouts) { workout in
            Calendar.current.startOfDay(for: workout.startDate)
        }
        
        let maxCount = grouped.values.map { $0.count }.max() ?? 1
        
        return grouped.map { (day, dayWorkouts) in
            WorkoutFrequencyDay(date: day, count: dayWorkouts.count, maxCount: maxCount)
        }.sorted { $0.date < $1.date }
    }
    
    // MARK: - All-Time PRs
    func allTimePRs() -> [ExercisePR] {
        var prsByExercise: [String: ExercisePR] = [:]
        
        for workout in workoutStore.workouts {
            for set in workout.sets {
                guard let name = set.exerciseName, let weight = set.weight, let reps = set.reps else { continue }
                let pr = ExercisePR(exerciseName: name, weight: weight, reps: reps, date: workout.startDate)
                if let existing = prsByExercise[name] {
                    if pr.estimated1RM > existing.estimated1RM {
                        prsByExercise[name] = pr
                    }
                } else {
                    prsByExercise[name] = pr
                }
            }
        }
        
        return Array(prsByExercise.values).sorted { $0.exerciseName < $1.exerciseName }
    }
    
    // MARK: - CSV Export
    func exportToCSV() -> String {
        var csv = "Date,Exercise,Sets,Reps,Weight,Volume\n"
        for workout in workoutStore.workouts.sorted(by: { $0.startDate < $1.startDate }) {
            let dateStr = ISO8601DateFormatter().string(from: workout.startDate)
            for set in workout.sets {
                let exercise = set.exerciseName ?? "Unknown"
                let reps = set.reps.map { "\($0)" } ?? ""
                let weight = set.weight.map { "\($0)" } ?? ""
                let volume = (set.reps ?? 0).description + "x" + (set.weight.map { "\($0)" } ?? "0")
                csv += "\(dateStr),\(exercise),1,\(reps),\(weight),\(volume)\n"
            }
        }
        return csv
    }
    
    // MARK: - Available Exercises (for curve selector)
    func availableExercises() -> [String] {
        let names = workoutStore.workouts
            .flatMap { $0.sets }
            .compactMap { $0.exerciseName }
        return Array(Set(names)).sorted()
    }
}
