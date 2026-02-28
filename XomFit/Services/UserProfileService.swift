import Foundation
import Supabase

@MainActor
class UserProfileService: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    /// Upload avatar image to Supabase Storage and return the public URL
    func uploadAvatar(imageData: Data, userId: String) async throws -> String {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let fileName = "avatars/\(userId)-\(UUID().uuidString).jpg"
            
            // Upload to Supabase Storage
            let response = try await supabase.storage
                .from("avatars")
                .upload(fileName, data: imageData)
            
            // Get public URL
            let publicURL = supabase.storage
                .from("avatars")
                .getPublicURL(path: fileName)
            
            return publicURL.absoluteString
        } catch {
            errorMessage = "Failed to upload avatar: \(error.localizedDescription)"
            throw error
        }
    }
    
    /// Update user profile in the database
    func updateUserProfile(
        userId: String,
        displayName: String,
        bio: String,
        avatarURL: String?,
        isPrivate: Bool
    ) async throws -> User {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            // Update auth user metadata
            var metadata: [String: Any] = [
                "display_name": displayName,
                "bio": bio,
                "is_private": isPrivate
            ]
            
            if let avatarURL = avatarURL {
                metadata["avatar_url"] = avatarURL
            }
            
            try await supabase.auth.update(user: UserAttributes(data: metadata))
            
            // Return updated user (in a real app, fetch from database)
            return User(
                id: userId,
                username: "", // Would be fetched from auth
                displayName: displayName,
                avatarURL: avatarURL,
                bio: bio,
                stats: User.UserStats(
                    totalWorkouts: 0,
                    totalVolume: 0,
                    totalPRs: 0,
                    currentStreak: 0,
                    longestStreak: 0,
                    favoriteExercise: nil
                ),
                isPrivate: isPrivate,
                createdAt: Date()
            )
        } catch {
            errorMessage = "Failed to update profile: \(error.localizedDescription)"
            throw error
        }
    }
    
    /// Delete user's avatar from storage
    func deleteAvatar(avatarPath: String) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            try await supabase.storage
                .from("avatars")
                .remove([avatarPath])
        } catch {
            errorMessage = "Failed to delete avatar: \(error.localizedDescription)"
            throw error
        }
    }
}
