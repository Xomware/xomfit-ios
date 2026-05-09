import Foundation

// MARK: - Question Enums

/// Primary lifting goal — drives AI helper recommendations (#252).
enum FitnessPrimaryGoal: String, Codable, CaseIterable, Identifiable {
    case buildMuscle
    case getStronger
    case loseFat
    case maintain
    case generalFitness

    var id: String { rawValue }

    var title: String {
        switch self {
        case .buildMuscle:    "Build muscle"
        case .getStronger:    "Get stronger"
        case .loseFat:        "Lose fat"
        case .maintain:       "Maintain"
        case .generalFitness: "General fitness"
        }
    }

    var icon: String {
        switch self {
        case .buildMuscle:    "dumbbell.fill"
        case .getStronger:    "figure.strengthtraining.traditional"
        case .loseFat:        "flame.fill"
        case .maintain:       "checkmark.seal.fill"
        case .generalFitness: "figure.mixed.cardio"
        }
    }
}

/// Lifting experience bucket.
enum FitnessExperience: String, Codable, CaseIterable, Identifiable {
    case beginner
    case intermediate
    case advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .beginner:     "Beginner"
        case .intermediate: "Intermediate"
        case .advanced:     "Advanced"
        }
    }

    var subtitle: String {
        switch self {
        case .beginner:     "Less than 6 months"
        case .intermediate: "6 months – 2 years"
        case .advanced:     "2+ years"
        }
    }
}

/// How many sessions per week the user wants to commit to.
enum FitnessWorkoutsPerWeek: String, Codable, CaseIterable, Identifiable {
    case two
    case three
    case four
    case five
    case sixPlus

    var id: String { rawValue }

    var title: String {
        switch self {
        case .two:     "2"
        case .three:   "3"
        case .four:    "4"
        case .five:    "5"
        case .sixPlus: "6+"
        }
    }
}

/// Preferred training split.
enum FitnessSplit: String, Codable, CaseIterable, Identifiable {
    case fullBody
    case upperLower
    case pushPullLegs
    case broSplit
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fullBody:     "Full body"
        case .upperLower:   "Upper / Lower"
        case .pushPullLegs: "Push / Pull / Legs"
        case .broSplit:     "Bro split"
        case .custom:       "Custom"
        }
    }

    var subtitle: String {
        switch self {
        case .fullBody:     "Hit everything each session"
        case .upperLower:   "Alternate upper and lower"
        case .pushPullLegs: "Classic 3- or 6-day split"
        case .broSplit:     "One muscle group per day"
        case .custom:       "I'll define my own"
        }
    }
}

/// Preferred session duration.
enum FitnessSessionLength: String, Codable, CaseIterable, Identifiable {
    case thirty
    case fortyFive
    case sixty
    case seventyFivePlus

    var id: String { rawValue }

    var title: String {
        switch self {
        case .thirty:           "30 min"
        case .fortyFive:        "45 min"
        case .sixty:            "60 min"
        case .seventyFivePlus:  "75+ min"
        }
    }
}

// MARK: - User Fitness Profile

/// Captured by the onboarding questionnaire (#259) and consumed by the AI helper (#252).
/// Local-first: persisted via `UserDefaults` JSON. Supabase sync may come later.
struct UserFitnessProfile: Codable, Equatable {
    var primaryGoal: FitnessPrimaryGoal?
    var experience: FitnessExperience?
    var workoutsPerWeek: FitnessWorkoutsPerWeek?
    var preferredSplit: FitnessSplit?
    var sessionLength: FitnessSessionLength?

    /// Set when the user finishes the questionnaire. `nil` until completed.
    var completedAt: Date?

    init(
        primaryGoal: FitnessPrimaryGoal? = nil,
        experience: FitnessExperience? = nil,
        workoutsPerWeek: FitnessWorkoutsPerWeek? = nil,
        preferredSplit: FitnessSplit? = nil,
        sessionLength: FitnessSessionLength? = nil,
        completedAt: Date? = nil
    ) {
        self.primaryGoal = primaryGoal
        self.experience = experience
        self.workoutsPerWeek = workoutsPerWeek
        self.preferredSplit = preferredSplit
        self.sessionLength = sessionLength
        self.completedAt = completedAt
    }

    /// True when every required answer is set.
    var isComplete: Bool {
        primaryGoal != nil
            && experience != nil
            && workoutsPerWeek != nil
            && preferredSplit != nil
            && sessionLength != nil
    }
}

// MARK: - UserDefaults-backed singleton accessor

extension UserFitnessProfile {
    /// Single source of truth for the user's fitness questionnaire answers.
    /// Reading always returns a value (empty profile if nothing stored).
    /// Writing JSON-encodes and persists under `userFitnessProfile`.
    static var current: UserFitnessProfile {
        get {
            guard let data = UserDefaults.standard.data(forKey: storageKey) else {
                return UserFitnessProfile()
            }
            do {
                return try JSONDecoder().decode(UserFitnessProfile.self, from: data)
            } catch {
                return UserFitnessProfile()
            }
        }
        set {
            do {
                let data = try JSONEncoder().encode(newValue)
                UserDefaults.standard.set(data, forKey: storageKey)
            } catch {
                // Encoding a small struct of enums + Date should never fail.
                assertionFailure("Failed to encode UserFitnessProfile: \(error)")
            }
        }
    }

    static let storageKey = "userFitnessProfile"
}
