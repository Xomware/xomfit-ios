import Foundation

// MARK: - Errors

enum AICoachServiceError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case http(status: Int, message: String?)
    case decoding(Error)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No Anthropic API key configured. Add one in Settings → Anthropic API Key."
        case .invalidResponse:
            return "The Anthropic API returned an unexpected response."
        case .http(let status, let message):
            if let message, !message.isEmpty {
                return "Anthropic error (\(status)): \(message)"
            }
            return "Anthropic error (HTTP \(status))."
        case .decoding(let error):
            return "Couldn't decode Anthropic response: \(error.localizedDescription)"
        case .transport(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - Streaming events

/// Higher-level events surfaced to the view model from a streaming SSE response.
/// We collapse Anthropic's lower-level event taxonomy into something the view
/// model can act on directly (append text, capture a tool-use payload, finish).
enum AICoachStreamEvent {
    /// Text delta for the assistant bubble. Append to the in-progress message.
    case textDelta(String)
    /// A `build_workout` tool call resolved to a parseable payload.
    /// Attach it to the assistant message so the chat can render the action card.
    case toolUse(WorkoutBuildPayload)
    /// Stream finished cleanly (`message_stop`).
    case done
}

// MARK: - Service

/// Direct REST client for Anthropic's Messages API.
///
/// - Streaming via SSE (`stream: true`) using `URLSession.bytes(for:)`.
///   `sendMessageStream` parses `content_block_delta` / `input_json_delta` /
///   `message_stop` and yields `AICoachStreamEvent`s the view model can apply
///   token-by-token.
/// - Tool use: declares a single `build_workout` tool. When the model calls it,
///   we accumulate `input_json_delta` chunks and emit a single `.toolUse` event
///   with the decoded `WorkoutBuildPayload` once `content_block_stop` arrives.
///
/// API docs: https://docs.claude.com/en/api/messages
final class AICoachService {
    // MARK: Public

    static let shared = AICoachService()

    /// Default model. Override per-request via the `model` argument.
    static let defaultModel = "claude-sonnet-4-6"
    static let defaultMaxTokens = 1024

    /// Base system prompt. Profile and exercise catalog context are appended
    /// on top of this when present.
    static let baseSystemPrompt = """
    You are an expert lifting coach. Be terse. Output structured workout \
    suggestions when relevant. Reference the user's profile data provided. \
    When the user asks for a workout, plan, or routine, call the \
    `build_workout` tool with concrete exercises so the app can render a \
    Save / Start card under your reply. Only use exerciseIds present in the \
    provided exercise catalog.
    """

    // MARK: Init

    private init(session: URLSession = .shared) {
        self.session = session
    }

    private let session: URLSession
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let anthropicVersion = "2023-06-01"

    // MARK: - Key resolution

    /// Resolves an API key from runtime override (Settings).
    /// Build-time `Config.anthropicAPIKey` is added by `ci_post_clone.sh` /
    /// the GHA `Generate Config.swift` step from the `ANTHROPIC_API_KEY` env;
    /// fall back to a key set in Settings (`@AppStorage`) when not present.
    /// Returns nil when neither is set.
    static func resolvedAPIKey(runtimeOverride: String?) -> String? {
        if let trimmed = runtimeOverride?.trimmingCharacters(in: .whitespacesAndNewlines),
           !trimmed.isEmpty {
            return trimmed
        }
        return nil
    }

    // MARK: - System prompt builder

    /// Builds the system prompt by prepending the user's fitness profile (if any)
    /// and appending a compressed exercise-catalog hint so the model can pick
    /// valid `exerciseId`s for `build_workout` calls.
    static func systemPrompt(profile: UserFitnessProfile) -> String {
        var prompt = baseSystemPrompt

        if profile.isComplete {
            var lines: [String] = ["User profile:"]
            if let goal = profile.primaryGoal {
                lines.append("- Primary goal: \(goal.title)")
            }
            if let experience = profile.experience {
                lines.append("- Experience: \(experience.title)")
            }
            if let workouts = profile.workoutsPerWeek {
                lines.append("- Workouts per week: \(workouts.title)")
            }
            if let split = profile.preferredSplit {
                lines.append("- Preferred split: \(split.title)")
            }
            if let length = profile.sessionLength {
                lines.append("- Session length: \(length.title)")
            }
            // Only prepend if we actually got fields out (defensive).
            if lines.count > 1 {
                prompt = lines.joined(separator: "\n") + "\n\n" + prompt
            }
        }

        let catalog = exerciseCatalogHint()
        if !catalog.isEmpty {
            prompt += "\n\nExercise catalog (id, name, equipment):\n" + catalog
        }

        return prompt
    }

    /// Compressed exercise catalog used to seed the system prompt so the model
    /// knows which `exerciseId`s are valid for `build_workout`.
    /// Truncated to ~3000 chars to keep token usage bounded.
    static func exerciseCatalogHint(maxChars: Int = 3000) -> String {
        let entries = ExerciseDatabase.all.map { ex in
            "\(ex.id)|\(ex.name)|\(ex.equipment.rawValue)"
        }
        let joined = entries.joined(separator: ", ")
        if joined.count <= maxChars { return joined }
        // Truncate at the last comma boundary so we don't slice an id mid-string.
        let cut = joined.prefix(maxChars)
        if let lastComma = cut.lastIndex(of: ",") {
            return String(cut[..<lastComma])
        }
        return String(cut)
    }

    // MARK: - Send (streaming)

    /// Sends the conversation to Anthropic with SSE streaming enabled and yields
    /// higher-level `AICoachStreamEvent`s. Throws on transport / HTTP / decode
    /// failures.
    ///
    /// - Parameters:
    ///   - messages: prior chat history, in order. User and assistant only — no system.
    ///   - profile: user fitness profile to seed the system prompt.
    ///   - apiKeyOverride: optional runtime key (Settings).
    ///   - model: model id; defaults to `defaultModel`.
    ///   - maxTokens: response cap; defaults to `defaultMaxTokens`.
    func sendMessageStream(
        messages: [AICoachMessage],
        profile: UserFitnessProfile = .current,
        apiKeyOverride: String? = nil,
        model: String = AICoachService.defaultModel,
        maxTokens: Int = AICoachService.defaultMaxTokens
    ) -> AsyncThrowingStream<AICoachStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task { [self] in
                do {
                    try await self.runStream(
                        messages: messages,
                        profile: profile,
                        apiKeyOverride: apiKeyOverride,
                        model: model,
                        maxTokens: maxTokens,
                        continuation: continuation
                    )
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func runStream(
        messages: [AICoachMessage],
        profile: UserFitnessProfile,
        apiKeyOverride: String?,
        model: String,
        maxTokens: Int,
        continuation: AsyncThrowingStream<AICoachStreamEvent, Error>.Continuation
    ) async throws {
        guard let apiKey = Self.resolvedAPIKey(runtimeOverride: apiKeyOverride) else {
            throw AICoachServiceError.missingAPIKey
        }

        let body = AnthropicRequest(
            model: model,
            maxTokens: maxTokens,
            system: Self.systemPrompt(profile: profile),
            messages: messages.map { AnthropicMessage(role: $0.role.rawValue, content: $0.text) },
            stream: true,
            tools: [Self.buildWorkoutTool]
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw AICoachServiceError.decoding(error)
        }

        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await session.bytes(for: request)
        } catch {
            throw AICoachServiceError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AICoachServiceError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            // On error responses Anthropic still returns JSON (not SSE).
            let data = try await Self.collect(bytes)
            let message = Self.extractErrorMessage(from: data)
            throw AICoachServiceError.http(status: http.statusCode, message: message)
        }

        // SSE parser state.
        // Anthropic content blocks are indexed; we track the in-progress
        // tool_use block (only one expected for build_workout) and append
        // input_json_delta partials until content_block_stop fires.
        var pendingToolJSON = ""
        var inToolBlock = false

        for try await line in bytes.lines {
            if Task.isCancelled { return }
            // SSE event format: lines starting with "data: " carry JSON payloads.
            // "event:" lines are informational — the JSON payload also contains a
            // `type` field, so we key off that and ignore the event line.
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst("data:".count)
                .trimmingCharacters(in: .whitespaces)
            if payload.isEmpty || payload == "[DONE]" { continue }

            guard let data = payload.data(using: .utf8) else { continue }

            // Decode the discriminator first; lots of event shapes share fields.
            let envelope: SSEEnvelope
            do {
                envelope = try JSONDecoder().decode(SSEEnvelope.self, from: data)
            } catch {
                // Skip lines we can't parse — keep streaming.
                continue
            }

            switch envelope.type {
            case "content_block_start":
                if let block = envelope.content_block {
                    if block.type == "tool_use" {
                        inToolBlock = true
                        pendingToolJSON = ""
                    } else {
                        inToolBlock = false
                    }
                }

            case "content_block_delta":
                guard let delta = envelope.delta else { continue }
                if delta.type == "text_delta", let text = delta.text {
                    continuation.yield(.textDelta(text))
                } else if delta.type == "input_json_delta", let partial = delta.partial_json {
                    pendingToolJSON += partial
                }

            case "content_block_stop":
                if inToolBlock {
                    inToolBlock = false
                    if let payload = Self.decodeWorkoutPayload(json: pendingToolJSON) {
                        continuation.yield(.toolUse(payload))
                    }
                    pendingToolJSON = ""
                }

            case "message_stop":
                continuation.yield(.done)
                return

            default:
                continue
            }
        }
    }

    // MARK: - Helpers

    private static func collect(_ bytes: URLSession.AsyncBytes) async throws -> Data {
        var data = Data()
        for try await byte in bytes {
            data.append(byte)
        }
        return data
    }

    private static func decodeWorkoutPayload(json: String) -> WorkoutBuildPayload? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(WorkoutBuildPayload.self, from: data)
    }

    private static func extractErrorMessage(from data: Data) -> String? {
        // Anthropic error shape: { "type": "error", "error": { "type": ..., "message": ... } }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            return message
        }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - Tool definition

extension AICoachService {
    /// `build_workout` tool. The model calls this when the user asks for a
    /// workout, plan, or routine. Returned `exerciseId`s must come from the
    /// catalog injected into the system prompt.
    static let buildWorkoutTool: AnthropicTool = AnthropicTool(
        name: "build_workout",
        description: "Create a workout plan with exercises and target sets/reps/weight. Return when the user asks for a workout, plan, or routine.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "name": .object(["type": .string("string")]),
                "estimatedDurationMinutes": .object(["type": .string("integer")]),
                "exercises": .object([
                    "type": .string("array"),
                    "items": .object([
                        "type": .string("object"),
                        "properties": .object([
                            "exerciseId": .object([
                                "type": .string("string"),
                                "description": .string("id from ExerciseDatabase")
                            ]),
                            "sets": .object(["type": .string("integer")]),
                            "targetReps": .object(["type": .string("integer")]),
                            "targetWeight": .object(["type": .string("number")])
                        ]),
                        "required": .array([
                            .string("exerciseId"),
                            .string("sets"),
                            .string("targetReps")
                        ])
                    ])
                ])
            ]),
            "required": .array([
                .string("name"),
                .string("exercises")
            ])
        ])
    )
}

// MARK: - Wire types

private struct AnthropicMessage: Encodable {
    let role: String
    let content: String
}

private struct AnthropicRequest: Encodable {
    let model: String
    let maxTokens: Int
    let system: String
    let messages: [AnthropicMessage]
    let stream: Bool
    let tools: [AnthropicTool]?

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case system
        case messages
        case stream
        case tools
    }
}

/// Tool definition payload. Encoded as `{ name, description, input_schema }`.
struct AnthropicTool: Encodable {
    let name: String
    let description: String
    let inputSchema: JSONValue

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case inputSchema = "input_schema"
    }
}

/// Minimal JSON value type so we can encode the tool's `input_schema` declaratively
/// without leaking `Any` into the request body.
enum JSONValue: Encodable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .number(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .array(let v): try container.encode(v)
        case .object(let v): try container.encode(v)
        case .null: try container.encodeNil()
        }
    }
}

// MARK: - SSE event decoding

private struct SSEEnvelope: Decodable {
    let type: String
    let index: Int?
    let content_block: ContentBlock?
    let delta: Delta?

    struct ContentBlock: Decodable {
        let type: String
        let id: String?
        let name: String?
    }

    struct Delta: Decodable {
        let type: String?
        let text: String?
        let partial_json: String?
    }
}
