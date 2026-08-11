import XCTest
@testable import Xomfit

final class StrengthStandardsTests: XCTestCase {

    private let service = StrengthLevelService.shared

    // MARK: - Coverage

    /// The whole point of mapping every exercise to an anchor is that no lift
    /// silently falls through without a rank. This fails when an exercise is
    /// added to the database without a decision being made in StrengthStandards.
    func testEveryExerciseIsMapped() {
        let unmapped = ExerciseDatabase.all
            .filter { StrengthStandards.profile(for: $0.id) == nil }
            .map(\.id)

        XCTAssertTrue(
            unmapped.isEmpty,
            "\(unmapped.count) exercise(s) have no strength profile: \(unmapped.sorted().joined(separator: ", "))"
        )
    }

    func testNoProfileReferencesAnUnknownExercise() {
        let knownIds = Set(ExerciseDatabase.all.map(\.id))
        let stale = StrengthStandards.profiles.keys.filter { !knownIds.contains($0) }
        XCTAssertTrue(
            stale.isEmpty,
            "Strength profiles reference exercises that no longer exist: \(stale.sorted().joined(separator: ", "))"
        )
    }

    func testAllCoefficientsArePositive() {
        for (id, profile) in StrengthStandards.profiles {
            XCTAssertGreaterThan(profile.coefficient, 0, "\(id) has a non-positive coefficient")
        }
    }

    // MARK: - Threshold shape

    func testThresholdsAreStrictlyIncreasingForEveryPattern() {
        for pattern in MovementPattern.allCases {
            for sex in LifterSex.allCases {
                let ratios = pattern.ratios(for: sex)
                XCTAssertEqual(ratios.count, StrengthTier.ranked.count,
                               "\(pattern) has the wrong number of thresholds")
                for i in 1..<ratios.count {
                    XCTAssertGreaterThan(
                        ratios[i], ratios[i - 1],
                        "\(pattern)/\(sex) thresholds must increase: \(ratios)"
                    )
                }
            }
        }
    }

    func testFemaleStandardsAreLowerButNotTrivial() {
        for pattern in MovementPattern.allCases {
            let male = pattern.ratios(for: .male)
            let female = pattern.ratios(for: .female)
            for i in male.indices {
                XCTAssertLessThan(female[i], male[i], "\(pattern)")
                XCTAssertGreaterThan(female[i], male[i] * 0.5, "\(pattern) female standard is implausibly low")
            }
        }
    }

    func testUnspecifiedSexSitsBetweenMaleAndFemale() {
        let male = MovementPattern.squat.ratios(for: .male)
        let female = MovementPattern.squat.ratios(for: .female)
        let unspecified = MovementPattern.squat.ratios(for: .unspecified)
        for i in male.indices {
            XCTAssertGreaterThan(unspecified[i], female[i])
            XCTAssertLessThan(unspecified[i], male[i])
        }
    }

    // MARK: - Ranking

    /// A 200 lb male with a 225 bench is at 1.125x bodyweight — past Silver
    /// (0.75x) and closing on Gold (1.25x). Landing mid-ladder rather than at
    /// either extreme is the sanity check that the ratios are believable.
    func testTypicalIntermediateBenchRanksSilverApproachingGold() {
        let rank = service.rank(
            exerciseId: "ex-bench-flat", estimated1RM: 225,
            bodyweight: 200, sex: .male, age: 30
        )
        XCTAssertEqual(rank?.tier, .silver)
        XCTAssertEqual(rank?.nextTier, .gold)
        XCTAssertEqual(rank?.nextTierTarget ?? 0, 250, accuracy: 0.01)
    }

    func testUntrainedLifterIsUnrankedRatherThanBronze() {
        let rank = service.rank(
            exerciseId: "ex-bench-flat", estimated1RM: 65,
            bodyweight: 200, sex: .male, age: 30
        )
        XCTAssertEqual(rank?.tier, .unranked)
        XCTAssertEqual(rank?.nextTier, .bronze)
    }

    func testWorldClassLiftReachesGod() {
        let rank = service.rank(
            exerciseId: "ex-deadlift", estimated1RM: 900,
            bodyweight: 200, sex: .male, age: 28
        )
        XCTAssertEqual(rank?.tier, .god)
        XCTAssertNil(rank?.nextTier, "God is the top of the ladder")
        XCTAssertNil(rank?.nextTierTarget)
    }

    func testHeavierLifterNeedsMoreWeightForTheSameRank() {
        let light = service.rank(exerciseId: "ex-squat", estimated1RM: 315,
                                 bodyweight: 150, sex: .male, age: 30)
        let heavy = service.rank(exerciseId: "ex-squat", estimated1RM: 315,
                                 bodyweight: 250, sex: .male, age: 30)
        XCTAssertGreaterThan(light!.tier, heavy!.tier,
                             "Bodyweight-relative standards must favor the lighter lifter")
    }

    // MARK: - Load basis

