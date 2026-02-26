import Foundation
import SwiftUI

@MainActor
class ProfileViewModel: ObservableObject {

    // MARK: - Published State
    @Published var user: User = .mock
    @Published var recentPRs: [PersonalRecord] = PersonalRecord.mockPRs
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    /// True when the current user has no Supabase profile yet → show setup flow
    @Published var showSetupFlow = false

    private let profileService = ProfileService.shared

    // Convenience pass-through
    var workoutCount: Int { user.stats.totalWorkouts }

    // MARK: - Load Profile

    /// Fetch profile from Supabase. Shows setup flow if none exists.
    func loadProfile(userId: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            if let profile = try await profileService.fetchProfile(userId: userId) {
                applyProfile(profile)
                showSetupFlow = false
            } else {
                // No row in `profiles` yet — ask user to set up their profile
                showSetupFlow = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Create Profile (Setup Flow)

    func createProfile(userId: String, displayName: String, username: String, bio: String) async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let newProfile = UserProfile(
            id: userId,
            username: username.trimmingCharacters(in: .whitespaces),
            displayName: displayName.trimmingCharacters(in: .whitespaces),
            bio: bio,
            avatarURL: nil,
            isPrivate: false,
            totalWorkouts: 0,
            totalVolume: 0,
            totalPRs: 0,
            currentStreak: 0,
            longestStreak: 0,
            favoriteExercise: nil,
            createdAt: Date()
        )

        do {
            let created = try await profileService.createProfile(newProfile)
            applyProfile(created)
            showSetupFlow = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Update Profile

    func updateProfile(displayName: String, username: String, bio: String, isPrivate: Bool) async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let payload = ProfileUpdatePayload(
            displayName: displayName.isEmpty ? nil : displayName,
            username: username.isEmpty ? nil : username,
            bio: bio,
            avatarURL: nil,
            isPrivate: isPrivate
        )

        do {
            let updated = try await profileService.updateProfile(userId: user.id, payload: payload)
            applyProfile(updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Upload Avatar

    /// Compresses the image and uploads it to Supabase Storage, then persists the URL.
    func uploadAvatar(imageData: Data) async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        // Compress to JPEG at 80% quality to keep uploads lean
        let finalData: Data
        if let img = UIImage(data: imageData),
           let jpeg = img.jpegData(compressionQuality: 0.8) {
            finalData = jpeg
        } else {
            finalData = imageData
        }

        do {
            let avatarURL = try await profileService.uploadAvatar(userId: user.id, imageData: finalData)
            let payload = ProfileUpdatePayload(avatarURL: avatarURL)
            let updated = try await profileService.updateProfile(userId: user.id, payload: payload)
            applyProfile(updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Refresh (legacy / pull-to-refresh)

    func refresh(userId: String) async {
        await loadProfile(userId: userId)
    }

    // MARK: - Private Helpers

    private func applyProfile(_ profile: UserProfile) {
        user = User(
            id: profile.id,
            username: profile.username,
            displayName: profile.displayName,
            avatarURL: profile.avatarURL,
            bio: profile.bio,
            stats: User.UserStats(
                totalWorkouts: profile.totalWorkouts,
                totalVolume: profile.totalVolume,
                totalPRs: profile.totalPRs,
                currentStreak: profile.currentStreak,
                longestStreak: profile.longestStreak,
                favoriteExercise: profile.favoriteExercise
            ),
            isPrivate: profile.isPrivate,
            createdAt: profile.createdAt
        )
    }
}
