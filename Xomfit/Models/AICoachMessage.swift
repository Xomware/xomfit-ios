import Foundation

/// A single message in the AI Coach chat session.
/// Persisted to UserDefaults via `AICoachViewModel.persist()`.
struct AICoachMessage: Identifiable, Equatable, Codable {
    enum Role: String, Codable {
        case user
        case assistant
    }

    let id: UUID
    let role: Role
    var text: String
    let createdAt: Date
    /// True while the assistant is actively streaming tokens into `text`.
    var isStreaming: Bool
    /// Populated when the assistant emitted a `build_workout` tool use call
    /// during this turn. Used by the chat view to render a Save/Start card
    /// inline under the message.
    var workoutPayload: WorkoutBuildPayload?

    init(
        id: UUID = UUID(),
        role: Role,
        text: String,
        createdAt: Date = Date(),
        isStreaming: Bool = false,
        workoutPayload: WorkoutBuildPayload? = nil
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
        self.isStreaming = isStreaming
        self.workoutPayload = workoutPayload
    }
}

// MARK: - Tool-use payload

/// Decoded `build_workout` tool input emitted by Claude.
/// Mirrors the JSON schema declared in `AICoachService.buildWorkoutTool`.
struct WorkoutBuildPayload: Codable, Equatable {
    var name: String
    var estimatedDurationMinutes: Int?
    var exercises: [Exercise]

    struct Exercise: Codable, Equatable {
        var exerciseId: String
        var sets: Int
        var targetReps: Int
        var targetWeight: Double?
    }
}
