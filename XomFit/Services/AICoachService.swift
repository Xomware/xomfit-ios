import Foundation

// MARK: - AI Coach Service Protocol
protocol AICoachServiceProtocol {
    func calculateReadiness(from workouts: [Workout]) -> ReadinessScore
    func generateInsights(from workouts: [Workout]) -> [CoachInsight]
    func generateRecommendations(userId: String, workouts: [Workout], userStats: User.UserStats?) -> [AIRecommendation]
    func analyzePerformance(userId: String, workouts: [Workout]) -> PerformanceAnalysis
    func generatePeriodizationPlan(currentPhase: PeriodizationPhase) -> [PeriodizationBlock]
    func calculateTrainingLoad(from workouts: [Workout]) -> TrainingLoad
    func calculateMuscleGroupVolumes(from workouts: [Workout]) -> [MuscleGroupVolume]
}

class AICoachService: ObservableObject, AICoachServiceProtocol {
    static let shared = AICoachService()

    private var learningState = RecommendationLearning()

    // MARK: - Readiness Score
    func calculateReadiness(from workouts: [Workout]) -> ReadinessScore {
        let now = Date()
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        let fourteenDaysAgo = Calendar.current.date(byAdding: .day, value: -14, to: now)!

        let recentWorkouts = workouts.filter { $0.startTime >= sevenDaysAgo }
        let previousWorkouts = workouts.filter { $0.startTime >= fourteenDaysAgo && $0.startTime < sevenDaysAgo }

        let recentSets = recentWorkouts.reduce(0) { $0 + $1.totalSets }
        let volumeScore = min(Int(Double(recentSets) / 20.0 * 100), 100)

        let workoutDays = Set(recentWorkouts.map { Calendar.current.startOfDay(for: $0.startTime) }).count
        let consistencyScore = min(workoutDays * 20, 100)

        let lastWorkout = workouts.sorted { $0.startTime > $1.startTime }.first
        let daysSinceLastWorkout = lastWorkout.map { Int(now.timeIntervalSince($0.startTime) / 86400) } ?? 7
        let recoveryScore = min(daysSinceLastWorkout * 25, 100)

        let previousSets = previousWorkouts.reduce(0) { $0 + $1.totalSets }
        let prMomentumScore = previousSets > 0
            ? min(Int(Double(recentSets) / Double(previousSets) * 75), 100)
            : 50

        let components = ReadinessScore.ReadinessComponents(
            recentVolume: volumeScore,
            consistency: consistencyScore,
            recoveryDays: recoveryScore,
            prMomentum: prMomentumScore
        )

        let overallScore = (volumeScore + consistencyScore + recoveryScore + prMomentumScore) / 4

        let fatigue: FatigueLevel
        switch overallScore {
        case 75...: fatigue = .fresh
        case 50..<75: fatigue = .moderate
        case 25..<50: fatigue = .fatigued
        default: fatigue = .overreached
        }

        let recommendation: String
        switch fatigue {
        case .fresh: recommendation = "You're primed for a heavy session. Push for PRs today."
        case .moderate: recommendation = "Good energy levels. Stick to your program."
        case .fatigued: recommendation = "Consider a lighter session or active recovery today."
        case .overreached: recommendation = "Your body needs rest. Take 1-2 days off."
        }

        return ReadinessScore(score: overallScore, fatigueLevel: fatigue,
                              components: components, recommendation: recommendation)
    }

    // Convenience overload using WorkoutStore
    @MainActor
    func calculateReadiness() -> ReadinessScore {
        calculateReadiness(from: WorkoutStore.shared.workouts)
    }

