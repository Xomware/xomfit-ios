import XCTest
@testable import XomFit

final class AICoachTests: XCTestCase {
    var service: AICoachService!

    override func setUp() {
        super.setUp()
        service = AICoachService.shared
    }

    // MARK: - Readiness Score Tests

    func testReadinessCalculationWithNoWorkouts() {
        let readiness = service.calculateReadiness(from: [])
        XCTAssertGreaterThanOrEqual(readiness.score, 0)
        XCTAssertLessThanOrEqual(readiness.score, 100)
        XCTAssertNotNil(readiness.fatigueLevel)
        XCTAssertFalse(readiness.recommendation.isEmpty)
    }

    func testReadinessScoreInRange() {
        let readiness = service.calculateReadiness(from: [])
        XCTAssertGreaterThanOrEqual(readiness.score, 0)
        XCTAssertLessThanOrEqual(readiness.score, 100)
    }

    func testReadinessWithRecentWorkouts() {
        let workouts = createMockWorkouts(count: 5, daysAgo: 3)
        let readiness = service.calculateReadiness(from: workouts)
        XCTAssertGreaterThan(readiness.score, 0)
        XCTAssertNotNil(readiness.components)
    }

    func testReadinessFreshWhenHighScore() {
        // Create workouts with good consistency
        let workouts = createMockWorkouts(count: 4, daysAgo: 1) + createMockWorkouts(count: 4, daysAgo: 8)
        let readiness = service.calculateReadiness(from: workouts)
        XCTAssertTrue([FatigueLevel.fresh, .moderate].contains(readiness.fatigueLevel))
    }

    // MARK: - Periodization Tests

    func testPeriodizationPlanHasSixWeeks() {
        let plan = service.generatePeriodizationPlan()
        XCTAssertEqual(plan.count, 6)
    }

    func testPeriodizationPhaseOrder() {
        let plan = service.generatePeriodizationPlan()
        XCTAssertTrue(plan.contains { $0.phase == .accumulation })
        XCTAssertTrue(plan.contains { $0.phase == .intensification })
        XCTAssertTrue(plan.contains { $0.phase == .realization })
        XCTAssertTrue(plan.contains { $0.phase == .deload })
    }

    func testPeriodizationBlockFields() {
        let plan = service.generatePeriodizationPlan()
        for block in plan {
            XCTAssertGreaterThan(block.targetVolume, 0)
            XCTAssertGreaterThan(block.targetIntensity, 0)
            XCTAssertLessThanOrEqual(block.targetIntensity, 1.0)
            XCTAssertFalse(block.notes.isEmpty)
        }
    }

    func testDeloadBlockHasLowestVolume() {
        let plan = service.generatePeriodizationPlan()
        let deloadBlock = plan.first { $0.phase == .deload }!
        let otherBlocks = plan.filter { $0.phase != .deload }
        for block in otherBlocks {
            XCTAssertGreaterThan(block.targetVolume, deloadBlock.targetVolume)
        }
    }

    // MARK: - Training Load Tests

    func testTrainingLoadCalculation() {
        let load = service.calculateTrainingLoad(from: [])
        XCTAssertGreaterThanOrEqual(load.acute, 0)
        XCTAssertGreaterThan(load.chronic, 0) // chronic defaults to max(x, 1)
        XCTAssertFalse(load.riskLevel.isEmpty)
    }

    func testACWRRiskLevels() {
        let optimalLoad = TrainingLoad(acute: 20, chronic: 18)
        XCTAssertEqual(optimalLoad.riskLevel, "Optimal")

        let highRiskLoad = TrainingLoad(acute: 30, chronic: 15)
        XCTAssertEqual(highRiskLoad.riskLevel, "High Risk")

        let cautionLoad = TrainingLoad(acute: 26, chronic: 20)
        XCTAssertEqual(cautionLoad.riskLevel, "Caution")

        let undertrainingLoad = TrainingLoad(acute: 5, chronic: 20)
        XCTAssertEqual(undertrainingLoad.riskLevel, "Undertraining")
    }

    func testTrainingLoadWithWorkouts() {
        let workouts = createMockWorkouts(count: 3, daysAgo: 2)
        let load = service.calculateTrainingLoad(from: workouts)
        XCTAssertGreaterThan(load.acute, 0)
    }

    // MARK: - Muscle Group Volume Tests

