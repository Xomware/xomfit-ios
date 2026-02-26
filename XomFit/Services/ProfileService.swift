import Foundation
import Supabase

// MARK: - UserProfile (Supabase DB model)
struct UserProfile: Codable {
    var id: String
    var username: String
    var displayName: String
    var bio: String
    var avatarURL: String?
    var isPrivate: Bool
    var totalWorkouts: Int
    var totalVolume: Double
    var totalPRs: Int
    var currentStreak: Int
    var longestStreak: Int
    var favoriteExercise: String?
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case bio
        case avatarURL = "avatar_url"
        case isPrivate = "is_private"
        case totalWorkouts = "total_workouts"
        case totalVolume = "total_volume"
        case totalPRs = "total_prs"
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case favoriteExercise = "favorite_exercise"
        case createdAt = "created_at"
    }
}

// MARK: - Partial update payload (nil fields are omitted — no accidental overwrites)
struct ProfileUpdatePayload: Encodable {
    var displayName: String?
    var username: String?
    var bio: String?
    var avatarURL: String?
    var isPrivate: Bool?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case username
        case bio
        case avatarURL = "avatar_url"
        case isPrivate = "is_private"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let v = displayName  { try container.encode(v, forKey: .displayName) }
        if let v = username     { try container.encode(v, forKey: .username) }
        if let v = bio          { try container.encode(v, forKey: .bio) }
        if let v = avatarURL    { try container.encode(v, forKey: .avatarURL) }
        if let v = isPrivate    { try container.encode(v, forKey: .isPrivate) }
    }
}

// MARK: - ProfileService
class ProfileService {
    static let shared = ProfileService()
    private let avatarsBucket = "avatars"

    // MARK: Fetch

    func fetchProfile(userId: String) async throws -> UserProfile? {
        let profiles: [UserProfile] = try await supabase
            .from("profiles")
            .select()
            .eq("id", value: userId)
            .execute()
            .value
        return profiles.first
    }

    // MARK: Create

    func createProfile(_ profile: UserProfile) async throws -> UserProfile {
        let created: UserProfile = try await supabase
            .from("profiles")
            .insert(profile)
            .select()
            .single()
            .execute()
            .value
        return created
    }

    // MARK: Update

    func updateProfile(userId: String, payload: ProfileUpdatePayload) async throws -> UserProfile {
        let updated: UserProfile = try await supabase
            .from("profiles")
            .update(payload)
            .eq("id", value: userId)
            .select()
            .single()
            .execute()
            .value
        return updated
    }

    // MARK: Avatar Upload

    /// Uploads JPEG image data to Supabase Storage and returns the public URL.
    func uploadAvatar(userId: String, imageData: Data) async throws -> String {
        let path = "\(userId)/avatar.jpg"

        try await supabase.storage
            .from(avatarsBucket)
            .upload(
                path,
                data: imageData,
                options: FileOptions(contentType: "image/jpeg", upsert: true)
            )

        let publicURL = supabase.storage
            .from(avatarsBucket)
            .getPublicURL(path: path)

        // Append cache-busting timestamp so the app reloads the new image
        return "\(publicURL.absoluteString)?t=\(Int(Date().timeIntervalSince1970))"
    }
}
