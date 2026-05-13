import Foundation
import Observation

/// View model for the AI Coach chat.
/// - Streams replies token-by-token via `AICoachService.sendMessageStream`.
/// - Persists the last 50 messages to UserDefaults under `aiCoach.conversation`.
/// - Captures `build_workout` tool calls and surfaces them on the assistant
///   message so the chat view can render an inline Save / Start card.
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
        "Build me a 10-minute ab circuit",
        "Suggest a 4-day split",
        "Help me hit a 225 bench"
    ]

    // MARK: - Persistence

    /// Storage key for the conversation history.
    private static let storageKey = "aiCoach.conversation"
    /// Cap on stored history so the UserDefaults blob doesn't grow unbounded.
    private static let historyCap = 50

    // MARK: - Dependencies

    private let service: AICoachService
    private let defaults: UserDefaults

    init(service: AICoachService = .shared, defaults: UserDefaults = .standard) {
        self.service = service
        self.defaults = defaults
        self.messages = Self.loadPersisted(from: defaults)
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
    /// Streams the response and updates the placeholder bubble in place.
    func send(apiKeyOverride: String?) async {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }

        errorMessage = nil
        let userMessage = AICoachMessage(role: .user, text: trimmed)
        messages.append(userMessage)
        draft = ""
        isSending = true

        // Insert a placeholder assistant bubble that we'll stream into.
        let placeholderId = UUID()
        messages.append(
            AICoachMessage(id: placeholderId, role: .assistant, text: "", isStreaming: true)
        )
        persist()

        do {
            // Send everything except the placeholder (last entry).
            let history = Array(messages.dropLast())
            let stream = service.sendMessageStream(
                messages: history,
                apiKeyOverride: apiKeyOverride
            )

            for try await event in stream {
                switch event {
                case .textDelta(let chunk):
                    appendText(chunk, to: placeholderId)
                case .toolUse(let payload):
                    attachWorkoutPayload(payload, to: placeholderId)
                case .done:
                    finishStreaming(id: placeholderId)
                }
            }
            // If the stream ended without an explicit `message_stop` (rare),
            // still flip off the streaming flag.
            finishStreaming(id: placeholderId)
        } catch {
            // Drop the placeholder and surface a user-friendly error.
            messages.removeAll { $0.id == placeholderId }
            errorMessage = Self.userFacingMessage(for: error)
            persist()
        }

        isSending = false
    }

    // MARK: - Error mapping (#311)

    /// Maps service / transport errors to copy that tells the user what to do
    /// next. Falls back to `localizedDescription` for the long tail.
    static func userFacingMessage(for error: Error) -> String {
        if let serviceError = error as? AICoachServiceError {
            switch serviceError {
            case .missingAPIKey:
                return "Your API key is invalid. Update it in Settings → AI Coach."
            case .http(let status, _):
                switch status {
                case 401, 403:
                    return "Your API key is invalid. Update it in Settings → AI Coach."
                case 429:
                    return "Rate limited. Try again in a minute."
                default:
                    return serviceError.errorDescription ?? error.localizedDescription
                }
            case .transport(let underlying):
                if let urlError = underlying as? URLError, Self.isOfflineURLError(urlError) {
                    return "You're offline. Check your connection."
                }
                return underlying.localizedDescription
            case .invalidResponse, .decoding:
                return serviceError.errorDescription ?? error.localizedDescription
            }
        }
        if let urlError = error as? URLError, Self.isOfflineURLError(urlError) {
            return "You're offline. Check your connection."
        }
        return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    private static func isOfflineURLError(_ error: URLError) -> Bool {
        switch error.code {
        case .notConnectedToInternet,
             .networkConnectionLost,
             .dataNotAllowed,
             .internationalRoamingOff,
             .timedOut,
             .cannotConnectToHost,
             .cannotFindHost,
             .dnsLookupFailed:
            return true
        default:
            return false
        }
    }

    /// Clear the conversation, wipe the persisted blob, and reset transient state.
    func clearConversation() {
        messages.removeAll()
        draft = ""
        errorMessage = nil
        isSending = false
        persist()
    }

    /// Back-compat alias used by existing views.
    func reset() { clearConversation() }

    // MARK: - Tool actions

    /// Build a `WorkoutTemplate` from a streamed `build_workout` payload.
    /// Skips exercises whose ids aren't present in `ExerciseDatabase.all`
    /// rather than failing the whole tool call. Returns nil if no usable
    /// exercises survive the filter.
    func buildTemplate(from payload: WorkoutBuildPayload) -> WorkoutTemplate? {
        let templateExercises: [WorkoutTemplate.TemplateExercise] = payload.exercises.compactMap { item in
            guard let exercise = ExerciseDatabase.byId[item.exerciseId] else {
                return nil
            }
            let notes: String?
            if let weight = item.targetWeight, weight > 0 {
                notes = "Target weight: \(formatWeight(weight)) lb"
            } else {
                notes = nil
            }
            return WorkoutTemplate.TemplateExercise(
                id: UUID().uuidString,
                exercise: exercise,
                targetSets: max(1, item.sets),
                targetReps: "\(max(1, item.targetReps))",
                notes: notes
            )
        }

        guard !templateExercises.isEmpty else { return nil }

        return WorkoutTemplate(
            id: "tpl-ai-\(UUID().uuidString.prefix(8))",
            name: payload.name,
            description: "Built by AI Coach",
            exercises: templateExercises,
            estimatedDuration: payload.estimatedDurationMinutes ?? 45,
            category: .custom,
            isCustom: true
        )
    }

    /// Save the AI-built template via `TemplateService`. Returns the persisted
    /// template (or nil when no exercises mapped).
    @discardableResult
    func saveTemplate(from payload: WorkoutBuildPayload) -> WorkoutTemplate? {
        guard let template = buildTemplate(from: payload) else {
            errorMessage = "Couldn't save — none of the suggested exercises matched the catalog."
            return nil
        }
        TemplateService.shared.saveCustomTemplate(template)
        return template
    }

    /// Resolves the payload's exercises against `ExerciseDatabase`, dropping
    /// unknown ids. Used by the timed-circuit start path which sidesteps
    /// `WorkoutTemplate` (no sets/reps to project).
    func resolvedExercises(from payload: WorkoutBuildPayload) -> [Exercise] {
        payload.exercises.compactMap { ExerciseDatabase.byId[$0.exerciseId] }
    }

    /// Start the payload as a live workout on the provided `WorkoutLoggerViewModel`.
    /// Branches on `payload.kind`:
    /// - `.timedCircuit`: routes into `startTimedCircuit(...)` with the payload's
    ///   `durationMinutes` (defaulting to 10 when unspecified).
    /// - everything else (including `.amrap` / `.emom` for v1): falls back to
    ///   the existing template-based sets/reps flow.
    /// Returns `true` when the workout started successfully.
    @discardableResult
    func startWorkout(
        from payload: WorkoutBuildPayload,
        on session: WorkoutLoggerViewModel,
        userId: String
    ) -> Bool {
        switch payload.kind {
        case .timedCircuit:
            let resolved = resolvedExercises(from: payload)
            guard !resolved.isEmpty else {
                errorMessage = "Couldn't start — none of the suggested exercises matched the catalog."
                return false
            }
            let minutes = payload.durationMinutes ?? payload.estimatedDurationMinutes ?? 10
            session.startTimedCircuit(
                name: payload.name,
                userId: userId,
                exercises: resolved,
                durationMinutes: minutes
            )
            session.isPresented = true
            return true
        case .setsReps, .amrap, .emom:
            guard let template = buildTemplate(from: payload) else {
                errorMessage = "Couldn't start — none of the suggested exercises matched the catalog."
                return false
            }
            session.startFromTemplate(template, userId: userId)
            session.isPresented = true
            return true
        }
    }

    // MARK: - Private (streaming)

    private func appendText(_ chunk: String, to id: UUID) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].text += chunk
        // Persist on each delta so a crash mid-stream still keeps progress.
        // UserDefaults coalesces writes so this is cheap.
        persist()
    }

    private func attachWorkoutPayload(_ payload: WorkoutBuildPayload, to id: UUID) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].workoutPayload = payload
        persist()
    }

    private func finishStreaming(id: UUID) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        if messages[index].isStreaming {
            messages[index].isStreaming = false
            persist()
        }
    }

    // MARK: - Private (persistence)

    private func persist() {
        // Cap to last `historyCap` messages so the blob stays bounded.
        let capped = messages.suffix(Self.historyCap)
        let payload = Array(capped)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private static func loadPersisted(from defaults: UserDefaults) -> [AICoachMessage] {
        guard let data = defaults.data(forKey: storageKey) else { return [] }
        guard var decoded = try? JSONDecoder().decode([AICoachMessage].self, from: data) else {
            return []
        }
        // Defensive: never restore with a dangling streaming flag.
        for i in decoded.indices where decoded[i].isStreaming {
            decoded[i].isStreaming = false
        }
        return decoded
    }

    // MARK: - Private (formatting)

    private func formatWeight(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }
}
