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

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case bio
        case avatarURL = "avatar_url"
        case isPrivate = "is_private"
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
        isPrivate: Bool
    ) async throws {
        struct UpsertPayload: Encodable {
            let id: String
            let username: String
            let display_name: String
            let bio: String
            let avatar_url: String?
            let is_private: Bool
        }

        let payload = UpsertPayload(
            id: userId,
            username: username,
            display_name: displayName,
            bio: bio,
            avatar_url: avatarURL,
            is_private: isPrivate
        )

        try await supabase
            .from("profiles")
            .upsert(payload)
            .execute()
    }
}