    func testMuscleGroupVolumesReturnsSixGroups() {
        let volumes = service.calculateMuscleGroupVolumes(from: [])
        XCTAssertEqual(volumes.count, 6)
    }

    func testMuscleGroupVolumeTargets() {
        let volumes = service.calculateMuscleGroupVolumes(from: [])
        for vol in volumes {
            XCTAssertGreaterThan(vol.weeklySetTarget, 0)
            XCTAssertFalse(vol.muscleGroup.isEmpty)
        }
    }

    func testMuscleGroupVolumePercentCalculation() {
        let vol = MuscleGroupVolume(muscleGroup: "Test", weeklySetTarget: 10, currentWeeklySets: 5)
        XCTAssertEqual(vol.percentOfTarget, 0.5, accuracy: 0.01)
    }

    func testMuscleGroupVolumeZeroTarget() {
        let vol = MuscleGroupVolume(muscleGroup: "Test", weeklySetTarget: 0, currentWeeklySets: 5)
        // Should not crash, uses max(target, 1) in percentOfTarget
        XCTAssertGreaterThan(vol.percentOfTarget, 0)
    }

    // MARK: - Insights Tests

    func testInsightsAreGenerated() {
        let insights = service.generateInsights(from: [])
        XCTAssertNotNil(insights)
    }

    func testNoWorkoutsInsight() {
        let insights = service.generateInsights(from: [])
        let recoveryInsight = insights.first { $0.type == .recoveryAlert }
        XCTAssertNotNil(recoveryInsight, "Should suggest recovery when no recent workouts")
    }

    func testCoachInsightHasRequiredFields() {
        let insight = CoachInsight(
            type: .progressiveOverload,
            title: "Test",
            message: "Test message",
            confidence: 0.8
        )
        XCTAssertFalse(insight.title.isEmpty)
        XCTAssertFalse(insight.message.isEmpty)
        XCTAssertGreaterThanOrEqual(insight.confidence, 0)
        XCTAssertLessThanOrEqual(insight.confidence, 1.0)
    }

    func testInsightPrioritySorting() {
        let insights = service.generateInsights(from: [])
        guard insights.count > 1 else { return }
        for idx in 0..<(insights.count - 1) {
            XCTAssertLessThanOrEqual(insights[idx].priority, insights[idx + 1].priority)
        }
    }

    // MARK: - Fatigue Level Tests

    func testFatigueLevelColors() {
        XCTAssertEqual(FatigueLevel.fresh.color, "green")
        XCTAssertEqual(FatigueLevel.moderate.color, "yellow")
        XCTAssertEqual(FatigueLevel.fatigued.color, "orange")
        XCTAssertEqual(FatigueLevel.overreached.color, "red")
    }

    func testFatigueLevelCases() {
        XCTAssertEqual(FatigueLevel.allCases.count, 4)
    }

    // MARK: - Recommendation Generation Tests

    func testNoRecommendationsWithNoWorkouts() {
        let recs = service.generateRecommendations(userId: "user-1", workouts: [])
        XCTAssertTrue(recs.isEmpty)
    }

    func testRecommendationsGenerated() {
        let workouts = createMockWorkouts(count: 10, daysAgo: 5)
        let recs = service.generateRecommendations(userId: "user-1", workouts: workouts)
        XCTAssertTrue(recs.count <= 5, "Should limit to max 5 recommendations")
    }

    func testRecommendationsSortedByConfidence() {
        let workouts = createMockWorkouts(count: 10, daysAgo: 5)
        let recs = service.generateRecommendations(userId: "user-1", workouts: workouts)
        guard recs.count > 1 else { return }
        for idx in 0..<(recs.count - 1) {
            XCTAssertGreaterThanOrEqual(recs[idx].confidence, recs[idx + 1].confidence)
        }
    }

    func testRecommendationWithUserStats() {
        let workouts = createMockWorkouts(count: 10, daysAgo: 5)
        let stats = User.UserStats(
            totalWorkouts: 50,
            totalVolume: 500000,
            totalPRs: 15,
            currentStreak: 5,
            longestStreak: 20,
            favoriteExercise: "Bench Press"
        )
        let recs = service.generateRecommendations(userId: "user-1", workouts: workouts, userStats: stats)
        let programRec = recs.first { $0.type == .newProgram }
        XCTAssertNotNil(programRec, "Should generate program recommendation with enough workout history")
    }