    // MARK: - Generate Insights
    func generateInsights(from workouts: [Workout]) -> [CoachInsight] {
        var insights: [CoachInsight] = []
        let now = Date()
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        let recentWorkouts = workouts.filter { $0.startTime >= sevenDaysAgo }

        let totalRecentSets = recentWorkouts.reduce(0) { $0 + $1.totalSets }
        if totalRecentSets > 80 && recentWorkouts.count >= 5 {
            insights.append(CoachInsight(
                type: .deloadSuggestion,
                title: "Deload Week Recommended",
                message: "You've logged \(totalRecentSets) sets this week across \(recentWorkouts.count) sessions. A deload at 50% volume will drive supercompensation.",
                confidence: 0.85,
                actionLabel: "Schedule Deload",
                priority: 1
            ))
        }

        if let lastWorkout = workouts.sorted(by: { $0.startTime > $1.startTime }).first {
            let allSets = lastWorkout.exercises.flatMap { $0.sets }
            let heaviestSet = allSets.sorted(by: { $0.weight > $1.weight }).first
            if let set = heaviestSet {
                let exerciseName = lastWorkout.exercises.first { $0.sets.contains(where: { $0.id == set.id }) }?.exercise.name ?? "your last exercise"
                insights.append(CoachInsight(
                    type: .progressiveOverload,
                    title: "Progressive Overload Opportunity",
                    message: "You've hit \(Int(set.weight))lbs on \(exerciseName) 2+ times. Try adding 5lbs next session.",
                    confidence: 0.78,
                    actionLabel: "Got It",
                    priority: 2
                ))
            }
        }

        let muscleVolumes = calculateMuscleGroupVolumes(from: workouts)
        for vol in muscleVolumes where vol.percentOfTarget < 0.5 {
            insights.append(CoachInsight(
                type: .volumeRecommendation,
                title: "\(vol.muscleGroup) Volume Low",
                message: "You're at \(vol.currentWeeklySets)/\(vol.weeklySetTarget) sets for \(vol.muscleGroup) this week. Add a session to hit minimum effective volume.",
                confidence: 0.9,
                priority: 2
            ))
        }

        if recentWorkouts.isEmpty {
            insights.append(CoachInsight(
                type: .recoveryAlert,
                title: "No Workouts This Week",
                message: "It's been 7+ days since your last session. Even a 20-minute workout maintains momentum.",
                confidence: 1.0,
                actionLabel: "Start Workout",
                priority: 1
            ))
        }

        let readiness = calculateReadiness(from: workouts)
        if readiness.score > 75 {
            insights.append(CoachInsight(
                type: .prOpportunity,
                title: "Perfect Day for a PR",
                message: "Your readiness score is \(readiness.score)/100. Conditions are ideal for a personal record attempt.",
                confidence: 0.72,
                actionLabel: "View PR Targets",
                priority: 2
            ))
        }

        return insights.sorted { $0.priority < $1.priority }
    }

    @MainActor
    func generateInsights() -> [CoachInsight] {
        generateInsights(from: WorkoutStore.shared.workouts)
    }

