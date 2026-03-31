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
    var editUsername: String = ""
    var editDisplayName: String = ""
    var editBio: String = ""
    var editIsPrivate: Bool = false

    // MARK: - Stats
    var totalWorkouts: Int = 0
    var totalVolume: Double = 0
    var totalPRs: Int = 0
    var recentPRs: [PersonalRecord] = []

    // MARK: - Muscle Group Heatmap
    var muscleGroupSetsThisWeek: [String: Int] = [:]
    var muscleGroupSetsThisMonth: [String: Int] = [:]

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
        computeMuscleGroupSets(workouts: workouts)

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
        computeMuscleGroupSets(workouts: workouts)

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
            let savedUsername = editUsername.isEmpty ? (username.isEmpty ? userId : username) : editUsername
            try await ProfileService.shared.upsertProfile(
                userId: userId,
                username: savedUsername,
                displayName: editDisplayName.isEmpty ? displayName : editDisplayName,
                bio: editBio,
                avatarURL: avatarURL,
                isPrivate: editIsPrivate
            )
            username = savedUsername
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
        editUsername = username
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
            friends = allFriends
            friendCount = allFriends.count

            // Batch-load friend profiles for display names
            let friendIds = allFriends.map { $0.requesterId == userId ? $0.addresseeId : $0.requesterId }
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
            let allFriendships = try await FriendsService.shared.fetchFriends(userId: currentUserId)
            let match = allFriendships.first(where: {
                ($0.requesterId == currentUserId && $0.addresseeId == targetUserId) ||
                ($0.requesterId == targetUserId && $0.addresseeId == currentUserId)
            })
            if let match {
                friendshipStatus = match.status == "accepted" ? .friends : .pending
                return
            }

            friendshipStatus = .none
        } catch {
            friendshipStatus = .none
        }
    }

    func computeMuscleGroupSets(workouts: [Workout]) {
        let calendar = Calendar.current
        let now = Date()
        let oneWeekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
        let oneMonthAgo = calendar.date(byAdding: .month, value: -1, to: now) ?? now

        var weekSets: [String: Int] = [:]
        var monthSets: [String: Int] = [:]

        for workout in workouts {
            let isThisWeek = workout.startTime >= oneWeekAgo
            let isThisMonth = workout.startTime >= oneMonthAgo

            guard isThisMonth else { continue }

            for exercise in workout.exercises {
                let setCount = exercise.sets.count
                for muscleGroup in exercise.exercise.muscleGroups {
                    let name = muscleGroup.displayName
                    if isThisWeek {
                        weekSets[name, default: 0] += setCount
                    }
                    monthSets[name, default: 0] += setCount
                }
            }
        }

        muscleGroupSetsThisWeek = weekSets
        muscleGroupSetsThisMonth = monthSets
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
