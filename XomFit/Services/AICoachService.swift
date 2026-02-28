import Foundation

protocol AICoachServiceProtocol {
    func generateRecommendations(userId: String, workouts: [Workout], userStats: User.UserStats) async throws -> [AIRecommendation]
    func analyzePerformance(userId: String, workouts: [Workout]) async throws -> PerformanceAnalysis
    func recordRecommendationFeedback(userId: String, recommendationId: String, accepted: Bool) async throws
    func getPersonalizedProgram(userId: String, workouts: [Workout], preferences: UserTrainingPreferences) async throws -> ProgramRecommendation
}

class AICoachService: AICoachServiceProtocol {
    static let shared = AICoachService()
    
    private let apiService: APIServiceProtocol
    private var learningState: [String: RecommendationLearning] = [:]
    
    init(apiService: APIServiceProtocol = APIService.shared) {
        self.apiService = apiService
    }
    
    // MARK: - Main Recommendation Engine
    
    func generateRecommendations(userId: String, workouts: [Workout], userStats: User.UserStats) async throws -> [AIRecommendation] {
        guard !workouts.isEmpty else {
            return [generateInitialRecommendation(userId: userId)]
        }
        
        let analysis = try await analyzePerformance(userId: userId, workouts: workouts)
        var recommendations: [AIRecommendation] = []
        
        // 1. Detect weak muscle groups
        recommendations.append(contentsOf: generateWeakPointRecommendations(userId: userId, analysis: analysis, workouts: workouts))
        
        // 2. Detect muscle imbalances
        recommendations.append(contentsOf: generateBalanceRecommendations(userId: userId, analysis: analysis))
        
        // 3. Detect plateaus
        recommendations.append(contentsOf: generatePlateauRecommendations(userId: userId, analysis: analysis, workouts: workouts))
        
        // 4. Volume progression
        recommendations.append(contentsOf: generateVolumeRecommendations(userId: userId, analysis: analysis))
        
        // 5. Deload recommendations
        if shouldRecommendDeload(workouts: workouts, analysis: analysis) {
            recommendations.append(generateDeloadRecommendation(userId: userId, workouts: workouts))
        }
        
        // Sort by confidence (highest first) and limit to top 5
        return Array(recommendations
            .sorted { $0.confidence > $1.confidence }
            .prefix(5))
    }
    
    // MARK: - Performance Analysis
    
    func analyzePerformance(userId: String, workouts: [Workout]) async throws -> PerformanceAnalysis {
        let sortedWorkouts = workouts.sorted { $0.startTime > $1.startTime }
        
        // Analyze volume progression
        let volumeProgress = analyzeVolumeProgression(workouts: sortedWorkouts)
        
        // Analyze strength progression
        let strengthProgress = analyzeStrengthProgression(workouts: sortedWorkouts)
        
        // Muscle group analysis
        let muscleGroupsAnalysis = analyzeMuscleGroups(workouts: sortedWorkouts)
        
        // Detect imbalances
        let imbalances = detectImbalances(muscleGroupsAnalysis: muscleGroupsAnalysis)
        
        // Estimate maxes
        let estimatedMaxes = estimateOneRepMaxes(workouts: sortedWorkouts)
        
        return PerformanceAnalysis(
            muscleGroupsAnalysis: muscleGroupsAnalysis,
            volumeProgression: volumeProgress,
            strengthProgression: strengthProgress,
            imbalances: imbalances,
            estimatedMaxes: estimatedMaxes
        )
    }
    
    // MARK: - Recommendation Generation Methods
    
    private func generateInitialRecommendation(userId: String) -> AIRecommendation {
        return AIRecommendation(
            userId: userId,
            type: .newProgram,
            program: ProgramRecommendation(
                name: "Beginner Full Body Strength",
                weekDuration: 3,
                splitType: .fullBody,
                focusAreas: [.chest, .back, .quads, .hamstrings, .shoulders],
                estimatedDaysPerWeek: 3,
                reasoning: "Start with a 3-day full body program to build foundational strength and learn proper form.",
                estimatedDurationWeeks: 8
            ),
            confidence: 0.95,
            reasoning: "You're just starting out! A full body routine 3 days/week is perfect for building a strong foundation."
        )
    }
    
