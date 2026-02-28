import Foundation

// MARK: - Workout Program Model

struct WorkoutProgram: Codable, Identifiable {
    let id: String
    var title: String
    var description: String
    var creatorId: String
    var creatorName: String
    var creatorAvatarUrl: String?
    var daysPerWeek: Int
    var durationWeeks: Int
    var difficulty: ProgramDifficulty
    var goals: [ProgramGoal]
    var exercises: [ProgramExercise]
    var price: Double           // 0.0 = free; reserved for future monetization
    var rating: Double
    var reviewCount: Int
    var importCount: Int
    var isFeatured: Bool
    var isPublic: Bool
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date

    // Computed helpers
    var isFree: Bool { price == 0 }
    var formattedRating: String { String(format: "%.1f", rating) }
    var difficultyColor: String {
        switch difficulty {
        case .beginner:     return "34C759"
        case .intermediate: return "FF9500"
        case .advanced:     return "FF3B30"
        case .elite:        return "AF52DE"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, title, description
        case creatorId       = "creator_id"
        case creatorName     = "creator_name"
        case creatorAvatarUrl = "creator_avatar_url"
        case daysPerWeek     = "days_per_week"
        case durationWeeks   = "duration_weeks"
        case difficulty, goals, exercises, price, rating
        case reviewCount     = "review_count"
        case importCount     = "import_count"
        case isFeatured      = "is_featured"
        case isPublic        = "is_public"
        case tags
        case createdAt       = "created_at"
        case updatedAt       = "updated_at"
    }
}

// MARK: - Program Difficulty

enum ProgramDifficulty: String, Codable, CaseIterable {
    case beginner, intermediate, advanced, elite

    var displayName: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .beginner:     return "1.circle.fill"
        case .intermediate: return "2.circle.fill"
        case .advanced:     return "3.circle.fill"
        case .elite:        return "star.circle.fill"
        }
    }
}

// MARK: - Program Goal

enum ProgramGoal: String, Codable, CaseIterable {
    case strength, hypertrophy, weightLoss, endurance, athletic, mobility, powerlifting, bodybuilding

    var displayName: String {
        switch self {
        case .strength:      return "Strength"
        case .hypertrophy:   return "Hypertrophy"
        case .weightLoss:    return "Weight Loss"
        case .endurance:     return "Endurance"
        case .athletic:      return "Athletic"
        case .mobility:      return "Mobility"
        case .powerlifting:  return "Powerlifting"
        case .bodybuilding:  return "Bodybuilding"
        }
    }

    var icon: String {
        switch self {
        case .strength:      return "bolt.fill"
        case .hypertrophy:   return "figure.strengthtraining.traditional"
        case .weightLoss:    return "flame.fill"
        case .endurance:     return "heart.fill"
        case .athletic:      return "figure.run"
        case .mobility:      return "figure.flexibility"
        case .powerlifting:  return "dumbbell.fill"
        case .bodybuilding:  return "figure.arms.open"
        }
    }

    enum CodingKeys: String, CodingKey {
        case strength, hypertrophy
        case weightLoss   = "weight_loss"
        case endurance, athletic, mobility, powerlifting, bodybuilding
    }
}

// MARK: - Program Exercise

struct ProgramExercise: Codable, Identifiable {
    let id: String
    var exerciseName: String
    var muscleGroups: [String]
    var sets: Int
    var reps: String        // e.g. "8-12", "5", "AMRAP"
    var restSeconds: Int
    var notes: String?
    var weekDay: Int        // 1-7
    var order: Int

    enum CodingKeys: String, CodingKey {
        case id
        case exerciseName  = "exercise_name"
        case muscleGroups  = "muscle_groups"
        case sets, reps
        case restSeconds   = "rest_seconds"
        case notes
        case weekDay       = "week_day"
        case order
    }
}

// MARK: - Program Review

struct ProgramReview: Codable, Identifiable {
    let id: String
    var programId: String
    var userId: String
    var userName: String
    var userAvatarUrl: String?
    var rating: Int             // 1-5
    var body: String
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case programId      = "program_id"
        case userId         = "user_id"
        case userName       = "user_name"
        case userAvatarUrl  = "user_avatar_url"
        case rating, body
        case createdAt      = "created_at"
    }
}

