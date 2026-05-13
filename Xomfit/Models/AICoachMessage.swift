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
    /// Workout format the model wants the app to run. Defaults to `.setsReps`
    /// when omitted so older / partial responses still produce a sane workout (#370).
    var kind: WorkoutKind = .setsReps
    /// Goal duration in whole minutes for `.timedCircuit`, `.amrap`, `.emom`.
    /// Independent of `estimatedDurationMinutes`, which is an informational
    /// estimate for sets/reps workouts.
    var durationMinutes: Int?
    /// Target round count for `.amrap` / `.emom`.
    var rounds: Int?

    struct Exercise: Codable, Equatable {
        var exerciseId: String
        var sets: Int
        var targetReps: Int
        var targetWeight: Double?
    }

    enum CodingKeys: String, CodingKey {
        case name, estimatedDurationMinutes, exercises, kind, durationMinutes, rounds
    }

    init(
        name: String,
        estimatedDurationMinutes: Int? = nil,
        exercises: [Exercise],
        kind: WorkoutKind = .setsReps,
        durationMinutes: Int? = nil,
        rounds: Int? = nil
    ) {
        self.name = name
        self.estimatedDurationMinutes = estimatedDurationMinutes
        self.exercises = exercises
        self.kind = kind
        self.durationMinutes = durationMinutes
        self.rounds = rounds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        estimatedDurationMinutes = try container.decodeIfPresent(Int.self, forKey: .estimatedDurationMinutes)
        exercises = try container.decode([Exercise].self, forKey: .exercises)
        kind = try container.decodeIfPresent(WorkoutKind.self, forKey: .kind) ?? .setsReps
        durationMinutes = try container.decodeIfPresent(Int.self, forKey: .durationMinutes)
        rounds = try container.decodeIfPresent(Int.self, forKey: .rounds)
    }
}