    private func generateWeakPointRecommendations(userId: String, analysis: PerformanceAnalysis, workouts: [Workout]) -> [AIRecommendation] {
        var recommendations: [AIRecommendation] = []
        
        let weakGroups = analysis.muscleGroupsAnalysis.filter { $0.status == .weak }
        
        for weak in weakGroups {
            if let suggestion = suggestExerciseForMuscleGroup(weak.muscleGroup, workouts: workouts) {
                let rec = AIRecommendation(
                    userId: userId,
                    type: .weakPoint,
                    exercise: suggestion,
                    confidence: 0.80,
                    reasoning: "Your \(weak.muscleGroup.displayName) training is underemphasized. Add \(suggestion.exercise.name) to address this."
                )
                recommendations.append(rec)
            }
        }
        
        return recommendations
    }
    
    private func generateBalanceRecommendations(userId: String, analysis: PerformanceAnalysis) -> [AIRecommendation] {
        var recommendations: [AIRecommendation] = []
        
        for imbalance in analysis.imbalances where imbalance.severity != .minor {
            let recommendation = AIRecommendation(
                userId: userId,
                type: .exercise,
                exercise: nil, // Could suggest replacement
                confidence: 0.75,
                reasoning: imbalance.recommendation
            )
            recommendations.append(recommendation)
        }
        
        return recommendations
    }
    
    private func generatePlateauRecommendations(userId: String, analysis: PerformanceAnalysis, workouts: [Workout]) -> [AIRecommendation] {
        var recommendations: [AIRecommendation] = []
        
        let plateaued = analysis.muscleGroupsAnalysis.filter { $0.status == .plateaued }
        
        for group in plateaued {
            // Recommend rep range change or exercise swap
            let recommendation = AIRecommendation(
                userId: userId,
                type: .repRange,
                confidence: 0.72,
                reasoning: "Your \(group.muscleGroup.displayName) progress has stalled. Try lower reps (3-5) to break through the plateau."
            )
            recommendations.append(recommendation)
        }
        
        return recommendations
    }
    
    private func generateVolumeRecommendations(userId: String, analysis: PerformanceAnalysis) -> [AIRecommendation] {
        var recommendations: [AIRecommendation] = []
        
        if analysis.volumeProgression.trend == .down {
            let recommendation = AIRecommendation(
                userId: userId,
                type: .volumeProgression,
                confidence: 0.78,
                reasoning: "Your volume has declined recently. Gradually increase sets or reps to get back on track."
            )
            recommendations.append(recommendation)
        } else if analysis.volumeProgression.trend == .up {
            let recommendation = AIRecommendation(
                userId: userId,
                type: .volumeProgression,
                confidence: 0.80,
                reasoning: "Great momentum! Your volume is increasing. Maintain this trajectory for continued progress."
            )
            recommendations.append(recommendation)
        }
        
        return recommendations
    }
    
    private func generateDeloadRecommendation(userId: String, workouts: [Workout]) -> AIRecommendation {
        return AIRecommendation(
            userId: userId,
            type: .restPeriod,
            confidence: 0.70,
            reasoning: "You've logged intense training recently. Consider a deload week (50-60% intensity) to promote recovery and prevent burnout."
        )
    }
    
    // MARK: - Analysis Helpers
    
    private func analyzeVolumeProgression(workouts: [Workout]) -> PerformanceAnalysis.VolumeProgress {
        let lastMonth = workouts.filter { $0.startTime > Date().addingTimeInterval(-86400 * 30) }
        let lastThreeMonths = workouts.filter { $0.startTime > Date().addingTimeInterval(-86400 * 90) }
        
        let lastMonthVolume = lastMonth.reduce(0) { $0 + $1.totalVolume }
        let lastThreeMonthsVolume = lastThreeMonths.reduce(0) { $0 + $1.totalVolume }
        
        let trend: PerformanceAnalysis.Trend
        if lastMonthVolume > lastThreeMonthsVolume / 3 * 1.2 {
            trend = .up
        } else if lastMonthVolume < lastThreeMonthsVolume / 3 * 0.8 {
            trend = .down
        } else {
            trend = .stable
        }
        
        return PerformanceAnalysis.VolumeProgress(
            totalLastMonth: lastMonthVolume,
            totalLastThreeMonths: lastThreeMonthsVolume,
            trend: trend,
            recommendation: "Maintain current volume or increase by 10% weekly for progression."
        )
    }
    
