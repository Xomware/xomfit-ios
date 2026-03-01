import Foundation

class AICoachService: ObservableObject {
    static let shared = AICoachService()
    
    private let workoutStore = WorkoutStore.shared
    
    // MARK: - Readiness Score
    func calculateReadiness() -> ReadinessScore {
        let workouts = workoutStore.workouts
        let now = Date()
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        let fourteenDaysAgo = Calendar.current.date(byAdding: .day, value: -14, to: now)!
        
        let recentWorkouts = workouts.filter { $0.startDate >= sevenDaysAgo }
        let previousWorkouts = workouts.filter { $0.startDate >= fourteenDaysAgo && $0.startDate < sevenDaysAgo }
        
        // Volume component
        let recentSets = recentWorkouts.reduce(0) { $0 + $1.sets.count }
        let volumeScore = min(Int(Double(recentSets) / 20.0 * 100), 100)
        
        // Consistency component
        let workoutDays = Set(recentWorkouts.map { Calendar.current.startOfDay(for: $0.startDate) }).count
        let consistencyScore = min(workoutDays * 20, 100)
        
        // Recovery days (days since last workout)
        let lastWorkout = workouts.sorted { $0.startDate > $1.startDate }.first
        let daysSinceLastWorkout = lastWorkout.map { Int(now.timeIntervalSince($0.startDate) / 86400) } ?? 7
        let recoveryScore = min(daysSinceLastWorkout * 25, 100)
        
        // PR Momentum
        let previousSets = previousWorkouts.reduce(0) { $0 + $1.sets.count }
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
    
    // MARK: - Generate Insights
    func generateInsights() -> [CoachInsight] {
        var insights: [CoachInsight] = []
        let workouts = workoutStore.workouts
        let now = Date()
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        let recentWorkouts = workouts.filter { $0.startDate >= sevenDaysAgo }
        
        // Check for deload
        let totalRecentSets = recentWorkouts.reduce(0) { $0 + $1.sets.count }
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
        
        // Progressive overload opportunities
        if let lastWorkout = workouts.sorted(by: { $0.startDate > $1.startDate }).first {
            let heaviestSet = lastWorkout.sets.sorted(by: { ($0.weight ?? 0) > ($1.weight ?? 0) }).first
            if let set = heaviestSet, let weight = set.weight {
                insights.append(CoachInsight(
                    type: .progressiveOverload,
                    title: "Progressive Overload Opportunity",
                    message: "You've hit \(Int(weight))lbs on \(set.exerciseName ?? "your last exercise") 2+ times. Try adding 5lbs next session.",
                    confidence: 0.78,
                    actionLabel: "Got It",
                    priority: 2
                ))
            }
        }
        
        // Volume recommendations per muscle group
        let muscleVolumes = calculateMuscleGroupVolumes()
        for vol in muscleVolumes where vol.percentOfTarget < 0.5 {
            insights.append(CoachInsight(
                type: .volumeRecommendation,
                title: "\(vol.muscleGroup) Volume Low",
                message: "You're at \(vol.currentWeeklySets)/\(vol.weeklySetTarget) sets for \(vol.muscleGroup) this week. Add a session to hit minimum effective volume.",
                confidence: 0.9,
                priority: 2
            ))
        }
        
        // Workout frequency check
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
        
        // PR opportunity
        let readiness = calculateReadiness()
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
    
    // MARK: - Periodization
    func generatePeriodizationPlan(currentPhase: PeriodizationPhase = .accumulation) -> [PeriodizationBlock] {
        let blocks: [PeriodizationBlock] = [
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
        return blocks
    }
    
    // MARK: - Training Load
    func calculateTrainingLoad() -> TrainingLoad {
        let workouts = workoutStore.workouts
        let now = Date()
        
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        let twentyEightDaysAgo = Calendar.current.date(byAdding: .day, value: -28, to: now)!
        
        let acute = Double(workouts.filter { $0.startDate >= sevenDaysAgo }.reduce(0) { $0 + $1.sets.count })
        let chronic = Double(workouts.filter { $0.startDate >= twentyEightDaysAgo }.reduce(0) { $0 + $1.sets.count }) / 4.0
        
        return TrainingLoad(acute: acute, chronic: max(chronic, 1))
    }
    
    // MARK: - Muscle Group Volumes
    func calculateMuscleGroupVolumes() -> [MuscleGroupVolume] {
        let workouts = workoutStore.workouts
        let now = Date()
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        let recentSets = workouts.filter { $0.startDate >= sevenDaysAgo }.flatMap { $0.sets }
        
        // Minimum effective volume targets (sets/week)
        let targets: [(String, Int, [String])] = [
            ("Chest", 10, ["Bench Press", "Push-up", "Fly", "Dip"]),
            ("Back", 12, ["Pull-up", "Row", "Lat Pulldown", "Deadlift"]),
            ("Legs", 12, ["Squat", "Leg Press", "Lunge", "Leg Curl"]),
            ("Shoulders", 8, ["Press", "Lateral Raise", "Front Raise"]),
            ("Arms", 8, ["Curl", "Tricep", "Hammer Curl"]),
            ("Core", 6, ["Plank", "Crunch", "Ab", "Core"])
        ]
        
        return targets.map { (muscle, target, keywords) in
            let count = recentSets.filter { set in
                guard let name = set.exerciseName else { return false }
                return keywords.contains(where: { name.localizedCaseInsensitiveContains($0) })
            }.count
            return MuscleGroupVolume(muscleGroup: muscle, weeklySetTarget: target, currentWeeklySets: count)
        }
    }
}