    func testRecommendationConfidenceRange() {
        let workouts = createMockWorkouts(count: 10, daysAgo: 5)
        let recs = service.generateRecommendations(userId: "user-1", workouts: workouts)
        for rec in recs {
            XCTAssertGreaterThanOrEqual(rec.confidence, 0)
            XCTAssertLessThanOrEqual(rec.confidence, 1.0)
        }
    }

    // MARK: - Performance Analysis Tests

    func testPerformanceAnalysis() {
        let workouts = createMockWorkouts(count: 5, daysAgo: 5)
        let analysis = service.analyzePerformance(userId: "user-1", workouts: workouts)
        XCTAssertFalse(analysis.muscleGroupsAnalysis.isEmpty)
        XCTAssertNotNil(analysis.volumeProgression)
        XCTAssertNotNil(analysis.strengthProgression)
    }

    func testPerformanceAnalysisEmptyWorkouts() {
        let analysis = service.analyzePerformance(userId: "user-1", workouts: [])
        XCTAssertNotNil(analysis)
        XCTAssertEqual(analysis.muscleGroupsAnalysis.count, MuscleGroup.allCases.count)
    }

    func testPerformanceAnalysisOverallScore() {
        let workouts = createMockWorkouts(count: 5, daysAgo: 5)
        let analysis = service.analyzePerformance(userId: "user-1", workouts: workouts)
        XCTAssertGreaterThanOrEqual(analysis.overallScore, 0)
        XCTAssertLessThanOrEqual(analysis.overallScore, 1.0)
    }

    func testPerformanceAnalysisMuscleGroupStatuses() {
        let workouts = createMockWorkouts(count: 5, daysAgo: 5)
        let analysis = service.analyzePerformance(userId: "user-1", workouts: workouts)
        for group in analysis.muscleGroupsAnalysis {
            XCTAssertNotNil(group.frequency)
            XCTAssertNotNil(group.status)
            XCTAssertGreaterThanOrEqual(group.relativeVolume, 0)
        }
    }

    func testWeakMuscleGroupsDetection() {
        let analysis = service.analyzePerformance(userId: "user-1", workouts: [])
        // With no workouts, all muscle groups should be weak
        XCTAssertEqual(analysis.weakMuscleGroups.count, MuscleGroup.allCases.count)
    }

    // MARK: - Feedback Tests

    func testRecordFeedback() {
        // Should not crash
        service.recordFeedback(recommendationId: "test-id", accepted: true)
        service.recordFeedback(recommendationId: "test-id-2", accepted: false)
    }

    // MARK: - Model Tests

    func testAIRecommendationDisplayTitle() {
        let rec = AIRecommendation.mockExerciseRecommendation
        XCTAssertFalse(rec.displayTitle.isEmpty)
    }

    func testAIRecommendationDisplayIcon() {
        let rec = AIRecommendation.mockWeakPointRecommendation
        XCTAssertFalse(rec.displayIcon.isEmpty)
    }

    func testAIRecommendationConfidencePercentage() {
        let rec = AIRecommendation.mockExerciseRecommendation
        XCTAssertEqual(rec.confidencePercentage, Int(rec.confidence * 100))
    }

    func testAIRecommendationHashable() {
        let rec1 = AIRecommendation.mockExerciseRecommendation
        let rec2 = AIRecommendation.mockWeakPointRecommendation
        XCTAssertNotEqual(rec1, rec2)
    }

    func testRecommendationTypeDisplayIcons() {
        let types: [RecommendationType] = [.exercise, .repRange, .restPeriod, .weakPoint, .plateau, .volumeProgression, .exerciseSwap, .newProgram, .formCorrection]
        for type in types {
            let rec = AIRecommendation(userId: "test", type: type, confidence: 0.5, reasoning: "test")
            XCTAssertFalse(rec.displayIcon.isEmpty)
            XCTAssertFalse(rec.displayTitle.isEmpty)
        }
    }

    func testProgramRecommendationMock() {
        let rec = AIRecommendation.mockProgramRecommendation
        XCTAssertNotNil(rec.program)
        XCTAssertEqual(rec.type, .newProgram)
        XCTAssertGreaterThan(rec.program!.estimatedDurationWeeks, 0)
    }

    func testExerciseFrequencyDisplayNames() {
        XCTAssertEqual(ExerciseFrequency.rare.displayName, "Rarely")
        XCTAssertEqual(ExerciseFrequency.occasional.displayName, "Occasionally")
        XCTAssertEqual(ExerciseFrequency.regular.displayName, "Regularly")
        XCTAssertEqual(ExerciseFrequency.frequent.displayName, "Frequently")
    }

