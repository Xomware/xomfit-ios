import Foundation

/// A single message in the AI Coach chat session. In-memory only for v1.
struct AICoachMessage: Identifiable, Equatable {
    enum Role: String {
        case user
        case assistant
    }

    let id: UUID
    let role: Role
    var text: String
    let createdAt: Date
    /// True while the assistant is actively streaming tokens into `text`.
    var isStreaming: Bool

    init(
        id: UUID = UUID(),
        role: Role,
        text: String,
        createdAt: Date = Date(),
        isStreaming: Bool = false
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
        self.isStreaming = isStreaming
    }
}