    // MARK: - Generate Recommendations
    func generateRecommendations(userId: String, workouts: [Workout], userStats: User.UserStats? = nil) -> [AIRecommendation] {
        guard !workouts.isEmpty else { return [] }

        var recommendations: [AIRecommendation] = []
        let analysis = analyzePerformance(userId: userId, workouts: workouts)

        // 1. Weak point detection
        for group in analysis.muscleGroupsAnalysis where group.status == .weak {
            let exercise = suggestExercise(for: group.muscleGroup)
            recommendations.append(AIRecommendation(
                userId: userId,
                type: .weakPoint,
                exercise: ExerciseRecommendation(
                    exercise: exercise,
                    reps: ExerciseRecommendation.IntRange(min: 8, max: 12),
                    sets: 3,
                    restSeconds: 120,
                    reasoning: "\(group.muscleGroup.displayName) is undertrained (\(group.frequency.displayName)). Add \(exercise.name) to address the gap.",
                    replacesExercise: nil
                ),
                confidence: 0.80,
                reasoning: "Detected weak point: \(group.muscleGroup.displayName) trained \(group.frequency.displayName)."
            ))
        }

        // 2. Imbalance detection
        for imbalance in analysis.imbalances where imbalance.severity != .minor {
            let exercise = suggestExercise(for: imbalance.muscleGroup2)
            recommendations.append(AIRecommendation(
                userId: userId,
                type: .exerciseSwap,
                exercise: ExerciseRecommendation(
                    exercise: exercise,
                    reps: ExerciseRecommendation.IntRange(min: 8, max: 15),
                    sets: 3,
                    restSeconds: 90,
                    reasoning: imbalance.recommendation,
                    replacesExercise: nil
                ),
                confidence: 0.75,
                reasoning: "Imbalance detected: \(imbalance.muscleGroup1.displayName) vs \(imbalance.muscleGroup2.displayName) (\(String(format: "%.1f", imbalance.volumeRatio))x ratio)."
            ))
        }

        // 3. Plateau detection
        if analysis.strengthProgression.trend == .stable && analysis.strengthProgression.averageRPELastMonth > 8.0 {
            recommendations.append(AIRecommendation(
                userId: userId,
                type: .plateau,
                confidence: 0.72,
                reasoning: "Your strength progress has plateaued with high RPE (\(String(format: "%.1f", analysis.strengthProgression.averageRPELastMonth))). Consider changing rep ranges or adding variation."
            ))
        }

        // 4. Volume progression
        switch analysis.volumeProgression.trend {
        case .down:
            recommendations.append(AIRecommendation(
                userId: userId,
                type: .volumeProgression,
                confidence: 0.78,
                reasoning: "Training volume has decreased. \(analysis.volumeProgression.recommendation)"
            ))
        case .up:
            recommendations.append(AIRecommendation(
                userId: userId,
                type: .volumeProgression,
                confidence: 0.80,
                reasoning: "Volume is trending up nicely. \(analysis.volumeProgression.recommendation)"
            ))
        case .stable:
            break
        }

        // 5. Deload suggestion
        if analysis.strengthProgression.rpe9PlusCount > 15 {
            recommendations.append(AIRecommendation(
                userId: userId,
                type: .restPeriod,
                confidence: 0.70,
                reasoning: "You have \(analysis.strengthProgression.rpe9PlusCount) high-intensity sets (RPE 9+) this month. Schedule a deload week at 50-60% intensity."
            ))
        }

        // 6. Program recommendation based on data completeness
        if let stats = userStats, stats.totalWorkouts >= 20 {
            let split: ProgramRecommendation.SplitType = stats.totalWorkouts > 100 ? .pushPullLegs : .upperLower
            recommendations.append(AIRecommendation(
                userId: userId,
                type: .newProgram,
                program: ProgramRecommendation(
                    name: "Personalized \(split.displayName) Program",
                    weekDuration: 4,
                    splitType: split,
                    focusAreas: analysis.muscleGroupsAnalysis.filter { $0.status == .weak }.map { $0.muscleGroup },
                    estimatedDaysPerWeek: split == .pushPullLegs ? 6 : 4,
                    reasoning: "Based on \(stats.totalWorkouts) workouts and your current performance profile.",
                    estimatedDurationWeeks: 12
                ),
                confidence: stats.totalWorkouts > 100 ? 0.90 : 0.85,
                reasoning: "Data completeness is high enough for a personalized program recommendation."
            ))
        }

        // Sort by confidence, limit to top 5
        return Array(recommendations.sorted { $0.confidence > $1.confidence }.prefix(5))
    }

    // MARK: - Analyze Performance
    func analyzePerformance(userId: String, workouts: [Workout]) -> PerformanceAnalysis {
        let userWorkouts = workouts.filter { $0.userId == userId }
        let now = Date()
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: now)!
        let ninetyDaysAgo = Calendar.current.date(byAdding: .day, value: -90, to: now)!

        let recentWorkouts = userWorkouts.filter { $0.startTime >= thirtyDaysAgo }
        let olderWorkouts = userWorkouts.filter { $0.startTime >= ninetyDaysAgo }