    private func analyzeStrengthProgression(workouts: [Workout]) -> PerformanceAnalysis.StrengthProgress {
        let lastMonth = workouts.filter { $0.startTime > Date().addingTimeInterval(-86400 * 30) }
        let prs = lastMonth.flatMap { $0.exercises }.flatMap { $0.sets }.filter { $0.isPersonalRecord }.count
        
        let rpeSum = lastMonth.flatMap { $0.exercises }.flatMap { $0.sets }.reduce(0) { $0 + $1.rpe }
        let avgRPE = lastMonth.flatMap { $0.exercises }.flatMap { $0.sets }.isEmpty ? 0 : 
            Double(rpeSum) / Double(lastMonth.flatMap { $0.exercises }.flatMap { $0.sets }.count)
        
        let rpe9Plus = lastMonth.flatMap { $0.exercises }.flatMap { $0.sets }.filter { $0.rpe >= 9 }.count
        
        let trend: PerformanceAnalysis.Trend = prs > 2 ? .up : (avgRPE < 7 ? .down : .stable)
        
        return PerformanceAnalysis.StrengthProgress(
            prsSinceDate: prs,
            averageRPELastMonth: avgRPE,
            rpe9PlusCount: rpe9Plus,
            trend: trend
        )
    }
    
    private func analyzeMuscleGroups(workouts: [Workout]) -> [PerformanceAnalysis.MuscleGroupAnalysis] {
        var analysis: [MuscleGroup: PerformanceAnalysis.MuscleGroupAnalysis] = [:]
        
        for group in MuscleGroup.allCases {
            let relatedWorkouts = workouts.filter { workout in
                workout.muscleGroups.contains(group)
            }
            
            let frequency: ExerciseFrequency
            let workoutsPerMonth = Double(relatedWorkouts.filter { $0.startTime > Date().addingTimeInterval(-86400 * 30) }.count)
            
            if workoutsPerMonth < 0.25 {
                frequency = .rare
            } else if workoutsPerMonth < 1 {
                frequency = .occasional
            } else if workoutsPerMonth < 3 {
                frequency = .regular
            } else {
                frequency = .frequent
            }
            
            let totalVolume = relatedWorkouts.reduce(0) { $0 + $1.totalVolume }
            let status: TrainingStatus
            
            if frequency == .rare {
                status = .weak
            } else if relatedWorkouts.count >= 3 {
                let recentPRs = relatedWorkouts.prefix(3).flatMap { $0.exercises }.flatMap { $0.sets }.filter { $0.isPersonalRecord }.count
                status = recentPRs == 0 ? .plateaued : .balanced
            } else {
                status = .balanced
            }
            
            analysis[group] = PerformanceAnalysis.MuscleGroupAnalysis(
                muscleGroup: group,
                lastWorked: relatedWorkouts.first?.startTime,
                frequency: frequency,
                relativeVolume: Double(relatedWorkouts.count) / Double(max(1, workouts.count)),
                status: status
            )
        }
        
        return Array(analysis.values)
    }
    
    private func detectImbalances(muscleGroupsAnalysis: [PerformanceAnalysis.MuscleGroupAnalysis]) -> [PerformanceAnalysis.Imbalance] {
        var imbalances: [PerformanceAnalysis.Imbalance] = []
        
        let sorted = muscleGroupsAnalysis.sorted { $0.relativeVolume > $1.relativeVolume }
        
        for i in 0..<sorted.count {
            for j in (i+1)..<sorted.count {
                let ratio = sorted[i].relativeVolume / max(0.01, sorted[j].relativeVolume)
                if ratio > 1.5 {
                    let severity: PerformanceAnalysis.SeverityLevel = ratio > 3 ? .severe : .moderate
                    imbalances.append(PerformanceAnalysis.Imbalance(
                        muscleGroup1: sorted[i].muscleGroup,
                        muscleGroup2: sorted[j].muscleGroup,
                        volumeRatio: ratio,
                        severity: severity,
                        recommendation: "Increase \(sorted[j].muscleGroup.displayName) training to balance with \(sorted[i].muscleGroup.displayName)."
                    ))
                }
            }
        }
        
        return imbalances
    }
    