// MARK: - Filter / Sort

enum MarketplaceFilter: String, CaseIterable {
    case all        = "All"
    case featured   = "Featured"
    case new        = "New"
    case popular    = "Popular"
    case free       = "Free"

    var displayName: String { rawValue }
}

enum MarketplaceSortOrder: String, CaseIterable {
    case rating     = "Rating"
    case newest     = "Newest"
    case popular    = "Most Popular"
    case price      = "Price"

    var displayName: String { rawValue }
}

// MARK: - Mock Data

extension WorkoutProgram {
    static let mockPrograms: [WorkoutProgram] = [
        WorkoutProgram(
            id: "prog-1",
            title: "5/3/1 Powerbuilding",
            description: "Jim Wendler's legendary 5/3/1 program adapted for muscle mass and strength gains. 4-day upper/lower split with main lifts and hypertrophy accessories.",
            creatorId: "user-jim",
            creatorName: "JimLifts",
            creatorAvatarUrl: nil,
            daysPerWeek: 4,
            durationWeeks: 12,
            difficulty: .intermediate,
            goals: [.strength, .hypertrophy],
            exercises: [],
            price: 0,
            rating: 4.8,
            reviewCount: 324,
            importCount: 1872,
            isFeatured: true,
            isPublic: true,
            tags: ["powerlifting", "4-day", "barbells"],
            createdAt: Date().addingTimeInterval(-86400 * 90),
            updatedAt: Date().addingTimeInterval(-86400 * 10)
        ),
        WorkoutProgram(
            id: "prog-2",
            title: "Hypertrophy Kickstart",
            description: "A 6-week beginner-friendly program focused on building a foundation of muscle. High volume, moderate weights, full-body 3x per week.",
            creatorId: "user-alex",
            creatorName: "AlexFit",
            creatorAvatarUrl: nil,
            daysPerWeek: 3,
            durationWeeks: 6,
            difficulty: .beginner,
            goals: [.hypertrophy],
            exercises: [],
            price: 0,
            rating: 4.5,
            reviewCount: 187,
            importCount: 942,
            isFeatured: true,
            isPublic: true,
            tags: ["beginner", "full-body", "3-day"],
            createdAt: Date().addingTimeInterval(-86400 * 30),
            updatedAt: Date().addingTimeInterval(-86400 * 2)
        ),
        WorkoutProgram(
            id: "prog-3",
            title: "HIIT Fat Burner",
            description: "8-week high-intensity interval training program for fat loss and conditioning. Minimal equipment needed.",
            creatorId: "user-sarah",
            creatorName: "SarahStrong",
            creatorAvatarUrl: nil,
            daysPerWeek: 5,
            durationWeeks: 8,
            difficulty: .intermediate,
            goals: [.weightLoss, .endurance],
            exercises: [],
            price: 0,
            rating: 4.2,
            reviewCount: 93,
            importCount: 456,
            isFeatured: false,
            isPublic: true,
            tags: ["HIIT", "fat-loss", "cardio"],
            createdAt: Date().addingTimeInterval(-86400 * 14),
            updatedAt: Date().addingTimeInterval(-86400 * 1)
        ),
        WorkoutProgram(
            id: "prog-4",
            title: "Advanced PPL",
            description: "Push Pull Legs 6-day split for advanced lifters. High frequency, high volume with progressive overload built in.",
            creatorId: "user-dom",
            creatorName: "DomPower",
            creatorAvatarUrl: nil,
            daysPerWeek: 6,
            durationWeeks: 16,
            difficulty: .advanced,
            goals: [.hypertrophy, .strength],
            exercises: [],
            price: 0,
            rating: 4.9,
            reviewCount: 512,
            importCount: 2341,
            isFeatured: true,
            isPublic: true,
            tags: ["PPL", "6-day", "advanced"],
            createdAt: Date().addingTimeInterval(-86400 * 60),
            updatedAt: Date().addingTimeInterval(-86400 * 5)
        )
    ]
}