        // Muscle group analysis
        let muscleGroupsAnalysis = analyzeMuscleGroups(workouts: recentWorkouts)

        // Volume progression
        let recentVolume = recentWorkouts.reduce(0.0) { $0 + $1.totalVolume }
        let olderVolume = olderWorkouts.reduce(0.0) { $0 + $1.totalVolume }
        let volumeTrend: PerformanceAnalysis.Trend
        if olderVolume > 0 {
            let ratio = recentVolume / (olderVolume / 3.0)
            if ratio > 1.2 { volumeTrend = .up }
            else if ratio < 0.8 { volumeTrend = .down }
            else { volumeTrend = .stable }
        } else {
            volumeTrend = .stable
        }

        let volumeRecommendation: String
        switch volumeTrend {
        case .up: volumeRecommendation = "Volume is increasing well. Monitor recovery to avoid overtraining."
        case .down: volumeRecommendation = "Volume is decreasing. Consider adding sets if recovery allows."
        case .stable: volumeRecommendation = "Volume is stable. Consider progressive overload to drive adaptation."
        }

        let volumeProgression = PerformanceAnalysis.VolumeProgress(
            totalLastMonth: recentVolume,
            totalLastThreeMonths: olderVolume,
            trend: volumeTrend,
            recommendation: volumeRecommendation
        )

        // Strength progression
        let allRecentSets = recentWorkouts.flatMap { $0.exercises.flatMap { $0.sets } }
        let prCount = allRecentSets.filter { $0.isPersonalRecord }.count
        let rpeValues = allRecentSets.compactMap { $0.rpe }
        let avgRPE = rpeValues.isEmpty ? 0 : rpeValues.reduce(0, +) / Double(rpeValues.count)
        let rpe9Plus = rpeValues.filter { $0 >= 9.0 }.count

        let strengthTrend: PerformanceAnalysis.Trend
        if prCount >= 3 { strengthTrend = .up }
        else if prCount == 0 && avgRPE > 8.5 { strengthTrend = .stable }
        else { strengthTrend = avgRPE > 7.0 ? .up : .down }

        let strengthProgression = PerformanceAnalysis.StrengthProgress(
            prsSinceDate: prCount,
            averageRPELastMonth: avgRPE,
            rpe9PlusCount: rpe9Plus,
            trend: strengthTrend
        )

        // Imbalances
        let imbalances = detectImbalances(muscleGroups: muscleGroupsAnalysis)

        // Estimated maxes
        let estimatedMaxes = calculateEstimatedMaxes(workouts: recentWorkouts)

