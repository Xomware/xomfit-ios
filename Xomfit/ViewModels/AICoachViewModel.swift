import Foundation
import Observation

/// View model for the AI Coach chat. In-memory message list per app launch (v1).
@MainActor
@Observable
final class AICoachViewModel {
    // MARK: - State

    /// Conversation history. Renders top → bottom in the chat view.
    var messages: [AICoachMessage] = []

    /// Current draft text in the composer.
    var draft: String = ""

    /// True while waiting on (or streaming from) Anthropic.
    var isSending: Bool = false

    /// Latest user-visible error message. Cleared automatically on next send.
    var errorMessage: String?

    /// Suggested prompts shown when the conversation is empty.
    let suggestionChips: [String] = [
        "Build me today's workout",
        "Suggest a 4-day split",
        "Help me hit a 225 bench"
    ]

    // MARK: - Dependencies

    private let service: AICoachService
    /// Runtime override for the API key (read from Settings via @AppStorage).
    /// The view passes this in on each send.
    init(service: AICoachService = .shared) {
        self.service = service
    }

    // MARK: - Derived

    var isEmpty: Bool { messages.isEmpty }

    var canSend: Bool {
        !isSending && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Actions

    /// Append a chip's text to the draft and immediately send it.
    func sendSuggestion(_ text: String, apiKeyOverride: String?) async {
        draft = text
        await send(apiKeyOverride: apiKeyOverride)
    }

    /// Send the current draft. No-op when nothing to send.
    func send(apiKeyOverride: String?) async {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }

        errorMessage = nil
        let userMessage = AICoachMessage(role: .user, text: trimmed)
        messages.append(userMessage)
        draft = ""
        isSending = true

        // Insert a placeholder assistant bubble that we'll replace when the
        // reply arrives. Marked streaming so the UI can show a typing dot.
        let placeholderId = UUID()
        messages.append(
            AICoachMessage(id: placeholderId, role: .assistant, text: "", isStreaming: true)
        )

        do {
            // Send everything except the placeholder (last entry).
            let history = Array(messages.dropLast())
            let reply = try await service.sendMessage(
                messages: history,
                apiKeyOverride: apiKeyOverride
            )
            replacePlaceholder(id: placeholderId, with: reply)
        } catch {
            // Drop the placeholder and surface the error.
            messages.removeAll { $0.id == placeholderId }
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        isSending = false
    }

    /// Clear the conversation and any pending error.
    func reset() {
        messages.removeAll()
        draft = ""
        errorMessage = nil
        isSending = false
    }

    // MARK: - Private

    private func replacePlaceholder(id: UUID, with text: String) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].text = text
        messages[index].isStreaming = false
    }
}
