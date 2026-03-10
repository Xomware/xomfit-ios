import Foundation

/// Represents a live workout session that friends can view in real-time
struct LiveWorkout: Codable, Identifiable {
    let id: String
    let userId: String
    var user: AppUser?
    var currentExercise: WorkoutExercise?
    var currentSet: WorkoutSet?
    var reactions: [LiveReaction] = []
    var viewers: [String] = [] // user IDs currently viewing
    var startTime: Date
    var lastUpdated: Date
    var isActive: Bool
    
    var duration: TimeInterval {
        Date().timeIntervalSince(startTime)
    }
    
    var durationString: String {
        let minutes = Int(duration / 60)
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
    
    var viewerCount: Int {
        viewers.count
    }
}

/// Represents a reaction/cheer from a friend during a live workout
struct LiveReaction: Codable, Identifiable {
    let id: String
    let userId: String
    var user: AppUser?
    let emoji: String // 💪, 🔥, 👏, etc.
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case id, userId, user, emoji, timestamp
    }
}

/// Represents a friend currently watching your live workout
struct LiveWorkoutViewer: Codable, Identifiable {
    let id: String
    let userId: String
    var user: AppUser?
    let joinedAt: Date
    let allowedReactions: [String] = ["💪", "🔥", "👏", "🎯", "😤"]
}

/// WebSocket message for real-time updates
struct LiveWorkoutUpdate: Codable {
    enum MessageType: String, Codable {
        case setCompleted = "set_completed"
        case exerciseChanged = "exercise_changed"
        case reactionAdded = "reaction_added"
        case viewerJoined = "viewer_joined"
        case viewerLeft = "viewer_left"
        case workoutEnded = "workout_ended"
    }
    
    let type: MessageType
    let liveWorkoutId: String
    let data: AnyCodable // flexible payload
    let timestamp: Date
}

/// Generic codable wrapper for any data
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let value = value as? String {
            try container.encode(value)
        } else if let value = value as? Int {
            try container.encode(value)
        } else if let value = value as? Double {
            try container.encode(value)
        } else if let value = value as? Bool {
            try container.encode(value)
        } else {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: [], debugDescription: "Value not supported"))
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self.value = value
        } else if let value = try? container.decode(Int.self) {
            self.value = value
        } else if let value = try? container.decode(Double.self) {
            self.value = value
        } else if let value = try? container.decode(Bool.self) {
            self.value = value
        } else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Unknown type"))
        }
    }
}
