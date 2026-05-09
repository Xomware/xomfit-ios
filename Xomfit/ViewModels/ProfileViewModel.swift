import Foundation
import Supabase

// MARK: - Profile Tab

enum ProfileTab: String, CaseIterable, Identifiable {
    case feed
    case calendar
    case stats

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .feed: return "list.bullet"
        case .calendar: return "calendar"
        case .stats: return "chart.bar"
        }
    }

    var label: String {
        switch self {
        case .feed: return "Feed"
        case .calendar: return "Calendar"
        case .stats: return "Stats"
        }
    }
}

// MARK: - ProfileViewModel

@MainActor
@Observable
final class ProfileViewModel {
    // MARK: - Derived stat types

    /// One weekly bucket of training volume.
    struct VolumeBucket: Identifiable {
        let id = UUID()
        let weekStart: Date
        let volume: Double
    }

    /// Aggregated lifetime volume for a single exercise.
    struct TopExercise: Identifiable {
        let id = UUID()
        let name: String
        let volume: Double
        let setCount: Int
    }

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

    // MARK: - Username validation
    var usernameError: String?
    var isCheckingUsername: Bool = false
    private var usernameCheckTask: Task<Void, Never>?

    // MARK: - Stats
    var totalWorkouts: Int = 0
    var totalVolume: Double = 0
    var totalPRs: Int = 0
    var recentPRs: [PersonalRecord] = []
    /// Full PR list (used for derived stats like PR-of-the-month).
    var allPRs: [PersonalRecord] = []

    // MARK: - Derived Stats (computed in `computeDerivedStats`)
    /// 4 weekly buckets covering the last ~30 days, oldest first. Empty weeks emit a 0 bucket.
    var volumeTrend30d: [VolumeBucket] = []
    /// Workout count per week for last 4 weeks, oldest first.
    var workoutsPerWeek4w: [Int] = []
    /// Mean of `workoutsPerWeek4w`.
    var avgWorkoutsPerWeek: Double = 0
    /// Top 5 lifetime exercises ranked by total volume (laterality-aware).
    var topExercisesByVolume: [TopExercise] = []
    /// Highest %-improvement PR within the last 30 days, if any.
    var prOfTheMonth: PersonalRecord? = nil

    // MARK: - Muscle Group Heatmap
    var muscleGroupSetsThisWeek: [String: Int] = [:]
    var muscleGroupSetsThisMonth: [String: Int] = [:]

    // MARK: - Tab state
    var selectedTab: ProfileTab = .feed

    // MARK: - Feed
    var feedItems: [SocialFeedItem] = []
    var feedDateRange: FeedDateRange = .all
    var feedMuscleGroups: Set<MuscleGroup> = []

    var filteredFeedItems: [SocialFeedItem] {
        feedItems.filter { item in
            if let start = feedDateRange.startDate, item.createdAt < start {
                return false
            }
            if !feedMuscleGroups.isEmpty {
                guard let exercises = item.workoutActivity?.exercises else { return false }
                let itemGroups = exercises.flatMap { ex in
                    ExerciseDatabase.all.first(where: { $0.name == ex.name })?.muscleGroups ?? []
                }
                if feedMuscleGroups.isDisjoint(with: itemGroups) { return false }
            }
            return true
        }
    }

    var isFeedFiltered: Bool { feedDateRange != .all || !feedMuscleGroups.isEmpty }

    // MARK: - Workouts (profile history)
    var workouts: [Workout] = []

    var filteredWorkouts: [Workout] {
        workouts.filter { workout in
            if let start = feedDateRange.startDate, workout.startTime < start {
                return false
            }
            if !feedMuscleGroups.isEmpty {
                let groups = workout.exercises.flatMap { $0.exercise.muscleGroups }
                if feedMuscleGroups.isDisjoint(with: groups) { return false }
            }
            return true
        }
    }

    // MARK: - Calendar
    var workoutDays: [Date: Int] = [:]

    // MARK: - Friends
    var friends: [FriendRow] = []
    var friendProfiles: [String: ProfileRow] = [:]

    // MARK: - Profile context
    var isOwnProfile: Bool = true
    var relation: FriendshipRelation = .none
    var friendCount: Int = 0
    var feedItemCount: Int = 0

