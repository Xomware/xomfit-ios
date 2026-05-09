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

// MARK: - Service

/// Direct REST client for Anthropic's Messages API.
///
/// v1 scope: non-streaming text replies. Streaming via SSE (`stream: true`)
/// is a TODO — wire it through `URLSession.bytes(for:)` and parse
/// `content_block_delta` / `message_delta` events.
///
/// API docs: https://docs.claude.com/en/api/messages
final class AICoachService {
    // MARK: Public

    static let shared = AICoachService()

    /// Default model. Override per-request via the `model` argument.
    static let defaultModel = "claude-sonnet-4-6"
    static let defaultMaxTokens = 1024

    /// Base system prompt. Profile context is appended on top of this when present.
    static let baseSystemPrompt = """
    You are an expert lifting coach. Be terse. Output structured workout \
    suggestions when relevant. Reference the user's profile data provided.
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

    /// Builds the system prompt by prepending the user's fitness profile (if any).
    static func systemPrompt(profile: UserFitnessProfile) -> String {
        guard profile.isComplete else { return baseSystemPrompt }

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

        // No profile fields filled in despite completedAt — fall back to base.
        if lines.count == 1 { return baseSystemPrompt }

        return lines.joined(separator: "\n") + "\n\n" + baseSystemPrompt
    }

    // MARK: - Send (non-streaming)

    /// Sends the conversation to Anthropic and returns the assistant's text reply.
    /// - Parameters:
    ///   - messages: prior chat history, in order. User and assistant only — no system.
    ///   - profile: user fitness profile to seed the system prompt.
    ///   - apiKeyOverride: optional runtime key (Settings). Falls back to Config.
    ///   - model: model id; defaults to `defaultModel`.
    ///   - maxTokens: response cap; defaults to `defaultMaxTokens`.
    func sendMessage(
        messages: [AICoachMessage],
        profile: UserFitnessProfile = .current,
        apiKeyOverride: String? = nil,
        model: String = AICoachService.defaultModel,
        maxTokens: Int = AICoachService.defaultMaxTokens
    ) async throws -> String {
        guard let apiKey = Self.resolvedAPIKey(runtimeOverride: apiKeyOverride) else {
            throw AICoachServiceError.missingAPIKey
        }

        let body = AnthropicRequest(
            model: model,
            maxTokens: maxTokens,
            system: Self.systemPrompt(profile: profile),
            messages: messages.map { AnthropicMessage(role: $0.role.rawValue, content: $0.text) }
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw AICoachServiceError.decoding(error)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AICoachServiceError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AICoachServiceError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            let message = Self.extractErrorMessage(from: data)
            throw AICoachServiceError.http(status: http.statusCode, message: message)
        }

        do {
            let decoded = try JSONDecoder().decode(AnthropicResponse.self, from: data)
            return decoded.content
                .compactMap { $0.type == "text" ? $0.text : nil }
                .joined()
        } catch {
            throw AICoachServiceError.decoding(error)
        }
    }

    // MARK: - Helpers

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

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case system
        case messages
    }
}

private struct AnthropicResponse: Decodable {
    struct Block: Decodable {
        let type: String
        let text: String?
    }
    let content: [Block]
}
