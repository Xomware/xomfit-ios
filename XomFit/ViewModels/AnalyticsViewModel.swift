import Foundation

@MainActor
class AnalyticsViewModel: ObservableObject {
    @Published var workouts: [Workout] = []
    @Published var selectedStartDate: Date = Date().addingTimeInterval(-30 * 24 * 3600) // 30 days ago
    @Published var selectedEndDate: Date = Date()
    @Published var selectedExerciseId: String? = nil
    
    // Analytics data
    @Published var weightProgressionData: [WeightProgressionDataPoint] = []
    @Published var volumeByMuscleGroup: [MuscleGroupVolume] = []
    @Published var workoutFrequency: [WorkoutFrequencyDataPoint] = []
    @Published var estimatedOneRMTrends: [OneRMTrendDataPoint] = []
    
    init(workouts: [Workout] = []) {
        self.workouts = workouts.isEmpty ? [.mock, .mockFriendWorkout] : workouts
        updateAnalytics()
    }
    
    // MARK: - Date Range Management
    func setDateRange(startDate: Date, endDate: Date) {
        self.selectedStartDate = startDate
        self.selectedEndDate = endDate
        updateAnalytics()
    }
    
    func setPresetDateRange(_ range: DateRangePreset) {
        let (start, end) = range.dateRange
        setDateRange(startDate: start, endDate: end)
    }
    
    // MARK: - Analytics Calculations
    private func updateAnalytics() {
        let filteredWorkouts = filterWorkoutsByDateRange()
        
        weightProgressionData = calculateWeightProgression(workouts: filteredWorkouts)
        volumeByMuscleGroup = calculateVolumeByMuscleGroup(workouts: filteredWorkouts)
        workoutFrequency = calculateWorkoutFrequency(workouts: filteredWorkouts)
        estimatedOneRMTrends = calculateOneRMTrends(workouts: filteredWorkouts)
    }
    
    private func filterWorkoutsByDateRange() -> [Workout] {
        workouts.filter { workout in
            workout.startTime >= selectedStartDate && workout.startTime <= selectedEndDate
        }
    }
    
    // MARK: - Weight Progression Calculation
    func calculateWeightProgression(workouts: [Workout]) -> [WeightProgressionDataPoint] {
        var progressionMap: [String: [(Date, Double)]] = [:]
        
        for workout in workouts.sorted(by: { $0.startTime < $1.startTime }) {
            for exerciseWorkout in workout.exercises {
                let exerciseId = exerciseWorkout.exercise.id
                let bestSet = exerciseWorkout.sets.max(by: { $0.weight < $1.weight })
                
                if let bestSet = bestSet {
                    if progressionMap[exerciseId] == nil {
                        progressionMap[exerciseId] = []
                    }
                    progressionMap[exerciseId]?.append((workout.startTime, bestSet.weight))
                }
            }
        }
        
        // Apply filter if specific exercise is selected
        let filteredProgression: [(Date, Double)]
        if let selectedExerciseId = selectedExerciseId,
           let progression = progressionMap[selectedExerciseId] {
            filteredProgression = progression
        } else {
            // Return overall best weight progression
            let allWeights = progressionMap.values.flatMap { $0 }
            filteredProgression = allWeights.sorted(by: { $0.0 < $1.0 })
        }
        
        return filteredProgression.map { date, weight in
            WeightProgressionDataPoint(date: date, weight: weight)
        }
    }
    
    // MARK: - Volume by Muscle Group Calculation
    func calculateVolumeByMuscleGroup(workouts: [Workout]) -> [MuscleGroupVolume] {
        var volumeMap: [MuscleGroup: Double] = [:]
        
        for workout in workouts {
            for exerciseWorkout in workout.exercises {
                for muscleGroup in exerciseWorkout.exercise.muscleGroups {
                    let setVolume = exerciseWorkout.sets.reduce(0) { $0 + $1.volume }
                    volumeMap[muscleGroup, default: 0] += setVolume
                }
            }
        }
        
        return MuscleGroup.allCases.map { group in
            MuscleGroupVolume(muscleGroup: group, volume: volumeMap[group] ?? 0)
        }.sorted(by: { $0.volume > $1.volume })
    }
    
