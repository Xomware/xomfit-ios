import Foundation

// MARK: - Load basis

/// How the load for an exercise is measured, which decides what number gets
/// compared against the standards.
enum LoadBasis {
    /// External weight only — a barbell, a stack, a pair of dumbbells.
    case external
    /// Bodyweight moves too, so the total load is bodyweight plus any added
    /// weight. A 200 lb lifter doing a strict pull-up is moving 200 lb, and
    /// ranking that as "0 lb" would be nonsense.
    case bodyweightPlusAdded
    /// Load carries no useful information — planks, mobility work, carries
    /// scored by time or distance. These are deliberately not ranked; inventing
    /// a "Gold plank" would cheapen every real rank.
    case notRanked
}

// MARK: - Movement patterns

/// Anchor movements that carry their own bodyweight-ratio standards.
///
/// Publishing a separate threshold table for all 194 exercises would mean
/// fabricating most of them — reliable population data simply does not exist for
/// the single-arm cable preacher curl. Instead each exercise maps to the anchor
/// it most resembles plus a coefficient expressing how it compares, so every
/// threshold traces back to a movement with real data behind it.
enum MovementPattern: String, CaseIterable {
    case horizontalPress
    case verticalPress
    case squat
    case hinge
    case horizontalPull
    case verticalPull
    case hipThrust
    case legPress
    case legCurl
    case legExtension
    case calfRaise
    case elbowFlexion      // curls
    case elbowExtension    // pushdowns, skullcrushers
    case lateralRaise
    case shrug

    /// Estimated-1RM-to-bodyweight ratios for each rank, male reference.
    ///
    /// Drawn from the commonly published strength-standard tables (the
    /// Symmetric Strength / ExRx family) for the first four ranks, with
    /// Olympian and God extrapolated beyond "elite" so the ladder keeps going
    /// for people who reach the top of the published range.
    ///
    /// Index order matches `StrengthTier.ranked`:
    /// bronze, silver, gold, diamond, olympian, god.
    var maleRatios: [Double] {
        switch self {
        case .horizontalPress: return [0.50, 0.75, 1.25, 1.75, 2.10, 2.50]
        case .verticalPress:   return [0.35, 0.55, 0.80, 1.10, 1.35, 1.60]
        case .squat:           return [0.75, 1.25, 1.75, 2.50, 3.00, 3.50]
        case .hinge:           return [1.00, 1.50, 2.25, 3.00, 3.50, 4.00]
        case .horizontalPull:  return [0.50, 0.75, 1.15, 1.50, 1.80, 2.10]
        case .verticalPull:    return [0.45, 0.70, 1.00, 1.30, 1.55, 1.80]
        case .hipThrust:       return [1.00, 1.50, 2.25, 3.00, 3.75, 4.50]
        case .legPress:        return [1.25, 2.00, 3.00, 4.00, 5.00, 6.00]
        case .legCurl:         return [0.30, 0.45, 0.65, 0.85, 1.00, 1.20]
        case .legExtension:    return [0.40, 0.60, 0.85, 1.10, 1.35, 1.60]
        case .calfRaise:       return [0.50, 0.90, 1.40, 2.00, 2.50, 3.00]
        case .elbowFlexion:    return [0.25, 0.40, 0.60, 0.80, 0.95, 1.10]
        case .elbowExtension:  return [0.20, 0.35, 0.50, 0.70, 0.85, 1.00]
        case .lateralRaise:    return [0.08, 0.13, 0.20, 0.28, 0.35, 0.42]
        case .shrug:           return [0.75, 1.25, 1.90, 2.60, 3.20, 3.80]
        }
    }

    /// Female standards as a fraction of the male ones.
    ///
    /// The gap is real and pattern-dependent: it is widest in upper-body
    /// pressing and narrowest in lower-body and hip-dominant work, which is why
    /// this is per-pattern rather than one global number. Using a single
    /// multiplier would make lower-body ranks unreachably hard and upper-body
    /// ranks trivially easy.
    var femaleFactor: Double {
        switch self {
        case .horizontalPress, .verticalPress: return 0.62
        case .elbowExtension, .lateralRaise:   return 0.62
        case .elbowFlexion:                    return 0.64
        case .horizontalPull, .verticalPull:   return 0.68
        case .shrug:                           return 0.70
        case .squat, .legPress, .legExtension: return 0.75
        case .hinge, .legCurl:                 return 0.78
        case .calfRaise:                       return 0.80
        case .hipThrust:                       return 0.85
        }
    }