    func testTrainingStatusDisplayNames() {
        XCTAssertEqual(TrainingStatus.weak.displayName, "Needs Work")
        XCTAssertEqual(TrainingStatus.balanced.displayName, "Balanced")
        XCTAssertEqual(TrainingStatus.overworked.displayName, "Overworked")
        XCTAssertEqual(TrainingStatus.plateaued.displayName, "Plateaued")
    }

    func testTrainingStatusIcons() {
        XCTAssertFalse(TrainingStatus.weak.icon.isEmpty)
        XCTAssertFalse(TrainingStatus.balanced.icon.isEmpty)
    }

    func testRecommendationLearning() {
        var learning = RecommendationLearning()
        learning.recordFeedback(recommendationId: "rec-1", accepted: true)
        learning.recordFeedback(recommendationId: "rec-2", accepted: false)
        XCTAssertEqual(learning.acceptedRecommendations.count, 1)
        XCTAssertEqual(learning.rejectedRecommendations.count, 1)
    }

    func testUserTrainingPreferencesDefaults() {
        let prefs = UserTrainingPreferences()
        XCTAssertEqual(prefs.targetDaysPerWeek, 4)
        XCTAssertTrue(prefs.enableAutoDeload)
        XCTAssertEqual(prefs.deloadFrequencyWeeks, 8)
    }

    func testUserTrainingPreferencesSliderBindings() {
        var prefs = UserTrainingPreferences()
        prefs.minRepsDouble = 6.0
        XCTAssertEqual(prefs.repRangePreference.min, 6)
        prefs.maxRepsDouble = 15.0
        XCTAssertEqual(prefs.repRangePreference.max, 15)
    }

    func testSplitTypeDisplayNames() {
        XCTAssertEqual(ProgramRecommendation.SplitType.upperLower.displayName, "Upper/Lower")
        XCTAssertEqual(ProgramRecommendation.SplitType.pushPullLegs.displayName, "Push/Pull/Legs")
        XCTAssertEqual(ProgramRecommendation.SplitType.fullBody.displayName, "Full Body")
    }

    func testPeriodizationPhaseCases() {
        XCTAssertEqual(PeriodizationPhase.allCases.count, 4)
    }

    // MARK: - Exercise Estimation Tests

    func testExerciseEstimateMax() {
        let max = Exercise.estimateMax(weight: 225, reps: 5)
        XCTAssertGreaterThan(max, 225)
    }

    func testExerciseEstimateMaxSingleRep() {
        let max = Exercise.estimateMax(weight: 315, reps: 1)
        XCTAssertEqual(max, 315)
    }

    func testExerciseEstimateMaxZeroReps() {
        let max = Exercise.estimateMax(weight: 100, reps: 0)
        XCTAssertEqual(max, 100)
    }

    // MARK: - Imbalance Detection Tests

    func testImbalanceDetection() {
        // Create workouts that only train chest (no back)
        let chestWorkouts = createChestOnlyWorkouts(count: 10)
        let analysis = service.analyzePerformance(userId: "user-1", workouts: chestWorkouts)
        // Should detect some imbalances or weak points
        let totalFindings = analysis.imbalances.count + analysis.weakMuscleGroups.count
        XCTAssertGreaterThan(totalFindings, 0)
    }

    func testImbalanceSeverityLevels() {
        let minor = PerformanceAnalysis.Imbalance(
            muscleGroup1: .chest, muscleGroup2: .back,
            volumeRatio: 1.6, severity: .minor, recommendation: "test"
        )
        XCTAssertEqual(minor.severity, .minor)

        let severe = PerformanceAnalysis.Imbalance(
            muscleGroup1: .chest, muscleGroup2: .back,
            volumeRatio: 3.5, severity: .severe, recommendation: "test"
        )
        XCTAssertEqual(severe.severity, .severe)
    }

    // MARK: - Estimated Maxes Tests

    func testEstimatedMaxesFromWorkouts() {
        let workouts = createMockWorkouts(count: 5, daysAgo: 5)
        let analysis = service.analyzePerformance(userId: "user-1", workouts: workouts)
        // Should have at least one estimated max from bench press in mock data
        XCTAssertGreaterThan(analysis.estimatedMaxes.count, 0)
    }