    var isFriendsRelation: Bool {
        if case .friends = relation { return true }
        return false
    }

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

    /// Current consecutive-day workout streak (#250). 0 if today/yesterday have no workouts.
    var currentStreak: Int {
        WorkoutInsights.currentStreak(workouts: workouts)
    }

    /// Longest historical streak across all workouts (#250). Used as the streak-card subtitle.
    var longestStreak: Int {
        WorkoutInsights.longestStreak(workouts: workouts)
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
            await loadRelation(currentUserId: currentUserId, targetUserId: userId)

            // If private and not friends, stop here
            if isPrivate && !isFriendsRelation {
                isLoading = false
                return
            }
        }

        // Load remaining data in parallel
        async let workoutsTask = WorkoutService.shared.fetchWorkouts(userId: userId)
        async let prsTask = loadPRs(userId: userId)
        async let feedTask = loadFeed(userId: userId)
        async let friendsTask = loadFriends(userId: userId)

        let fetchedWorkouts = await workoutsTask
        workouts = fetchedWorkouts
        totalWorkouts = fetchedWorkouts.count
        totalVolume = fetchedWorkouts.reduce(0) { $0 + $1.totalVolume }
        loadCalendarData(workouts: fetchedWorkouts)
        computeMuscleGroupSets(workouts: fetchedWorkouts)

        await prsTask
        await feedTask
        await friendsTask

        // Compute derived stats after PRs load so PR-of-the-month has data.
        computeDerivedStats(workouts: fetchedWorkouts)

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
        guard canSaveProfile else {
            errorMessage = usernameError ?? "Invalid username."
            return
        }

        isSaving = true
        errorMessage = nil
        do {
            let savedUsername = editUsername.trimmingCharacters(in: .whitespaces).lowercased()
                .isEmpty ? (username.isEmpty ? userId : username) : editUsername.trimmingCharacters(in: .whitespaces).lowercased()
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
        usernameError = nil
        isCheckingUsername = false
    }

    /// Debounced username uniqueness check against Supabase.
    func checkUsernameAvailability(userId: String) {
        usernameCheckTask?.cancel()
        usernameError = nil

        let trimmed = editUsername.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return }

        // Validate format first
        guard trimmed.count >= 3 else {
            usernameError = "Username must be at least 3 characters."
            return
        }
        guard trimmed.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else {
            usernameError = "Letters, numbers, and underscores only."
            return
        }

        // Skip server check if username hasn't changed
        if trimmed == username { return }