    func ratios(for sex: LifterSex) -> [Double] {
        switch sex {
        case .male:
            return maleRatios
        case .female:
            return maleRatios.map { $0 * femaleFactor }
        case .unspecified:
            // Midpoint, so an unspecified lifter is never wildly misranked in
            // either direction. Prompting for sex gets them a real rank.
            let factor = (1.0 + femaleFactor) / 2.0
            return maleRatios.map { $0 * factor }
        }
    }
}

// MARK: - Lifter attributes

enum LifterSex: String, Codable, CaseIterable, Identifiable {
    case male, female, unspecified
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .male:        return "Male"
        case .female:      return "Female"
        case .unspecified: return "Prefer not to say"
        }
    }
}

// MARK: - Exercise mapping

/// Maps every exercise to the anchor it is ranked against, plus a coefficient
/// for how its achievable load compares.
///
/// Coefficients follow a few consistent rules:
///   - Dumbbell variants of a barbell lift sit slightly below it, and are scored
///     on combined load (both hands) so the number stays comparable.
///   - Machine and Smith variants sit *above* the free-weight version, since
///     stability is provided.
///   - Incline/decline, close/wide grip, and paused variants scale off the
///     parent lift.
///   - Single-limb variants are scored on combined load, so they land near
///     their bilateral parent rather than at half.
enum StrengthStandards {

    struct Profile {
        let pattern: MovementPattern
        let coefficient: Double
        let basis: LoadBasis

        init(_ pattern: MovementPattern, _ coefficient: Double, _ basis: LoadBasis = .external) {
            self.pattern = pattern
            self.coefficient = coefficient
            self.basis = basis
        }
    }

    /// Exercises with no meaningful load ranking. Kept as an explicit list so a
    /// newly added mobility or core-hold movement fails loudly as "unmapped"
    /// rather than silently inheriting a bogus rank.
    private static let unranked = Profile(.squat, 1.0, .notRanked)