    func testEstimatedMaxConfidence() {
        let workouts = createMockWorkouts(count: 5, daysAgo: 5)
        let analysis = service.analyzePerformance(userId: "user-1", workouts: workouts)
        for estMax in analysis.estimatedMaxes {
            XCTAssertGreaterThanOrEqual(estMax.confidence, 0)
            XCTAssertLessThanOrEqual(estMax.confidence, 1.0)
        }
    }

    // MARK: - Identifiable Conformance Tests

    func testMuscleGroupAnalysisIdentifiable() {
        let analysis = PerformanceAnalysis.MuscleGroupAnalysis(
            muscleGroup: .chest, lastWorked: nil,
            frequency: .regular, relativeVolume: 0.5, status: .balanced
        )
        XCTAssertEqual(analysis.id, "chest")
    }

    func testImbalanceIdentifiable() {
        let imbalance = PerformanceAnalysis.Imbalance(
            muscleGroup1: .chest, muscleGroup2: .back,
            volumeRatio: 2.0, severity: .moderate, recommendation: "test"
        )
        XCTAssertEqual(imbalance.id, "chest-back")
    }

    func testExerciseMaxIdentifiable() {
        let estMax = PerformanceAnalysis.ExerciseMax(
            exerciseId: "ex-1", exerciseName: "Bench", estimatedMax: 300,
            basedOnSets: 5, confidence: 0.8
        )
        XCTAssertEqual(estMax.id, "ex-1")
    }

    // MARK: - Volume Trend Tests

    func testVolumeTrendDetection() {
        let analysis = service.analyzePerformance(userId: "user-1", workouts: [])
        XCTAssertNotNil(analysis.volumeProgression.trend)
        XCTAssertFalse(analysis.volumeProgression.recommendation.isEmpty)
    }

    // MARK: - Coach Insight Type Tests

    func testCoachInsightTypeRawValues() {
        XCTAssertEqual(CoachInsightType.deloadSuggestion.rawValue, "Deload Suggestion")
        XCTAssertEqual(CoachInsightType.prOpportunity.rawValue, "PR Opportunity")
    }

    // MARK: - Helpers

    private func createMockWorkouts(count: Int, daysAgo: Int) -> [Workout] {
        (0..<count).map { idx in
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo + idx, to: Date())!
            return Workout(
                id: "w-\(idx)",
                userId: "user-1",
                name: "Push Day \(idx)",
                exercises: [
                    WorkoutExercise(
                        id: "we-\(idx)",
                        exercise: .benchPress,
                        sets: [
                            WorkoutSet(id: "s-\(idx)-1", exerciseId: "ex-1", weight: 225, reps: 5, rpe: 8, isPersonalRecord: idx == 0, completedAt: date),
                            WorkoutSet(id: "s-\(idx)-2", exerciseId: "ex-1", weight: 225, reps: 5, rpe: 8.5, isPersonalRecord: false, completedAt: date),
                            WorkoutSet(id: "s-\(idx)-3", exerciseId: "ex-1", weight: 235, reps: 3, rpe: 9, isPersonalRecord: false, completedAt: date)
                        ],
                        notes: nil
                    )
                ],
                startTime: date,
                endTime: date.addingTimeInterval(3600),
                notes: nil
            )
        }
    }

    private func createChestOnlyWorkouts(count: Int) -> [Workout] {
        (0..<count).map { idx in
            let date = Calendar.current.date(byAdding: .day, value: -idx, to: Date())!
            return Workout(
                id: "chest-w-\(idx)",
                userId: "user-1",
                name: "Chest Day \(idx)",
                exercises: [
                    WorkoutExercise(
                        id: "chest-we-\(idx)",
                        exercise: Exercise(
                            id: "ex-bench",
                            name: "Bench Press",
                            muscleGroups: [.chest, .triceps, .shoulders],
                            equipment: .barbell,
                            category: .compound,
                            description: "Bench press",
                            tips: []
                        ),
                        sets: [
                            WorkoutSet(id: "cs-\(idx)-1", exerciseId: "ex-bench", weight: 200, reps: 8, rpe: 7, isPersonalRecord: false, completedAt: date),
                            WorkoutSet(id: "cs-\(idx)-2", exerciseId: "ex-bench", weight: 200, reps: 8, rpe: 8, isPersonalRecord: false, completedAt: date)
                        ],
                        notes: nil
                    )
                ],
                startTime: date,
                endTime: date.addingTimeInterval(2400),
                notes: nil
            )
        }
    }
}