    /// A strict bodyweight pull-up is not a zero-load lift. Ranking it as one
    /// would leave every unweighted calisthenics athlete permanently unranked.
    func testBodyweightMovementCountsBodyweightAsLoad() {
        let rank = service.rank(
            exerciseId: "ex-pullup", estimated1RM: 0,
            bodyweight: 180, sex: .male, age: 30
        )
        XCTAssertNotNil(rank)
        XCTAssertGreaterThan(rank!.tier, .unranked,
                             "A strict bodyweight pull-up should earn a rank")
    }

    /// For a bodyweight movement the prompt has to be the *added* weight, since
    /// that is what the lifter actually loads onto the belt.
    func testBodyweightNextTargetIsReportedAsAddedWeight() {
        let rank = service.rank(
            exerciseId: "ex-pullup", estimated1RM: 0,
            bodyweight: 180, sex: .male, age: 30
        )
        if let target = rank?.nextTierTarget {
            XCTAssertLessThan(target, 180, "Target must be added weight, not total load")
        }
    }

    func testHoldsAndMobilityAreNotRanked() {
        for id in ["ex-plank", "ex-side-plank", "ex-cat-cow", "ex-90-90-mobility"] {
            XCTAssertNil(
                service.rank(exerciseId: id, estimated1RM: 100,
                             bodyweight: 180, sex: .male, age: 30),
                "\(id) should not be weight-ranked"
            )
        }
    }

    func testUnknownBodyweightCannotRank() {
        XCTAssertNil(service.rank(
            exerciseId: "ex-bench-flat", estimated1RM: 225,
            bodyweight: 0, sex: .male, age: 30
        ))
    }

    // MARK: - Age

    func testAgeAllowanceMakesRanksReachableForMastersLifters() {
        let young = service.rank(exerciseId: "ex-bench-flat", estimated1RM: 250,
                                 bodyweight: 200, sex: .male, age: 28)
        let older = service.rank(exerciseId: "ex-bench-flat", estimated1RM: 250,
                                 bodyweight: 200, sex: .male, age: 60)
        XCTAssertGreaterThanOrEqual(older!.tier, young!.tier,
                                    "The same lift should never rank lower with age")
    }

    func testPrimeAgeGetsNoAllowance() {
        XCTAssertEqual(StrengthLevelService.ageFactor(for: 28), 1.0)
        XCTAssertEqual(StrengthLevelService.ageFactor(for: nil), 1.0)
    }

    func testAgeFactorDecreasesMonotonically() {
        let ages = [24, 35, 42, 47, 52, 57, 62, 67, 75]
        let factors = ages.map { StrengthLevelService.ageFactor(for: $0) }
        for i in 1..<factors.count {
            XCTAssertLessThan(factors[i], factors[i - 1], "age \(ages[i])")
        }
    }

    // MARK: - Progress

    func testProgressIsBoundedAndResetsAfterRankingUp() {
        // Just past the bronze threshold — progress toward silver should be low.
        let thresholds = StrengthStandards.thresholds(
            exerciseId: "ex-squat", bodyweight: 200, sex: .male
        )!
        let justPastBronze = thresholds[0] + 1
        let rank = service.rank(exerciseId: "ex-squat", estimated1RM: justPastBronze,
                                bodyweight: 200, sex: .male, age: 30)
        XCTAssertEqual(rank?.tier, .bronze)
        let progress = rank?.progressToNext ?? 1
        XCTAssertGreaterThanOrEqual(progress, 0)
        XCTAssertLessThan(progress, 0.1, "Progress should restart after ranking up")
    }

    func testNextTierPromptDescribesRemainingWeight() {
        let rank = service.rank(exerciseId: "ex-bench-flat", estimated1RM: 225,
                                bodyweight: 200, sex: .male, age: 30)
        let prompt = rank?.nextTierPrompt
        XCTAssertNotNil(prompt)
        // 250 lb Gold threshold minus the current 225 e1RM.
        XCTAssertEqual(prompt, "25 lb from Gold")
    }

    // MARK: - Distribution

    // Reads the service's stored lifter attributes, so it has to run on the
    // main actor unlike the pure ranking tests above.
    @MainActor
    func testTierDistributionCountsBestRankPerExercise() {
        StrengthLevelService.shared.setManualBodyweight(200)
        StrengthLevelService.shared.sex = .male

        let records = [
            PersonalRecord(id: "1", userId: "u", exerciseId: "ex-bench-flat",
                           exerciseName: "Bench Press", weight: 225, reps: 1,
                           date: Date(), previousBest: nil,
                           kind: .e1rm, estimated1RM: 225),
            PersonalRecord(id: "2", userId: "u", exerciseId: "ex-squat",
                           exerciseName: "Squat", weight: 315, reps: 1,
                           date: Date(), previousBest: nil,
                           kind: .e1rm, estimated1RM: 315)
        ]
        let distribution = service.tierDistribution(from: records)
        XCTAssertEqual(distribution.values.reduce(0, +), 2)
    }
}