    static let profiles: [String: Profile] = [
        // MARK: Chest — horizontal press
        "ex-bench-flat":                     Profile(.horizontalPress, 1.00),
        "ex-bench-incline":                  Profile(.horizontalPress, 0.82),
        "ex-decline-bench":                  Profile(.horizontalPress, 1.05),
        "ex-close-grip-bench":               Profile(.horizontalPress, 0.85),
        "ex-bench-db":                       Profile(.horizontalPress, 0.90),
        "ex-incline-db":                     Profile(.horizontalPress, 0.74),
        "ex-decline-db-press":               Profile(.horizontalPress, 0.92),
        "ex-machine-press":                  Profile(.horizontalPress, 1.15),
        "ex-incline-machine-press":          Profile(.horizontalPress, 0.95),
        "ex-smith-bench-press":              Profile(.horizontalPress, 1.10),
        "ex-smith-incline-press":            Profile(.horizontalPress, 0.90),
        "ex-iso-lateral-chest-press":        Profile(.horizontalPress, 1.10),
        "ex-hammer-strength-incline-press":  Profile(.horizontalPress, 0.95),
        "ex-landmine-press":                 Profile(.horizontalPress, 0.55),
        "ex-single-arm-cable-press":         Profile(.horizontalPress, 0.60),
        "ex-single-arm-floor-press":         Profile(.horizontalPress, 0.70),
        "ex-svend-press":                    Profile(.horizontalPress, 0.15),
        // Flies are a much shorter lever than a press.
        "ex-chest-fly":                      Profile(.horizontalPress, 0.42),
        "ex-db-fly":                          Profile(.horizontalPress, 0.36),
        "ex-pec-deck":                        Profile(.horizontalPress, 0.55),
        "ex-cable-high-fly":                  Profile(.horizontalPress, 0.40),
        "ex-cable-low-fly":                   Profile(.horizontalPress, 0.38),
        "ex-decline-cable-fly":               Profile(.horizontalPress, 0.40),
        "ex-cable-crossover":                 Profile(.horizontalPress, 0.42),
        // Bodyweight pressing.
        "ex-pushup":                          Profile(.horizontalPress, 0.64, .bodyweightPlusAdded),
        "ex-decline-pushup":                  Profile(.horizontalPress, 0.70, .bodyweightPlusAdded),
        "ex-diamond-pushup":                  Profile(.horizontalPress, 0.62, .bodyweightPlusAdded),
        "ex-dips":                            Profile(.horizontalPress, 1.00, .bodyweightPlusAdded),
        "ex-weighted-dip":                    Profile(.horizontalPress, 1.00, .bodyweightPlusAdded),
        "ex-assisted-dip-machine":            Profile(.horizontalPress, 1.00, .bodyweightPlusAdded),
        "ex-tricep-dip-machine":              Profile(.elbowExtension, 1.30),

        // MARK: Back — vertical pull
        "ex-pullup":                          Profile(.verticalPull, 1.00, .bodyweightPlusAdded),
        "ex-chinup":                          Profile(.verticalPull, 1.05, .bodyweightPlusAdded),
        "ex-lat-pulldown":                    Profile(.verticalPull, 1.00),
        "ex-close-grip-pulldown":             Profile(.verticalPull, 1.02),
        "ex-reverse-grip-pulldown":           Profile(.verticalPull, 1.05),
        "ex-cable-wide-bar-lat-pulldown":     Profile(.verticalPull, 0.95),
        "ex-kneeling-lat-pulldown":           Profile(.verticalPull, 0.80),
        "ex-single-arm-lat-pulldown":         Profile(.verticalPull, 0.85),
        "ex-single-arm-overhand-pulldown":    Profile(.verticalPull, 0.82),
        "ex-machine-high-row":                Profile(.verticalPull, 1.10),
        "ex-straight-arm-pulldown":           Profile(.verticalPull, 0.45),
        "ex-cable-straight-arm-pullover":     Profile(.verticalPull, 0.45),
        "ex-pullover-machine":                Profile(.verticalPull, 0.60),
        "ex-db-pullover":                     Profile(.verticalPull, 0.38),
        "ex-band-pullover":                   Profile(.verticalPull, 0.20),

        // MARK: Back — horizontal pull
        "ex-row-barbell":                     Profile(.horizontalPull, 1.00),
        "ex-pendlay-row":                     Profile(.horizontalPull, 0.95),
        "ex-tbar-row":                        Profile(.horizontalPull, 1.10),
        "ex-seal-row":                        Profile(.horizontalPull, 0.90),
        "ex-smith-row":                       Profile(.horizontalPull, 1.05),
        "ex-chest-supported-row":             Profile(.horizontalPull, 0.95),
        "ex-machine-row":                     Profile(.horizontalPull, 1.15),
        "ex-iso-lateral-row":                 Profile(.horizontalPull, 1.15),
        "ex-cable-row":                       Profile(.horizontalPull, 1.05),
        "ex-seated-cable-row-wide-grip":      Profile(.horizontalPull, 1.00),
        "ex-half-kneeling-cable-row":         Profile(.horizontalPull, 0.70),
        "ex-row-db":                          Profile(.horizontalPull, 0.85),
        "ex-meadows-row":                     Profile(.horizontalPull, 0.70),
        "ex-single-arm-cable-row":            Profile(.horizontalPull, 0.80),
        "ex-single-arm-low-cable-row":        Profile(.horizontalPull, 0.80),
        "ex-single-arm-machine-row":          Profile(.horizontalPull, 0.95),
        "ex-inverted-row":                    Profile(.horizontalPull, 0.75, .bodyweightPlusAdded),

        // MARK: Rear delts / face pulls — light, high-rep patterns
        "ex-face-pull":                       Profile(.lateralRaise, 1.60),
        "ex-single-arm-face-pull":            Profile(.lateralRaise, 0.90),
        "ex-cable-face-pull-straight-bar":    Profile(.lateralRaise, 1.60),
        "ex-rear-delt-fly":                   Profile(.lateralRaise, 0.85),
        "ex-cable-rear-delt-fly":             Profile(.lateralRaise, 0.90),
        "ex-cable-rear-delt-fly-high-low":    Profile(.lateralRaise, 0.90),
        "ex-cable-reverse-fly":               Profile(.lateralRaise, 0.90),
        "ex-reverse-pec-deck":                Profile(.lateralRaise, 1.50),
        "ex-y-raise":                         Profile(.lateralRaise, 0.55),

        // MARK: Shoulders — vertical press
        "ex-ohp":                             Profile(.verticalPress, 1.00),
        "ex-db-shoulder-press":               Profile(.verticalPress, 0.90),
        "ex-arnold-press":                    Profile(.verticalPress, 0.82),
        "ex-machine-shoulder-press":          Profile(.verticalPress, 1.15),
        "ex-smith-shoulder-press":            Profile(.verticalPress, 1.10),
        "ex-single-arm-db-shoulder-press":    Profile(.verticalPress, 0.80),
        "ex-single-arm-landmine-press":       Profile(.verticalPress, 0.55),
        "ex-pike-pushup":                     Profile(.verticalPress, 0.55, .bodyweightPlusAdded),

        // MARK: Shoulders — raises
        "ex-lateral-raise":                   Profile(.lateralRaise, 1.00),
        "ex-cable-lateral-raise":             Profile(.lateralRaise, 1.05),
        "ex-machine-lateral-raise":           Profile(.lateralRaise, 1.60),
        "ex-front-raise":                     Profile(.lateralRaise, 1.15),
        "ex-cable-front-raise":               Profile(.lateralRaise, 1.20),
        "ex-upright-row":                     Profile(.lateralRaise, 2.60),
        "ex-cable-upright-row":               Profile(.lateralRaise, 2.70),

        // MARK: Traps
        "ex-shrugs":                          Profile(.shrug, 1.00),
        "ex-db-shrugs":                       Profile(.shrug, 0.90),
        "ex-machine-shrugs":                  Profile(.shrug, 1.10),
        "ex-cable-shrug":                     Profile(.shrug, 0.95),

        // MARK: Legs — squat
        "ex-squat":                           Profile(.squat, 1.00),
        "ex-front-squat":                     Profile(.squat, 0.80),
        "ex-box-squat":                       Profile(.squat, 1.05),
        "ex-zercher-squat":                   Profile(.squat, 0.70),
        "ex-smith-squat":                     Profile(.squat, 1.10),
        "ex-smith-front-squat":               Profile(.squat, 0.88),
        "ex-hack-squat":                      Profile(.squat, 1.30),
        "ex-belt-squat":                      Profile(.squat, 1.20),
        "ex-goblet-squat":                    Profile(.squat, 0.35),
        "ex-kb-goblet-squat":                 Profile(.squat, 0.35),
        "ex-bulgarian-split-squat":           Profile(.squat, 0.50),
        "ex-split-squat":                     Profile(.squat, 0.50),
        "ex-lunge":                           Profile(.squat, 0.45),
        "ex-reverse-lunge":                   Profile(.squat, 0.45),
        "ex-lateral-lunge":                   Profile(.squat, 0.35),
        "ex-curtsy-lunge":                    Profile(.squat, 0.35),
        "ex-step-ups":                        Profile(.squat, 0.40),
        "ex-cossack-squat":                   Profile(.squat, 0.30, .bodyweightPlusAdded),
        "ex-pistol-squat":                    Profile(.squat, 0.55, .bodyweightPlusAdded),
        "ex-sissy-squat":                     Profile(.squat, 0.40, .bodyweightPlusAdded),

        // MARK: Legs — hinge
        "ex-deadlift":                        Profile(.hinge, 1.00),
        "ex-sumo-deadlift":                   Profile(.hinge, 1.02),
        "ex-trap-bar-deadlift":               Profile(.hinge, 1.08),
        "ex-suitcase-deadlift":               Profile(.hinge, 0.55),
        "ex-rdl":                             Profile(.hinge, 0.85),
        "ex-db-rdl":                          Profile(.hinge, 0.70),
        "ex-single-leg-rdl":                  Profile(.hinge, 0.45),
        "ex-kb-single-leg-rdl":               Profile(.hinge, 0.40),
        "ex-good-morning":                    Profile(.hinge, 0.55),
        "ex-kb-swing":                        Profile(.hinge, 0.35),
        "ex-rope-deadlift-simulator":         Profile(.hinge, 0.50),
        "ex-cable-pull-through":              Profile(.hinge, 0.45),
        "ex-reverse-hyper":                   Profile(.hinge, 0.55),
        "ex-nordic-curl":                     Profile(.legCurl, 1.40, .bodyweightPlusAdded),
        "ex-glute-ham-raise":                 Profile(.legCurl, 1.20, .bodyweightPlusAdded),

        // MARK: Glutes
        "ex-hip-thrust":                      Profile(.hipThrust, 1.00),
        "ex-single-leg-hip-thrust":           Profile(.hipThrust, 0.45),
        "ex-kneeling-hip-thrust-machine":     Profile(.hipThrust, 0.85),
        "ex-glute-bridge":                    Profile(.hipThrust, 0.70),
        "ex-glute-kickback":                  Profile(.hipThrust, 0.25),
        "ex-cable-kickback":                  Profile(.hipThrust, 0.18),
        "ex-cable-hip-abduction":             Profile(.hipThrust, 0.20),
        "ex-side-lying-hip-abduction":        Profile(.hipThrust, 0.10),

        // MARK: Legs — machines
        "ex-leg-press":                       Profile(.legPress, 1.00),
        "ex-single-leg-press":                Profile(.legPress, 0.60),
        "ex-leg-curl":                        Profile(.legCurl, 1.00),
        "ex-seated-leg-curl":                 Profile(.legCurl, 1.05),
        "ex-single-leg-curl":                 Profile(.legCurl, 0.60),
        "ex-leg-ext":                         Profile(.legExtension, 1.00),
        "ex-single-leg-ext":                  Profile(.legExtension, 0.60),

        // MARK: Calves
        "ex-calf-raise":                      Profile(.calfRaise, 1.00),
        "ex-seated-calf-raise":               Profile(.calfRaise, 0.55),
        "ex-smith-calf-raise":                Profile(.calfRaise, 1.05),
        "ex-donkey-calf-raise":               Profile(.calfRaise, 0.95),
        "ex-single-leg-calf-raise":           Profile(.calfRaise, 0.60),

        // MARK: Biceps
        "ex-barbell-curl":                    Profile(.elbowFlexion, 1.00),
        "ex-ez-bar-curl":                     Profile(.elbowFlexion, 1.02),
        "ex-db-curl":                         Profile(.elbowFlexion, 0.90),
        "ex-hammer-curl":                     Profile(.elbowFlexion, 1.00),
        "ex-cross-body-hammer-curl":          Profile(.elbowFlexion, 0.95),
        "ex-incline-db-curl":                 Profile(.elbowFlexion, 0.70),
        "ex-preacher-curl":                   Profile(.elbowFlexion, 0.80),
        "ex-spider-curl":                     Profile(.elbowFlexion, 0.75),
        "ex-concentration-curl":              Profile(.elbowFlexion, 0.65),
        "ex-cable-curl":                      Profile(.elbowFlexion, 1.05),
        "ex-bayesian-curl":                   Profile(.elbowFlexion, 0.85),
        "ex-hammer-cable-curl":               Profile(.elbowFlexion, 1.05),
        "ex-reverse-curl":                    Profile(.elbowFlexion, 0.70),
        "ex-single-arm-cable-curl":           Profile(.elbowFlexion, 0.85),
        "ex-single-arm-cable-preacher":       Profile(.elbowFlexion, 0.70),
        "ex-single-arm-machine-preacher":     Profile(.elbowFlexion, 0.85),

        // MARK: Triceps
        "ex-tricep-pushdown":                 Profile(.elbowExtension, 1.00),
        "ex-single-arm-pushdown":             Profile(.elbowExtension, 0.55),
        "ex-skull-crusher":                   Profile(.elbowExtension, 0.75),
        "ex-cable-lying-tricep-extension":    Profile(.elbowExtension, 0.85),
        "ex-overhead-ext":                    Profile(.elbowExtension, 0.70),
        "ex-cable-overhead-tri-ext":          Profile(.elbowExtension, 0.80),
        "ex-single-arm-cable-oh-ext":         Profile(.elbowExtension, 0.45),
        "ex-kickbacks":                       Profile(.elbowExtension, 0.30),

        // MARK: Forearms
        "ex-wrist-curl":                      Profile(.elbowFlexion, 0.55),
        "ex-single-arm-wrist-curl":           Profile(.elbowFlexion, 0.32),
        "ex-single-arm-reverse-wrist-curl":   Profile(.elbowFlexion, 0.22),
        "ex-single-arm-farmers-carry":        Profile(.shrug, 0.55),

        // MARK: Abs — the loaded ones
        "ex-cable-crunch":                    Profile(.elbowExtension, 1.10),
        "ex-kneeling-rope-crunch":            Profile(.elbowExtension, 1.10),
        "ex-cable-woodchop":                  Profile(.lateralRaise, 1.30),
        "ex-cable-woodchopper-high-low":      Profile(.lateralRaise, 1.30),
        "ex-pallof-press":                    Profile(.lateralRaise, 1.10),
        "ex-single-arm-pallof-press":         Profile(.lateralRaise, 0.70),
        "ex-russian-twist":                   Profile(.lateralRaise, 0.90),
        "ex-decline-situp":                   Profile(.elbowExtension, 0.40, .bodyweightPlusAdded),
        "ex-roman-chair-decline-crunch":      Profile(.elbowExtension, 0.40, .bodyweightPlusAdded),
        "ex-hanging-leg-raise":               Profile(.elbowExtension, 0.50, .bodyweightPlusAdded),
        "ex-ab-wheel":                        Profile(.elbowExtension, 0.45, .bodyweightPlusAdded),

        // MARK: Not weight-ranked — holds, mobility, conditioning
        // Added with the library gap-fill. Ratios are relative to the closest
        // already-mapped movement: a machine standing calf raise loads more than
        // a bodyweight one, a leg-press calf raise more again.
        "ex-standing-calf-machine":           Profile(.calfRaise, 1.10),
        "ex-leg-press-calf-raise":            Profile(.calfRaise, 1.60),
        "ex-reverse-wrist-curl":              Profile(.elbowFlexion, 0.28),
        "ex-behind-back-shrug":               Profile(.shrug, 0.90),
        "ex-band-tricep-pushdown":            Profile(.elbowExtension, 0.20),
        "ex-kb-clean-press":                  Profile(.verticalPress, 0.40),

        // Scored by time, distance or bodyweight control rather than load.
        // Explicitly unranked rather than left unmapped, so the coverage test
        // stays meaningful — an unmapped exercise is an oversight, an unranked
        // one is a decision.
        "ex-farmers-carry":                   unranked,
        "ex-dead-hang":                       unranked,
        "ex-plate-pinch":                     unranked,
        "ex-hanging-knee-raise":              unranked,
        "ex-hollow-hold":                     unranked,
        "ex-kb-turkish-getup":                unranked,
        "ex-kb-front-rack-carry":             unranked,
        "ex-band-pull-apart":                 unranked,
        "ex-band-face-pull":                  unranked,
        "ex-band-good-morning":               unranked,
        "ex-band-lateral-walk":               unranked,
        "ex-plank":                           unranked,
        "ex-side-plank":                      unranked,
        "ex-copenhagen-plank":                unranked,
        "ex-dead-bug":                        unranked,
        "ex-mountain-climbers":               unranked,
        "ex-worlds-greatest-stretch":         unranked,
        "ex-cat-cow":                         unranked,
        "ex-90-90-hip-stretch":               unranked,
        "ex-90-90-mobility":                  unranked
    ]

    /// Profile for an exercise, or nil when it has no mapping.
    ///
    /// A nil result means "not ranked yet" rather than "unrankable" — see
    /// `StrengthStandardsTests.testEveryExerciseIsMapped`, which fails when a
    /// new exercise is added to the database without a decision being made here.
    static func profile(for exerciseId: String) -> Profile? {
        profiles[exerciseId]
    }

    /// Weight thresholds for every rank on this exercise, for a given lifter.
    /// Index order matches `StrengthTier.ranked`.
    static func thresholds(
        exerciseId: String,
        bodyweight: Double,
        sex: LifterSex
    ) -> [Double]? {
        guard let profile = profile(for: exerciseId), profile.basis != .notRanked else { return nil }
        guard bodyweight > 0 else { return nil }

        return profile.pattern.ratios(for: sex).map { ratio in
            ratio * bodyweight * profile.coefficient
        }
    }
}
