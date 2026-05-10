import Foundation

struct Workout: Codable, Identifiable {
    let id: String
    var userId: String
    var name: String
    var exercises: [WorkoutExercise]
    var startTime: Date
    var endTime: Date?
    var notes: String?
    var location: String?
    var rating: Int?
    /// Songs captured passively during this workout via `NowPlayingService` (#302).
    /// Apple Music only — see `WorkoutTrack` for the iOS platform restriction.
    /// Defaulted so older cached / decoded payloads stay backward-compatible.
    var tracks: [WorkoutTrack] = []

    var startDate: Date { startTime }

    // MARK: - Codable
    //
    // Custom decoder so older cached `Workout` payloads (no `tracks` key) keep decoding.
    // Encoding stays synthesized.
    enum CodingKeys: String, CodingKey {
        case id, userId, name, exercises, startTime, endTime, notes, location, rating, tracks
    }

    init(
        id: String,
        userId: String,
        name: String,
        exercises: [WorkoutExercise],
        startTime: Date,
        endTime: Date? = nil,
        notes: String? = nil,
        location: String? = nil,
        rating: Int? = nil,
        tracks: [WorkoutTrack] = []
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.exercises = exercises
        self.startTime = startTime
        self.endTime = endTime
        self.notes = notes
        self.location = location
        self.rating = rating
        self.tracks = tracks
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        name = try container.decode(String.self, forKey: .name)
        exercises = try container.decode([WorkoutExercise].self, forKey: .exercises)
        startTime = try container.decode(Date.self, forKey: .startTime)
        endTime = try container.decodeIfPresent(Date.self, forKey: .endTime)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        rating = try container.decodeIfPresent(Int.self, forKey: .rating)
        tracks = try container.decodeIfPresent([WorkoutTrack].self, forKey: .tracks) ?? []
    }

    var duration: TimeInterval {
        (endTime ?? Date()).timeIntervalSince(startTime)
    }
    
    var durationString: String {
        let minutes = Int(duration / 60)
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
    
    var totalVolume: Double {
        exercises.flatMap { $0.sets }.reduce(0) { $0 + $1.volume }
    }
    
    var totalSets: Int {
        exercises.reduce(0) { $0 + $1.sets.count }
    }
    
    var totalPRs: Int {
        exercises.flatMap { $0.sets }.filter { $0.isPersonalRecord }.count
    }
    
    var formattedVolume: String {
        if totalVolume >= 1000 {
            return String(format: "%.1fk", totalVolume / 1000)
        }
        return "\(Int(totalVolume))"
    }
    
    var muscleGroups: [MuscleGroup] {
        Array(Set(exercises.flatMap { $0.exercise.muscleGroups }))
    }
}

/// How the user is performing the exercise — both sides at once, one side at a time, or alternating sides.
enum Laterality: String, Codable, CaseIterable, Identifiable {
    case bilateral    // both arms/legs together (default)
    case unilateral   // one arm/leg at a time (record weight per side)
    case alternating  // alternating sides each rep

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bilateral:   return "Both"
        case .unilateral:  return "Single"
        case .alternating: return "Alternating"
        }
    }
}

struct WorkoutExercise: Codable, Identifiable {
    let id: String
    var exercise: Exercise
    var sets: [WorkoutSet]
    var notes: String?
    var selectedGrip: GripType? = nil
    var selectedAttachment: CableAttachment? = nil
    var selectedPosition: ExercisePosition? = nil
    /// Laterality selection for this exercise instance. Defaults to bilateral.
    var selectedLaterality: Laterality = .bilateral
    /// When non-nil, this exercise is part of a superset group.
    /// All exercises sharing the same UUID are performed back-to-back (1 set of A → 1 set of B → rest → ...).
    var supersetGroupId: UUID? = nil
    /// Per-exercise rest override in seconds. When nil, the global `defaultRestDuration` is used.
    /// Backwards-compatible: pre-existing workouts decode this as nil.
    var restSeconds: Int? = nil

    var bestSet: WorkoutSet? {
        sets.max(by: { $0.volume < $1.volume })
    }

    /// Total volume for this exercise. Doubles the multiplier when performing unilaterally or alternating.
    var totalVolume: Double {
        let lateralityMultiplier: Double = selectedLaterality == .bilateral ? 1.0 : 2.0
        return sets.reduce(0) { acc, set in
            acc + set.weight * Double(set.reps) * (set.weightMode == .perSide ? 2 : 1) * lateralityMultiplier
        }
    }
}

// MARK: - Mock Data
extension Workout {
    static let mock = Workout(
        id: "w-1",
        userId: "user-1",
        name: "Push Day",
        exercises: [
            WorkoutExercise(
                id: "we-1",
                exercise: .benchPress,
                sets: WorkoutSet.mockSets,
                notes: "Felt strong today"
            )
        ],
        startTime: Date().addingTimeInterval(-3600),
        endTime: Date().addingTimeInterval(-600),
        notes: "Great session"
    )
    
    static let mockFriendWorkout = Workout(
        id: "w-2",
        userId: "user-2",
        name: "Leg Day",
        exercises: [
            WorkoutExercise(
                id: "we-2",
                exercise: .squat,
                sets: [
                    WorkoutSet(id: "s-4", exerciseId: "ex-2", weight: 315, reps: 5, rpe: 9, isPersonalRecord: false, completedAt: Date()),
                    WorkoutSet(id: "s-5", exerciseId: "ex-2", weight: 335, reps: 3, rpe: 9.5, isPersonalRecord: true, completedAt: Date()),
                ],
                notes: nil
            )
        ],
        startTime: Date().addingTimeInterval(-7200),
        endTime: Date().addingTimeInterval(-3600),
        notes: nil
    )
}
