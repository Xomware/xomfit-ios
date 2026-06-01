import Foundation

/// Detailed ratings captured when finishing a workout.
/// All fields are optional so users can fill out as much or as little as they want.
struct WorkoutRatings: Codable, Equatable {
    /// How tired are you after this workout? (1 = fresh, 5 = exhausted)
    var fatigue: Int?
    /// How hard was the workout itself? (1 = easy, 5 = brutal)
    var difficulty: Int?
    /// How busy was the gym? (1 = empty, 5 = packed)
    var crowdedness: Int?
    /// How was your music/atmosphere? (1 = poor, 5 = great)
    var musicVibe: Int?
    /// Energy level going in (1 = low, 5 = high)
    var energyBefore: Int?
    /// How do you feel after? (1 = drained, 5 = energized)
    var moodAfter: Int?

    /// Empty instance for initialization
    static let empty = WorkoutRatings()

    /// True when at least one rating has been set
    var hasAnyRating: Bool {
        fatigue != nil ||
        difficulty != nil ||
        crowdedness != nil ||
        musicVibe != nil ||
        energyBefore != nil ||
        moodAfter != nil
    }

    /// Category metadata for UI rendering
    enum Category: CaseIterable, Identifiable {
        case fatigue
        case difficulty
        case crowdedness
        case musicVibe
        case energyBefore
        case moodAfter

        var id: String { label }

        var label: String {
            switch self {
            case .fatigue: return "Fatigue"
            case .difficulty: return "Difficulty"
            case .crowdedness: return "Gym Crowd"
            case .musicVibe: return "Music Vibe"
            case .energyBefore: return "Energy In"
            case .moodAfter: return "Mood Out"
            }
        }

        var lowLabel: String {
            switch self {
            case .fatigue: return "Fresh"
            case .difficulty: return "Easy"
            case .crowdedness: return "Empty"
            case .musicVibe: return "Poor"
            case .energyBefore: return "Low"
            case .moodAfter: return "Drained"
            }
        }

        var highLabel: String {
            switch self {
            case .fatigue: return "Exhausted"
            case .difficulty: return "Brutal"
            case .crowdedness: return "Packed"
            case .musicVibe: return "Great"
            case .energyBefore: return "High"
            case .moodAfter: return "Energized"
            }
        }
    }

    /// Get the value for a category
    func value(for category: Category) -> Int? {
        switch category {
        case .fatigue: return fatigue
        case .difficulty: return difficulty
        case .crowdedness: return crowdedness
        case .musicVibe: return musicVibe
        case .energyBefore: return energyBefore
        case .moodAfter: return moodAfter
        }
    }

    /// Set the value for a category
    mutating func setValue(_ value: Int?, for category: Category) {
        switch category {
        case .fatigue: fatigue = value
        case .difficulty: difficulty = value
        case .crowdedness: crowdedness = value
        case .musicVibe: musicVibe = value
        case .energyBefore: energyBefore = value
        case .moodAfter: moodAfter = value
        }
    }
}
