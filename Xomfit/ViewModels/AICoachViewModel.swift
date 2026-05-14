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

    /// Accumulated input tokens across this conversation. Reset on clear (#371).
    var totalInputTokens: Int = 0
    /// Accumulated output tokens across this conversation. Reset on clear (#371).
    var totalOutputTokens: Int = 0
    /// Cost meter uses the current model's pricing when computing the display
    /// string. Persisted across sends in the same convo via the running totals.
    var lastModel: AICoachModel = .sonnet45

    /// Suggested prompts shown when the conversation is empty (#371).
    /// Horizontally scrollable in the view — keep these short.
    let suggestionChips: [String] = [
        "Build me today's workout",
        "Plan my week",
        "Critique my last workout",
        "What should I focus on this week?",
        "Build me a 10-minute ab circuit",
        "Suggest a 4-day split"
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

    /// True when the last turn is a `[user, assistant (done)]` pair and we
    /// aren't currently streaming. Drives the regenerate button visibility (#371).
    var canRegenerateLast: Bool {
        guard !isSending else { return false }
        guard
            let lastAssistantIndex = messages.lastIndex(where: { $0.role == .assistant }),
            !messages[lastAssistantIndex].isStreaming,
            lastAssistantIndex >= 1,
            messages[lastAssistantIndex - 1].role == .user
        else { return false }
        return true
    }

    /// The id of the last assistant message in the transcript, or nil when none
    /// exists. Used by the view to attach the regenerate action to the right bubble.
    var lastAssistantMessageId: UUID? {
        messages.last(where: { $0.role == .assistant })?.id
    }

    // MARK: - Actions

    /// Append a chip's text to the draft and immediately send it.
    func sendSuggestion(
        _ text: String,
        apiKeyOverride: String?,
        model: AICoachModel = .sonnet45,
        userId: String? = nil
    ) async {
        draft = text
        await send(apiKeyOverride: apiKeyOverride, model: model, userId: userId)
    }

    /// Send the current draft. No-op when nothing to send.
    /// Streams the response and updates the placeholder bubble in place.
    func send(
        apiKeyOverride: String?,
        model: AICoachModel = .sonnet45,
        userId: String? = nil
    ) async {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }

        errorMessage = nil
        let userMessage = AICoachMessage(role: .user, text: trimmed)
        messages.append(userMessage)
        draft = ""
        isSending = true
        lastModel = model

        // Insert a placeholder assistant bubble that we'll stream into.
        let placeholderId = UUID()
        messages.append(
            AICoachMessage(id: placeholderId, role: .assistant, text: "", isStreaming: true)
        )
        persist()

        do {
            // Send everything except the placeholder (last entry).
            let history = Array(messages.dropLast())
            let workoutContext = buildWorkoutContext(userId: userId)
            let stream = service.sendMessageStream(
                messages: history,
                workoutContext: workoutContext,
                apiKeyOverride: apiKeyOverride,
                model: model.rawValue
            )

            for try await event in stream {
                switch event {
                case .textDelta(let chunk):
                    appendText(chunk, to: placeholderId)
                case .toolUse(let payload):
                    attachWorkoutPayload(payload, to: placeholderId)
                case .usage(let input, let output):
                    totalInputTokens += input
                    totalOutputTokens += output
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

    /// Drop the last assistant turn and re-send the user message that preceded
    /// it, streaming a fresh reply (#371). No-op while streaming.
    ///
    /// Pre-condition: the conversation ends with `[user, assistant]`. We use
    /// `lastIndex(where: .assistant)` so an intermediate user message after the
    /// last assistant (rare race) doesn't get clobbered.
    func regenerateLast(
        apiKeyOverride: String?,
        model: AICoachModel = .sonnet45,
        userId: String? = nil
    ) async {
        guard !isSending else { return }
        guard
            let lastAssistantIndex = messages.lastIndex(where: { $0.role == .assistant }),
            lastAssistantIndex >= 1,
            messages[lastAssistantIndex - 1].role == .user
        else { return }

        let userText = messages[lastAssistantIndex - 1].text
        // Drop the user → assistant pair; the user message gets re-issued via
        // the normal send path so streaming, persistence, and error handling
        // all stay uniform.
        messages.removeSubrange((lastAssistantIndex - 1)...lastAssistantIndex)
        persist()

        draft = userText
        await send(apiKeyOverride: apiKeyOverride, model: model, userId: userId)
    }

    // MARK: - Workout context (#371)

    /// Builds a compressed summary of recent workouts and PRs to seed the
    /// system prompt. Cached-only — never hits the network. Returns nil when
    /// there's nothing useful to surface.
    ///
    /// Format (truncated at ~3000 chars):
    /// ```
    /// Recent workout history (most recent first):
    /// - 2026-05-08 Push Day · 12,500 lb · Bench Press best 225x4 · Overhead Press best 135x6
    /// ...
    ///
    /// Lifetime PRs (top 5 by est. 1RM):
    /// - Deadlift 405x1 (Epley 1RM ~405)
    /// ...
    /// ```
    func buildWorkoutContext(userId: String?, maxChars: Int = 3000) -> String? {
        guard let userId, !userId.isEmpty else { return nil }
        let workouts = WorkoutService.shared.fetchWorkoutsFromCache(userId: userId)
        guard !workouts.isEmpty else { return nil }

        var sections: [String] = []

        // --- Last 10 workouts
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]
        let recent = Array(workouts.prefix(10))
        var lines: [String] = ["Recent workout history (most recent first):"]
        for w in recent {
            let date = dateFormatter.string(from: w.startTime)
            let volume = Self.formatVolume(w.totalVolume)
            // Top 2 exercises by volume, with best set summary.
            let topExercises = w.exercises
                .sorted { $0.totalVolume > $1.totalVolume }
                .prefix(2)
            let exerciseLines: [String] = topExercises.compactMap { we in
                guard let best = we.bestSet else { return nil }
                return "\(we.exercise.name) best \(Self.formatWeightInt(best.weight))x\(best.reps)"
            }
            var line = "- \(date) \(w.name) · \(volume) lb"
            if !exerciseLines.isEmpty {
                line += " · " + exerciseLines.joined(separator: " · ")
            }
            lines.append(line)
        }
        sections.append(lines.joined(separator: "\n"))

        // --- Top 5 PRs computed from cached workouts (PRService has no cache;
        // we treat the best (weight, reps) per exercise across all cached
        // workouts as the lifetime PR for prompt-priming purposes).
        var bestByExercise: [String: (name: String, weight: Double, reps: Int, oneRM: Double)] = [:]
        for w in workouts {
            for we in w.exercises {
                for set in we.sets {
                    let oneRM = set.estimated1RM
                    if let existing = bestByExercise[we.exercise.id] {
                        if oneRM > existing.oneRM {
                            bestByExercise[we.exercise.id] = (we.exercise.name, set.weight, set.reps, oneRM)
                        }
                    } else if set.weight > 0 && set.reps > 0 {
                        bestByExercise[we.exercise.id] = (we.exercise.name, set.weight, set.reps, oneRM)
                    }
                }
            }
        }
        let topPRs = bestByExercise.values
            .sorted { $0.oneRM > $1.oneRM }
            .prefix(5)
        if !topPRs.isEmpty {
            var prLines: [String] = ["Lifetime PRs (top 5 by est. 1RM):"]
            for pr in topPRs {
                let oneRM = Self.formatWeightInt(pr.oneRM)
                prLines.append("- \(pr.name) \(Self.formatWeightInt(pr.weight))x\(pr.reps) (Epley 1RM ~\(oneRM))")
            }
            sections.append(prLines.joined(separator: "\n"))
        }

        var combined = sections.joined(separator: "\n\n")
        if combined.count > maxChars {
            // Truncate at the last newline boundary that fits so we don't
            // slice a row mid-line.
            let cut = combined.prefix(maxChars)
            if let lastNewline = cut.lastIndex(of: "\n") {
                combined = String(cut[..<lastNewline]) + "\n…"
            } else {
                combined = String(cut)
            }
        }
        return combined
    }

    // MARK: - Cost meter (#371)

    /// Estimated USD cost across the running input + output tokens. Uses the
    /// last model's pricing; if mid-convo the user switches models this is a
    /// rough mix but still informative.
    var estimatedCostUSD: Double {
        let pricing = lastModel.pricing
        let input = Double(totalInputTokens) / 1_000_000 * pricing.inputPerMillion
        let output = Double(totalOutputTokens) / 1_000_000 * pricing.outputPerMillion
        return input + output
    }

    /// "≈ $0.03 spent on this convo" style footer, or nil when we don't yet
    /// have token usage data.
    var costMeterText: String? {
        guard totalInputTokens > 0 || totalOutputTokens > 0 else { return nil }
        let cost = estimatedCostUSD
        let formatted: String
        if cost < 0.01 {
            formatted = String(format: "$%.4f", cost)
        } else {
            formatted = String(format: "$%.2f", cost)
        }
        return "≈ \(formatted) spent on this convo"
    }

    /// Compact integer weight: "225" not "225.0".
    private static func formatWeightInt(_ value: Double) -> String {
        String(Int(value.rounded()))
    }

    /// Volume formatter: "12.5k" for >=1000, integer otherwise.
    private static func formatVolume(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.1fk", value / 1000)
        }
        return String(Int(value))
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
        totalInputTokens = 0
        totalOutputTokens = 0
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
