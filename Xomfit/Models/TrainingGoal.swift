import Foundation

enum TrainingGoal: String, Codable, CaseIterable, Identifiable {
    case strength
    case hypertrophy
    case powerlifting
    case generalFitness

    var id: String { rawValue }

    var title: String {
        switch self {
        case .strength: "Get Stronger"
        case .hypertrophy: "Build Muscle"
        case .powerlifting: "Powerlifting"
        case .generalFitness: "General Fitness"
        }
    }

    var subtitle: String {
        switch self {
        case .strength: "Heavy compounds, low reps"
        case .hypertrophy: "Volume-focused hypertrophy"
        case .powerlifting: "Squat, bench, deadlift"
        case .generalFitness: "Balanced training"
        }
    }

    var icon: String {
        switch self {
        case .strength: "figure.strengthtraining.traditional"
        case .hypertrophy: "dumbbell.fill"
        case .powerlifting: "trophy.fill"
        case .generalFitness: "figure.mixed.cardio"
        }
    }
}