    // MARK: - Workout Frequency Calculation
    func calculateWorkoutFrequency(workouts: [Workout]) -> [WorkoutFrequencyDataPoint] {
        var frequencyMap: [Date: Int] = [:]
        
        for workout in workouts {
            let dayKey = Calendar.current.startOfDay(for: workout.startTime)
            frequencyMap[dayKey, default: 0] += 1
        }
        
        // Create entries for all days in range
        var result: [WorkoutFrequencyDataPoint] = []
        var currentDate = Calendar.current.startOfDay(for: selectedStartDate)
        
        while currentDate <= selectedEndDate {
            result.append(WorkoutFrequencyDataPoint(
                date: currentDate,
                count: frequencyMap[currentDate] ?? 0
            ))
            currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return result
    }
    
    // MARK: - Estimated 1RM Trends Calculation
    func calculateOneRMTrends(workouts: [Workout]) -> [OneRMTrendDataPoint] {
        var oneRMMap: [String: [(Date, Double)]] = [:]
        
        for workout in workouts.sorted(by: { $0.startTime < $1.startTime }) {
            for exerciseWorkout in workout.exercises {
                let exerciseId = exerciseWorkout.exercise.id
                let bestSet = exerciseWorkout.sets.max(by: { $0.estimated1RM < $1.estimated1RM })
                
                if let bestSet = bestSet {
                    if oneRMMap[exerciseId] == nil {
                        oneRMMap[exerciseId] = []
                    }
                    oneRMMap[exerciseId]?.append((workout.startTime, bestSet.estimated1RM))
                }
            }
        }
        
        // Apply filter if specific exercise is selected
        let filteredOneRM: [(Date, Double)]
        if let selectedExerciseId = selectedExerciseId,
           let oneRM = oneRMMap[selectedExerciseId] {
            filteredOneRM = oneRM
        } else {
            // Return overall best 1RM trends
            let allOneRMs = oneRMMap.values.flatMap { $0 }
            filteredOneRM = allOneRMs.sorted(by: { $0.0 < $1.0 })
        }
        
        return filteredOneRM.map { date, oneRM in
            OneRMTrendDataPoint(date: date, estimatedOneRM: oneRM)
        }
    }
    
    // MARK: - Summary Statistics
    var totalWorkouts: Int {
        filterWorkoutsByDateRange().count
    }
    
    var totalVolume: Double {
        filterWorkoutsByDateRange()
            .flatMap { $0.exercises }
            .flatMap { $0.sets }
            .reduce(0) { $0 + $1.volume }
    }
    
    var totalSets: Int {
        filterWorkoutsByDateRange()
            .flatMap { $0.exercises }
            .flatMap { $0.sets }
            .count
    }
    
    var averageWorkoutDuration: TimeInterval {
        let workouts = filterWorkoutsByDateRange()
        guard !workouts.isEmpty else { return 0 }
        let totalDuration = workouts.reduce(0) { $0 + $1.duration }
        return totalDuration / Double(workouts.count)
    }
}

// MARK: - Data Models
struct WeightProgressionDataPoint {
    let date: Date
    let weight: Double
}

struct MuscleGroupVolume {
    let muscleGroup: MuscleGroup
    let volume: Double
}

struct WorkoutFrequencyDataPoint {
    let date: Date
    let count: Int
}

struct OneRMTrendDataPoint {
    let date: Date
    let estimatedOneRM: Double
}

// MARK: - Date Range Preset
enum DateRangePreset: String, CaseIterable {
    case lastWeek = "Last Week"
    case lastMonth = "Last Month"
    case last3Months = "Last 3 Months"
    case lastYear = "Last Year"
    case allTime = "All Time"
    
    var dateRange: (start: Date, end: Date) {
        let now = Date()
        let calendar = Calendar.current
        
        switch self {
        case .lastWeek:
            let start = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            return (start, now)
        case .lastMonth:
            let start = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            return (start, now)
        case .last3Months:
            let start = calendar.date(byAdding: .month, value: -3, to: now) ?? now
            return (start, now)
        case .lastYear:
            let start = calendar.date(byAdding: .year, value: -1, to: now) ?? now
            return (start, now)
        case .allTime:
            let start = calendar.date(byAdding: .year, value: -10, to: now) ?? now
            return (start, now)
        }
    }
}
