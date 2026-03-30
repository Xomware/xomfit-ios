import Foundation

// MARK: - Profile Tab

enum ProfileTab: String, CaseIterable, Identifiable {
    case feed
    case calendar
    case stats
    case friends

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .feed: return "list.bullet"
        case .calendar: return "calendar"
        case .stats: return "chart.bar"
        case .friends: return "person.2"
        }
    }

    var label: String {
        switch self {
        case .feed: return "Feed"
        case .calendar: return "Calendar"
        case .stats: return "Stats"
        case .friends: return "Friends"
        }
    }
}

// MARK: - Friendship Status (profile context)

enum ProfileFriendshipStatus {
    case none
    case pending
    case friends
}

// MARK: - ProfileViewModel

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

    // MARK: - Tab state
    var selectedTab: ProfileTab = .feed

    // MARK: - Feed
    var feedItems: [SocialFeedItem] = []

    // MARK: - Calendar
    var workoutDays: [Date: Int] = [:]

    // MARK: - Friends
    var friends: [FriendRow] = []
    var friendProfiles: [String: ProfileRow] = [:]

    // MARK: - Profile context
    var isOwnProfile: Bool = true
    var friendshipStatus: ProfileFriendshipStatus = .none
    var friendCount: Int = 0
    var feedItemCount: Int = 0

    // MARK: - State
    var isLoading: Bool = false
    var isSaving: Bool = false
    var errorMessage: String? = nil

    // MARK: - Computed

    var initials: String {
        let name = displayName.isEmpty ? username : displayName
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    var formattedVolume: String {
        if totalVolume >= 1_000_000 {
            return String(format: "%.1fM", totalVolume / 1_000_000)
        } else if totalVolume >= 1000 {
            return String(format: "%.1fk", totalVolume / 1000)
        }
        return "\(Int(totalVolume))"
    }

    // MARK: - Load All

    func loadAll(userId: String, currentUserId: String) async {
        isLoading = true
        errorMessage = nil
        isOwnProfile = userId == currentUserId

        // Load profile first (needed for privacy check)
        do {
            let profile = try await ProfileService.shared.fetchProfile(userId: userId)
            displayName = profile.displayName
            username = profile.username
            bio = profile.bio
            avatarURL = profile.avatarURL
            isPrivate = profile.isPrivate
        } catch {
            // Profile row may not exist on first login
        }

        // For other users, check friendship status
        if !isOwnProfile {
            await loadFriendshipStatus(currentUserId: currentUserId, targetUserId: userId)

            // If private and not friends, stop here
            if isPrivate && friendshipStatus != .friends {
                isLoading = false
                return
            }
        }

        // Load remaining data in parallel
        async let workoutsTask = WorkoutService.shared.fetchWorkouts(userId: userId)
        async let prsTask = loadPRs(userId: userId)
        async let feedTask = loadFeed(userId: userId)
        async let friendsTask = loadFriends(userId: userId)

        let workouts = await workoutsTask
        totalWorkouts = workouts.count
        totalVolume = workouts.reduce(0) { $0 + $1.totalVolume }
        loadCalendarData(workouts: workouts)

        await prsTask
        await feedTask
        await friendsTask

        isLoading = false
    }

    // MARK: - Load Profile (legacy, kept for compatibility)

    func loadProfile(userId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let profile = try await ProfileService.shared.fetchProfile(userId: userId)
            displayName = profile.displayName
            username = profile.username
            bio = profile.bio
            avatarURL = profile.avatarURL
            isPrivate = profile.isPrivate
        } catch {
            // Profile row may not exist on first login
        }

        let workouts = await WorkoutService.shared.fetchWorkouts(userId: userId)
        totalWorkouts = workouts.count
        totalVolume = workouts.reduce(0) { $0 + $1.totalVolume }

        do {
            let prs = try await PRService.shared.fetchPRs(userId: userId)
            totalPRs = prs.count
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

    // MARK: - Friend Request

    func sendFriendRequest(fromUserId: String, toUserId: String) async {
        do {
            try await FriendsService.shared.sendFriendRequest(fromUserId: fromUserId, toUserId: toUserId)
            friendshipStatus = .pending
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Private Helpers

    private func loadPRs(userId: String) async {
        do {
            let prs = try await PRService.shared.fetchPRs(userId: userId)
            totalPRs = prs.count
            recentPRs = Array(prs.prefix(5))
        } catch {
            // Non-fatal
        }
    }

    private func loadFeed(userId: String) async {
        do {
            let items = try await FeedService.shared.fetchUserFeed(userId: userId)
            feedItems = items
            feedItemCount = items.count
        } catch {
            // Non-fatal
        }
    }

    private func loadFriends(userId: String) async {
        do {
            let allFriends = try await FriendsService.shared.fetchFriends(userId: userId)
            let mutualFriends = allFriends.filter { $0.status == "mutual" }
            friends = mutualFriends
            friendCount = mutualFriends.count

            // Batch-load friend profiles for display names
            let friendIds = mutualFriends.map { $0.friendId }
            for friendId in friendIds {
                if friendProfiles[friendId] == nil {
                    if let profile = try? await ProfileService.shared.fetchProfile(userId: friendId) {
                        friendProfiles[friendId] = profile
                    }
                }
            }
        } catch {
            // Non-fatal
        }
    }

    private func loadFriendshipStatus(currentUserId: String, targetUserId: String) async {
        do {
            // Check if current user sent a request to the target
            let sentFriends = try await FriendsService.shared.fetchFriends(userId: currentUserId)
            if let match = sentFriends.first(where: { $0.friendId == targetUserId }) {
                friendshipStatus = match.status == "mutual" ? .friends : .pending
                return
            }

            // Check if target sent a request to current user
            let receivedFriends = try await FriendsService.shared.fetchFriends(userId: targetUserId)
            if let match = receivedFriends.first(where: { $0.friendId == currentUserId }) {
                friendshipStatus = match.status == "mutual" ? .friends : .pending
                return
            }

            friendshipStatus = .none
        } catch {
            friendshipStatus = .none
        }
    }

    func loadCalendarData(workouts: [Workout]) {
        let calendar = Calendar.current
        var days: [Date: Int] = [:]
        for workout in workouts {
            let day = calendar.startOfDay(for: workout.startTime)
            days[day, default: 0] += 1
        }
        workoutDays = days
    }
}