    private func estimateOneRepMaxes(workouts: [Workout]) -> [PerformanceAnalysis.ExerciseMax] {
        var exercisesMaxes: [String: (Double, Int)] = [:]
        
        for workout in workouts {
            for exercise in workout.exercises {
                for set in exercise.sets {
                    let estimated1RM = estimate1RM(weight: set.weight, reps: set.reps, rpe: set.rpe)
                    if let (currentMax, count) = exercisesMaxes[exercise.exercise.id] {
                        let newMax = max(currentMax, estimated1RM)
                        exercisesMaxes[exercise.exercise.id] = (newMax, count + 1)
                    } else {
                        exercisesMaxes[exercise.exercise.id] = (estimated1RM, 1)
                    }
                }
            }
        }
        
        return exercisesMaxes.map { (id, data) in
            PerformanceAnalysis.ExerciseMax(
                exerciseId: id,
                exerciseName: "Exercise",
                estimatedMax: data.0,
                basedOnSets: data.1,
                confidence: min(1.0, Double(data.1) / 10.0)
            )
        }
    }
    
    private func estimate1RM(weight: Double, reps: Int, rpe: Double) -> Double {
        // Brzycki formula adjusted for RPE
        let repsAdjusted = Double(reps) + (10 - rpe)
        return weight * (36 / (37 - repsAdjusted))
    }
    
    private func suggestExerciseForMuscleGroup(_ group: MuscleGroup, workouts: [Workout]) -> ExerciseRecommendation? {
        let exercises = Exercise.mockExercises.filter { $0.muscleGroups.contains(group) }
        guard let suggested = exercises.first else { return nil }
        
        return ExerciseRecommendation(
            exercise: suggested,
            reps: ExerciseRecommendation.IntRange(min: 8, max: 12),
            sets: 3,
            restSeconds: 90,
            reasoning: "Target \(group.displayName) development.",
            replacesExercise: nil
        )
    }
    
    private func shouldRecommendDeload(workouts: [Workout], analysis: PerformanceAnalysis) -> Bool {
        let recentWorkouts = workouts.filter { $0.startTime > Date().addingTimeInterval(-86400 * 30) }
        let recentHighIntensity = recentWorkouts.flatMap { $0.exercises }.flatMap { $0.sets }.filter { $0.rpe >= 8.5 }.count
        
        return recentHighIntensity > 15
    }
    
    // MARK: - Personalized Program Generation
    
    func getPersonalizedProgram(userId: String, workouts: [Workout], preferences: UserTrainingPreferences) async throws -> ProgramRecommendation {
        let analysis = try await analyzePerformance(userId: userId, workouts: workouts)
        
        let focusAreas = analysis.muscleGroupsAnalysis
            .filter { $0.status == .weak || $0.status == .plateaued }
            .sorted { $0.relativeVolume < $1.relativeVolume }
            .prefix(3)
            .map { $0.muscleGroup }
        
        return ProgramRecommendation(
            name: generateProgramName(for: preferences.preferredSplit, focusAreas: Array(focusAreas)),
            weekDuration: 4,
            splitType: preferences.preferredSplit,
            focusAreas: Array(focusAreas),
            estimatedDaysPerWeek: preferences.targetDaysPerWeek,
            reasoning: "Program customized to your preferences and current weak points.",
            estimatedDurationWeeks: 12
        )
    }
    
    private func generateProgramName(for split: ProgramRecommendation.SplitType, focusAreas: [MuscleGroup]) -> String {
        let focusString = focusAreas.prefix(2).map { $0.displayName }.joined(separator: "/")
        return "\(split.displayName) - \(focusString) Focus"
    }
    
    // MARK: - Feedback Recording
    
    func recordRecommendationFeedback(userId: String, recommendationId: String, accepted: Bool) async throws {
        if learningState[userId] == nil {
            learningState[userId] = RecommendationLearning()
        }
        learningState[userId]?.recordFeedback(recommendationId: recommendationId, accepted: accepted)
    }
}
