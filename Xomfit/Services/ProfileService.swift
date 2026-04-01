import Foundation
import Supabase

// MARK: - DB Row Types

struct ProfileRow: Codable {
    let id: String
    var username: String
    var displayName: String
    var bio: String
    var avatarURL: String?
    var isPrivate: Bool
    var trainingGoals: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case bio
        case avatarURL = "avatar_url"
        case isPrivate = "is_private"
        case trainingGoals = "training_goals"
    }
}

// MARK: - ProfileService

@MainActor
final class ProfileService {
    static let shared = ProfileService()

    private init() {}

    func fetchProfile(userId: String) async throws -> ProfileRow {
        let response: ProfileRow = try await supabase
            .from("profiles")
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
            .value
        return response
    }

    func upsertProfile(
        userId: String,
        username: String,
        displayName: String,
        bio: String,
        avatarURL: String?,
        isPrivate: Bool,
        trainingGoals: [String]? = nil
    ) async throws {
        struct UpsertPayload: Encodable {
            let id: String
            let username: String
            let display_name: String
            let bio: String
            let avatar_url: String?
            let is_private: Bool
            let training_goals: [String]?
        }

        let payload = UpsertPayload(
            id: userId,
            username: username,
            display_name: displayName,
            bio: bio,
            avatar_url: avatarURL,
            is_private: isPrivate,
            training_goals: trainingGoals
        )

        try await supabase
            .from("profiles")
            .upsert(payload)
            .execute()
    }

    func updateTrainingGoals(userId: String, goals: [TrainingGoal]) async throws {
        let goalStrings = goals.map(\.rawValue)
        try await supabase
            .from("profiles")
            .update(["training_goals": goalStrings])
            .eq("id", value: userId)
            .execute()
    }
}
