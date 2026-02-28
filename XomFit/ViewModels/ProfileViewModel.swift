import Foundation
import SwiftUI

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var user: User = .mock
    @Published var recentPRs: [PersonalRecord] = PersonalRecord.mockPRs
    @Published var workoutCount: Int = 247
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Edit mode state
    @Published var isEditingProfile = false
    @Published var editingDisplayName = ""
    @Published var editingBio = ""
    @Published var editingIsPrivate = false
    @Published var selectedAvatarImage: UIImage?
    @Published var showImagePicker = false
    
    private let profileService = UserProfileService()
    
    func initializeEditMode() {
        editingDisplayName = user.displayName
        editingBio = user.bio
        editingIsPrivate = user.isPrivate
    }
    
    func saveProfile(avatarImageData: Data? = nil) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            var avatarURL = user.avatarURL
            
            // Upload avatar if new image selected
            if let imageData = avatarImageData {
                avatarURL = try await profileService.uploadAvatar(
                    imageData: imageData,
                    userId: user.id
                )
            }
            
            // Update profile
            let updatedUser = try await profileService.updateUserProfile(
                userId: user.id,
                displayName: editingDisplayName,
                bio: editingBio,
                avatarURL: avatarURL,
                isPrivate: editingIsPrivate
            )
            
            // Update local state
            user = updatedUser
            isEditingProfile = false
            selectedAvatarImage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func cancelEdit() {
        isEditingProfile = false
        selectedAvatarImage = nil
        initializeEditMode()
    }
    
    func refresh() {
        isLoading = true
        // Mock refresh - in production, fetch from backend
        isLoading = false
    }
}