        return PerformanceAnalysis(
            muscleGroupsAnalysis: muscleGroupsAnalysis,
            volumeProgression: volumeProgression,
            strengthProgression: strengthProgression,
            imbalances: imbalances,
            estimatedMaxes: estimatedMaxes
        )
    }

    // MARK: - Feedback
    func recordFeedback(recommendationId: String, accepted: Bool) {
        learningState.recordFeedback(recommendationId: recommendationId, accepted: accepted)
    }

    // MARK: - Periodization
    func generatePeriodizationPlan(currentPhase: PeriodizationPhase = .accumulation) -> [PeriodizationBlock] {
        [
            PeriodizationBlock(phase: .accumulation, weekNumber: 1, targetVolume: 20, targetIntensity: 0.70,
                notes: "Build work capacity. Focus on form and volume."),
            PeriodizationBlock(phase: .accumulation, weekNumber: 2, targetVolume: 24, targetIntensity: 0.72,
                notes: "Increase sets by 20%. Keep RPE 7-8."),
            PeriodizationBlock(phase: .intensification, weekNumber: 3, targetVolume: 20, targetIntensity: 0.80,
                notes: "Reduce volume, increase intensity. Heavier weights."),
            PeriodizationBlock(phase: .intensification, weekNumber: 4, targetVolume: 18, targetIntensity: 0.85,
                notes: "Push intensity. RPE 8-9 on main lifts."),
            PeriodizationBlock(phase: .realization, weekNumber: 5, targetVolume: 14, targetIntensity: 0.90,
                notes: "Peak week. Attempt PRs on key lifts."),
            PeriodizationBlock(phase: .deload, weekNumber: 6, targetVolume: 10, targetIntensity: 0.65,
                notes: "Active recovery. 50% volume, maintain movement patterns.")
        ]
    }

    // MARK: - Training Load
    func calculateTrainingLoad(from workouts: [Workout]) -> TrainingLoad {
        let now = Date()
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        let twentyEightDaysAgo = Calendar.current.date(byAdding: .day, value: -28, to: now)!

        let acute = Double(workouts.filter { $0.startTime >= sevenDaysAgo }.reduce(0) { $0 + $1.totalSets })
        let chronic = Double(workouts.filter { $0.startTime >= twentyEightDaysAgo }.reduce(0) { $0 + $1.totalSets }) / 4.0

        return TrainingLoad(acute: acute, chronic: max(chronic, 1))
    }

    @MainActor
    func calculateTrainingLoad() -> TrainingLoad {
        calculateTrainingLoad(from: WorkoutStore.shared.workouts)
    }

    // MARK: - Muscle Group Volumes
    func calculateMuscleGroupVolumes(from workouts: [Workout]) -> [MuscleGroupVolume] {
        let now = Date()
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        let recentExercises = workouts.filter { $0.startTime >= sevenDaysAgo }.flatMap { $0.exercises }

        let targets: [(String, Int, [String])] = [
            ("Chest", 10, ["Bench Press", "Push-up", "Fly", "Dip"]),
            ("Back", 12, ["Pull-up", "Row", "Lat Pulldown", "Deadlift"]),
            ("Legs", 12, ["Squat", "Leg Press", "Lunge", "Leg Curl"]),
            ("Shoulders", 8, ["Press", "Lateral Raise", "Front Raise"]),
            ("Arms", 8, ["Curl", "Tricep", "Hammer Curl"]),
            ("Core", 6, ["Plank", "Crunch", "Ab", "Core"])
        ]

        return targets.map { (muscle, target, keywords) in
            let count = recentExercises.filter { exercise in
                keywords.contains(where: { exercise.exercise.name.localizedCaseInsensitiveContains($0) })
            }.reduce(0) { $0 + $1.sets.count }
            return MuscleGroupVolume(muscleGroup: muscle, weeklySetTarget: target, currentWeeklySets: count)
        }
    }

    @MainActor
    func calculateMuscleGroupVolumes() -> [MuscleGroupVolume] {
        calculateMuscleGroupVolumes(from: WorkoutStore.shared.workouts)
    }

    // MARK: - Private Helpers

    private func analyzeMuscleGroups(workouts: [Workout]) -> [PerformanceAnalysis.MuscleGroupAnalysis] {
        var muscleGroupData: [MuscleGroup: (lastWorked: Date?, setCount: Int)] = [:]

        for muscleGroup in MuscleGroup.allCases {
            muscleGroupData[muscleGroup] = (lastWorked: nil, setCount: 0)
        }

        for workout in workouts {
            for exercise in workout.exercises {
                for muscleGroup in exercise.exercise.muscleGroups {
                    let existing = muscleGroupData[muscleGroup] ?? (nil, 0)
                    let lastWorked: Date?
                    if let existingDate = existing.lastWorked {
                        lastWorked = max(existingDate, workout.startTime)
                    } else {
                        lastWorked = workout.startTime
                    }
                    muscleGroupData[muscleGroup] = (lastWorked: lastWorked, setCount: existing.setCount + exercise.sets.count)
                }
            }
        }

        let allSets = workouts.flatMap { $0.exercises }
        let totalSets = max(allSets.reduce(0) { $0 + $1.sets.count }, 1)

        return MuscleGroup.allCases.map { muscleGroup in
            let data = muscleGroupData[muscleGroup] ?? (nil, 0)
            let relativeVolume = Double(data.setCount) / Double(totalSets)

            let frequency: ExerciseFrequency
            let weeksWithTraining = data.setCount
            if weeksWithTraining == 0 { frequency = .rare }
            else if weeksWithTraining <= 3 { frequency = .occasional }
            else if weeksWithTraining <= 10 { frequency = .regular }
            else { frequency = .frequent }

            let status: TrainingStatus
            if frequency == .rare { status = .weak }
            else if relativeVolume > 0.3 { status = .overworked }
            else if relativeVolume < 0.05 && frequency != .rare { status = .plateaued }
            else { status = .balanced }

            return PerformanceAnalysis.MuscleGroupAnalysis(
                muscleGroup: muscleGroup,
                lastWorked: data.lastWorked,
                frequency: frequency,
                relativeVolume: relativeVolume,
                status: status
            )
        }
    }

    private func detectImbalances(muscleGroups: [PerformanceAnalysis.MuscleGroupAnalysis]) -> [PerformanceAnalysis.Imbalance] {
        var imbalances: [PerformanceAnalysis.Imbalance] = []

        let pairs: [(MuscleGroup, MuscleGroup)] = [
            (.chest, .back),
            (.quads, .hamstrings),
            (.biceps, .triceps),
            (.shoulders, .back)
        ]

        for (group1, group2) in pairs {
            guard let analysis1 = muscleGroups.first(where: { $0.muscleGroup == group1 }),
                  let analysis2 = muscleGroups.first(where: { $0.muscleGroup == group2 }) else { continue }

            let vol1 = max(analysis1.relativeVolume, 0.01)
            let vol2 = max(analysis2.relativeVolume, 0.01)
            let ratio = max(vol1, vol2) / min(vol1, vol2)

            guard ratio > 1.5 else { continue }

            let severity: PerformanceAnalysis.SeverityLevel
            if ratio > 3.0 { severity = .severe }
            else if ratio > 2.0 { severity = .moderate }
            else { severity = .minor }

            let dominant = vol1 > vol2 ? group1 : group2
            let weaker = vol1 > vol2 ? group2 : group1

            imbalances.append(PerformanceAnalysis.Imbalance(
                muscleGroup1: dominant,
                muscleGroup2: weaker,
                volumeRatio: ratio,
                severity: severity,
                recommendation: "Increase \(weaker.displayName) training to match \(dominant.displayName) volume."
            ))
        }

        return imbalances
    }

    private func calculateEstimatedMaxes(workouts: [Workout]) -> [PerformanceAnalysis.ExerciseMax] {
        var bestSets: [String: (name: String, weight: Double, reps: Int, rpe: Double?, count: Int)] = [:]

        for workout in workouts {
            for exercise in workout.exercises {
                for set in exercise.sets {
                    let existing = bestSets[exercise.exercise.id]
                    let currentEstMax = Exercise.estimateMax(weight: set.weight, reps: set.reps)
                    let existingEstMax = existing.map { Exercise.estimateMax(weight: $0.weight, reps: $0.reps) } ?? 0
                    if currentEstMax > existingEstMax {
                        bestSets[exercise.exercise.id] = (
                            name: exercise.exercise.name,
                            weight: set.weight,
                            reps: set.reps,
                            rpe: set.rpe,
                            count: (existing?.count ?? 0) + 1
                        )
                    }
                }
            }
        }

        return bestSets.map { (exerciseId, data) in
            let estimated1RM = Exercise.estimateMax(weight: data.weight, reps: data.reps)
            let confidence = min(Double(data.count) / 10.0, 1.0)
            return PerformanceAnalysis.ExerciseMax(
                exerciseId: exerciseId,
                exerciseName: data.name,
                estimatedMax: estimated1RM,
                basedOnSets: data.count,
                confidence: confidence
            )
        }.sorted { $0.estimatedMax > $1.estimatedMax }
    }

    private func suggestExercise(for muscleGroup: MuscleGroup) -> Exercise {
        let suggestions: [MuscleGroup: Exercise] = [
            .chest: Exercise(id: "suggest-chest", name: "Incline Dumbbell Press", muscleGroups: [.chest, .shoulders], equipment: .dumbbell, category: .compound, description: "Incline press targeting upper chest.", tips: ["30-45 degree angle", "Full range of motion"]),
            .back: Exercise(id: "suggest-back", name: "Barbell Row", muscleGroups: [.back, .biceps], equipment: .barbell, category: .compound, description: "Bent over barbell row for back thickness.", tips: ["Hinge at hips", "Pull to lower chest"]),
            .shoulders: Exercise(id: "suggest-shoulders", name: "Lateral Raise", muscleGroups: [.shoulders], equipment: .dumbbell, category: .isolation, description: "Side lateral raises for medial delts.", tips: ["Slight bend in elbows", "Control the descent"]),
            .quads: Exercise(id: "suggest-quads", name: "Leg Press", muscleGroups: [.quads, .glutes], equipment: .machine, category: .compound, description: "Machine leg press for quad strength.", tips: ["Full range of motion", "Drive through heels"]),
            .hamstrings: Exercise(id: "suggest-hamstrings", name: "Romanian Deadlift", muscleGroups: [.hamstrings, .glutes], equipment: .barbell, category: .compound, description: "RDL for hamstring development.", tips: ["Slight knee bend", "Feel the stretch"]),
            .glutes: Exercise(id: "suggest-glutes", name: "Hip Thrust", muscleGroups: [.glutes, .hamstrings], equipment: .barbell, category: .compound, description: "Barbell hip thrust for glute activation.", tips: ["Drive through heels", "Squeeze at top"]),
            .biceps: Exercise(id: "suggest-biceps", name: "Barbell Curl", muscleGroups: [.biceps], equipment: .barbell, category: .isolation, description: "Standard barbell curl.", tips: ["Keep elbows stationary", "Control the negative"]),
            .triceps: Exercise(id: "suggest-triceps", name: "Tricep Pushdown", muscleGroups: [.triceps], equipment: .cable, category: .isolation, description: "Cable tricep pushdown.", tips: ["Keep elbows tight", "Full extension"]),
            .abs: Exercise(id: "suggest-abs", name: "Cable Crunch", muscleGroups: [.abs], equipment: .cable, category: .isolation, description: "Weighted cable crunch for abs.", tips: ["Curl spine", "Don't pull with arms"]),
            .calves: Exercise(id: "suggest-calves", name: "Standing Calf Raise", muscleGroups: [.calves], equipment: .machine, category: .isolation, description: "Standing calf raises.", tips: ["Full stretch at bottom", "Pause at top"]),
            .forearms: Exercise(id: "suggest-forearms", name: "Wrist Curl", muscleGroups: [.forearms], equipment: .dumbbell, category: .isolation, description: "Seated wrist curls.", tips: ["Controlled movement"]),
            .traps: Exercise(id: "suggest-traps", name: "Barbell Shrug", muscleGroups: [.traps], equipment: .barbell, category: .isolation, description: "Heavy barbell shrugs.", tips: ["Squeeze at top", "No rolling"]),
            .lats: Exercise(id: "suggest-lats", name: "Lat Pulldown", muscleGroups: [.lats, .biceps], equipment: .cable, category: .compound, description: "Wide grip lat pulldown.", tips: ["Pull to upper chest", "Squeeze lats"])
        ]
        return suggestions[muscleGroup] ?? Exercise(id: "suggest-general", name: "Dumbbell Press", muscleGroups: [muscleGroup], equipment: .dumbbell, category: .compound, description: "General pressing movement.", tips: ["Control the weight"])
    }
}