        isCheckingUsername = true
        usernameCheckTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            do {
                let existing: [ProfileRow] = try await supabase
                    .from("profiles")
                    .select("id")
                    .eq("username", value: trimmed)
                    .neq("id", value: userId)
                    .limit(1)
                    .execute()
                    .value

                guard !Task.isCancelled else { return }
                if !existing.isEmpty {
                    usernameError = "Username already taken."
                }
            } catch {
                guard !Task.isCancelled else { return }
            }
            isCheckingUsername = false
        }
    }

    /// Whether the save button should be disabled.
    var canSaveProfile: Bool {
        usernameError == nil && !isCheckingUsername && !editUsername.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Friend Request

    func sendFriendRequest(fromUserId: String, toUserId: String) async {
        do {
            let newId = try await FriendsService.shared.sendFriendRequest(
                fromUserId: fromUserId,
                toUserId: toUserId
            )
            relation = .outgoingPending(friendshipId: newId)
        } catch FriendError.alreadyExists(let existing) {
            // DB/concurrent-race fallback — reflect the actual state
            relation = existing
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancelRequest() async {
        guard case .outgoingPending(let id) = relation else { return }
        do {
            try await FriendsService.shared.cancelFriendRequest(friendshipId: id)
            relation = .none
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func acceptIncoming() async {
        guard case .incomingPending(let id) = relation else { return }
        do {
            try await FriendsService.shared.acceptFriendRequest(friendshipId: id)
            relation = .friends(friendshipId: id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func declineIncoming() async {
        guard case .incomingPending(let id) = relation else { return }
        do {
            try await FriendsService.shared.declineFriendRequest(friendshipId: id)
            relation = .none
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeFriend() async {
        guard case .friends(let id) = relation else { return }
        do {
            try await FriendsService.shared.removeFriend(friendshipId: id)
            relation = .none
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Private Helpers

    private func loadPRs(userId: String) async {
        do {
            let prs = try await PRService.shared.fetchPRs(userId: userId)
            totalPRs = prs.count
            allPRs = prs
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

    private func loadRelation(currentUserId: String, targetUserId: String) async {
        do {
            relation = try await FriendsService.shared.relation(
                currentUserId: currentUserId,
                otherUserId: targetUserId
            )
        } catch {
            relation = .none
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

    // MARK: - Derived Stats

    /// Computes the four derived stats surfaced on the Profile > Stats tab:
    /// `volumeTrend30d`, `workoutsPerWeek4w` (+ `avgWorkoutsPerWeek`), `topExercisesByVolume`, `prOfTheMonth`.
    /// Pure derivation over `workouts` and `allPRs` — no fetching, safe to re-run.
    func computeDerivedStats(workouts: [Workout]) {
        let calendar = Calendar.current
        let now = Date()

        // Build 4 weekly buckets ending today, oldest first. Each bucket spans 7 days.
        // Bucket i covers [now - (4 - i) * 7d, now - (3 - i) * 7d).
        let bucketCount = 4
        var bucketStarts: [Date] = []
        for i in 0..<bucketCount {
            let daysBack = (bucketCount - i) * 7
            if let start = calendar.date(byAdding: .day, value: -daysBack, to: now) {
                bucketStarts.append(start)
            }
        }
        // Bucket end is the next bucket's start (or `now` for the last bucket).
        var bucketRanges: [(start: Date, end: Date)] = []
        for i in 0..<bucketStarts.count {
            let end = i + 1 < bucketStarts.count ? bucketStarts[i + 1] : now
            bucketRanges.append((bucketStarts[i], end))
        }

        var volumeBuckets: [VolumeBucket] = []
        var weekCounts: [Int] = []
        for range in bucketRanges {
            let inRange = workouts.filter { $0.startTime >= range.start && $0.startTime < range.end }
            let volume = inRange.reduce(0.0) { $0 + $1.totalVolume }
            volumeBuckets.append(VolumeBucket(weekStart: range.start, volume: volume))
            weekCounts.append(inRange.count)
        }
        volumeTrend30d = volumeBuckets
        workoutsPerWeek4w = weekCounts
        avgWorkoutsPerWeek = weekCounts.isEmpty
            ? 0
            : Double(weekCounts.reduce(0, +)) / Double(weekCounts.count)

        // Top exercises: group by name, sum laterality-aware volume + set counts.
        var volumeByName: [String: Double] = [:]
        var setsByName: [String: Int] = [:]
        for workout in workouts {
            for exercise in workout.exercises {
                let name = exercise.exercise.name
                volumeByName[name, default: 0] += exercise.totalVolume
                setsByName[name, default: 0] += exercise.sets.count
            }
        }
        topExercisesByVolume = volumeByName
            .map { TopExercise(name: $0.key, volume: $0.value, setCount: setsByName[$0.key] ?? 0) }
            .sorted { lhs, rhs in
                if lhs.volume != rhs.volume { return lhs.volume > rhs.volume }
                return lhs.name < rhs.name // stable tiebreak
            }
            .prefix(5)
            .map { $0 }

        // PR of the month: highest %-improvement PR within the last 30 days.
        // Only PRs with a `previousBest > 0` qualify (need a measurable improvement baseline).
        guard let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) else {
            prOfTheMonth = nil
            return
        }
        let recent = allPRs.filter { $0.date >= thirtyDaysAgo }
        let scored: [(pr: PersonalRecord, pct: Double)] = recent.compactMap { pr in
            guard let prev = pr.previousBest, prev > 0 else { return nil }
            let pct = (pr.weight - prev) / prev
            guard pct > 0 else { return nil }
            return (pr, pct)
        }
        prOfTheMonth = scored
            .sorted { lhs, rhs in
                if lhs.pct != rhs.pct { return lhs.pct > rhs.pct }
                return lhs.pr.date > rhs.pr.date // tiebreak: most recent
            }
            .first?
            .pr
    }

}
