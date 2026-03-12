import Foundation

@MainActor
@Observable
final class ProfileViewModel {
    // MARK: - Profile fields
    var displayName: String = ""
    var username: String = ""
    var bio: String = ""
    var avatarURL: String? = nil
    var isPrivate: Bool = false

    // MARK: - Edit buffer (populated when the edit sheet opens)
    var editDisplayName: String = ""
    var editBio: String = ""
    var editIsPrivate: Bool = false

    // MARK: - Stats
    var totalWorkouts: Int = 0
    var totalVolume: Double = 0
    var totalPRs: Int = 0
    var recentPRs: [PersonalRecord] = []

    // MARK: - State
    var isLoading: Bool = false
    var isSaving: Bool = false
    var errorMessage: String? = nil

    // MARK: - Load

    func loadProfile(userId: String) async {
        isLoading = true
        errorMessage = nil

        // Fetch profile from Supabase (non-fatal if profile row doesn't exist yet)
        do {
            let profile = try await ProfileService.shared.fetchProfile(userId: userId)
            displayName = profile.displayName
            username = profile.username
            bio = profile.bio
            avatarURL = profile.avatarURL
            isPrivate = profile.isPrivate
        } catch {
            // Profile row may not exist on first login — use email initials fallback
            // Don't surface this as an error to the user
        }

        // Workout stats from local WorkoutService
        let workouts = WorkoutService.shared.fetchWorkouts(userId: userId)
        totalWorkouts = workouts.count
        totalVolume = workouts.reduce(0) { $0 + $1.totalVolume }

        // PRs from PRService
        do {
            let prs = try await PRService.shared.fetchPRs(userId: userId)
            totalPRs = prs.count
            // Show the 5 most recent PRs on the profile header
            recentPRs = Array(prs.prefix(5))
        } catch {
            // Non-fatal
        }

        isLoading = false
    }

    // MARK: - Update

    func updateProfile(userId: String) async {
        isSaving = true
        errorMessage = nil
        do {
            try await ProfileService.shared.upsertProfile(
                userId: userId,
                username: username.isEmpty ? userId : username,
                displayName: editDisplayName.isEmpty ? displayName : editDisplayName,
                bio: editBio,
                avatarURL: avatarURL,
                isPrivate: editIsPrivate
            )
            // Commit edits to live fields
            displayName = editDisplayName.isEmpty ? displayName : editDisplayName
            bio = editBio
            isPrivate = editIsPrivate
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    // MARK: - Edit sheet helpers

    func beginEditing() {
        editDisplayName = displayName
        editBio = bio
        editIsPrivate = isPrivate
    }
}
