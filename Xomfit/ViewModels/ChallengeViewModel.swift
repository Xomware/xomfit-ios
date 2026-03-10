import Foundation
import Combine

@MainActor
class ChallengeViewModel: ObservableObject {
    @Published var challenges: [Challenge] = []
    @Published var activeChallenges: [Challenge] = []
    @Published var selectedChallenge: ChallengeDetail?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var userChallenges: [Challenge] = []
    @Published var realtimeUpdates: [String: Date] = [:]  // Track last update time per challenge
    
    private var cancellables = Set<AnyCancellable>()
    let supabaseService: SupabaseService
    private let notificationService: NotificationService
    private let realtimeService: RealtimeService
    private let badgeService: BadgeService
    private let streakService: StreakService
    private let friendsService: FriendsService
    
    init(supabaseService: SupabaseService = .shared,
         notificationService: NotificationService = .shared,
         realtimeService: RealtimeService = .shared,
         badgeService: BadgeService = .shared,
         streakService: StreakService = .shared,
         friendsService: FriendsService = .shared) {
        self.supabaseService = supabaseService
        self.notificationService = notificationService
        self.realtimeService = realtimeService
        self.badgeService = badgeService
        self.streakService = streakService
        self.friendsService = friendsService
        
        // Setup real-time subscriptions
        setupRealtimeListeners()
    }
    
    // MARK: - Real-time Setup
    
    private func setupRealtimeListeners() {
        realtimeService.leaderboardChanges
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                Task { @MainActor in
                    await self?.handleLeaderboardChange(event)
                }
            }
            .store(in: &cancellables)
        
        realtimeService.streakUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in
                Task { @MainActor in
                    await self?.handleStreakUpdate(update)
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleLeaderboardChange(_ event: LeaderboardChangeEvent) async {
        // Update the selected challenge with new leaderboard data
        if let selectedChallenge = selectedChallenge, selectedChallenge.challenge.id == event.challengeId {
            realtimeUpdates[event.challengeId] = Date()
            await fetchChallengeDetail(challengeId: event.challengeId)
        }
    }
    
    private func handleStreakUpdate(_ update: StreakUpdate) async {
        // Notify user of streak changes
        switch update.changeType {
        case .updated:
            await notificationService.sendChallengeUpdate(
                title: "Streak Updated!",
                body: "Your \(update.streak.count)-day streak is going strong! 🔥"
            )
        case .broken:
            await notificationService.sendChallengeUpdate(
                title: "Streak Lost",
                body: "Your streak was broken. Get back in the gym!"
            )
        case .created:
            break
        case .resetOnDay:
            break
        }
    }
    
    // MARK: - Public Methods
    
    func fetchChallenges() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let allChallenges = try await supabaseService.fetch(Challenge.self, from: "challenges")
            self.challenges = allChallenges
            self.activeChallenges = allChallenges.filter { $0.isActive }
        } catch {
            errorMessage = "Failed to fetch challenges: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func fetchUserChallenges(userId: String) async {
        isLoading = true
        
        do {
            let userChallenges = try await supabaseService.fetch(
                Challenge.self,
                from: "challenges",
                where: "participants", isContainedIn: userId
            )
            self.userChallenges = userChallenges
        } catch {
            errorMessage = "Failed to fetch user challenges: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func fetchChallengeDetail(challengeId: String) async {
        isLoading = true
        
        do {
            let challenge = try await supabaseService.fetch(
                Challenge.self,
                from: "challenges",
                where: "id", equals: challengeId
            ).first
            
            guard let challenge = challenge else {
                throw NSError(domain: "Challenge not found", code: 404)
            }
            
            let leaderboard = try await fetchLeaderboard(for: challengeId)
            let streaks = try await fetchStreaks(for: challengeId)
            let currentUserId = supabaseService.currentUserId
            
            let detail = ChallengeDetail(
                id: challenge.id,
                challenge: challenge,
                leaderboard: leaderboard,
                currentUserRank: leaderboard.first(where: { $0.userId == currentUserId })?.rank,
                currentUserValue: challenge.results.first(where: { $0.userId == currentUserId })?.value,
                streaks: streaks
            )
            
            self.selectedChallenge = detail
        } catch {
            errorMessage = "Failed to fetch challenge details: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func createChallenge(
        type: ChallengeType,
        participantIds: [String],
        startDate: Date = Date()
    ) async -> Challenge? {
        isLoading = true
        errorMessage = nil
        
        let endDate = Calendar.current.date(byAdding: .day, value: type.durationDays, to: startDate)!
        let challengeId = UUID().uuidString
        
        let challenge = Challenge(
            id: challengeId,
            type: type,
            status: .upcoming,
            createdBy: supabaseService.currentUserId,
            participants: participantIds,
            startDate: startDate,
            endDate: endDate,
            results: initializeResults(for: participantIds, challengeId: challengeId),
            createdAt: Date(),
            updatedAt: Date()
        )
        
        do {
            try await supabaseService.insert(challenge, into: "challenges")
            
            // Initialize streaks for all participants
            for participantId in participantIds {
                let streak = Streak(
                    id: UUID().uuidString,
                    userId: participantId,
                    challengeId: challengeId,
                    count: 0,
                    lastWorkoutDate: Date()
                )
                try await supabaseService.insert(streak, into: "streaks")
            }
            
            // Subscribe to real-time updates
            realtimeService.subscribeToChallengeUpdates(challengeId: challengeId)
            realtimeService.subscribeToLeaderboardUpdates(challengeId: challengeId)
            
            // Notify participants
            await notifyParticipants(
                participantIds,
                aboutChallenge: challenge
            )
            
            isLoading = false
            return challenge
        } catch {
            errorMessage = "Failed to create challenge: \(error.localizedDescription)"
            isLoading = false
            return nil
        }
    }
    
    func joinChallenge(challengeId: String) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            let userId = supabaseService.currentUserId
            let participant = ChallengeParticipant(
                id: UUID().uuidString,
                challengeId: challengeId,
                userId: userId,
                joinStatus: .accepted,
                joinedAt: Date()
            )
            try await supabaseService.insert(participant, into: "challenge_participants")

            // Subscribe to real-time updates
            realtimeService.subscribeToChallengeUpdates(challengeId: challengeId)
            realtimeService.subscribeToLeaderboardUpdates(challengeId: challengeId)

            // Refresh challenge data
            await fetchChallengeDetail(challengeId: challengeId)

            isLoading = false
            return true
        } catch {
            errorMessage = "Failed to join challenge: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }

    func declineChallenge(challengeId: String) async {
        do {
            let participant = ChallengeParticipant(
                id: UUID().uuidString,
                challengeId: challengeId,
                userId: supabaseService.currentUserId,
                joinStatus: .declined,
                joinedAt: Date()
            )
            try await supabaseService.insert(participant, into: "challenge_participants")
        } catch {
            errorMessage = "Failed to decline challenge: \(error.localizedDescription)"
        }
    }

    func updateChallengeResults(
        challengeId: String,
        userId: String,
        value: Double
    ) async {
        do {
            let result = ChallengeResult(
                id: UUID().uuidString,
                challengeId: challengeId,
                userId: userId,
                rank: 0, // Will be calculated
                value: value,
                unit: "lbs",
                lastUpdated: Date()
            )
            
            try await supabaseService.insert(result, into: "challenge_results")
            
            // Update streak
            await streakService.updateStreak(userId: userId, challengeId: challengeId)
            
            // Recalculate leaderboard
            await fetchChallengeDetail(challengeId: challengeId)
            
            // Evaluate and award badges
            if let detail = selectedChallenge {
                let earnedBadges = await badgeService.evaluateBadges(
                    for: userId,
                    challengeId: challengeId,
                    leaderboard: detail.leaderboard
                )
                
                // Notify about earned badges
                if !earnedBadges.isEmpty {
                    let badgeNames = earnedBadges.map { $0.name }.joined(separator: ", ")
                    await notificationService.sendChallengeUpdate(
                        title: "Badges Earned!",
                        body: "You earned: \(badgeNames)"
                    )
                }
            }
            
            // Notify about rank change
            if let detail = selectedChallenge, let newRank = detail.currentUserRank {
                await notificationService.sendChallengeUpdate(
                    title: "Challenge Update",
                    body: "You're now ranked #\(newRank) in \(detail.challenge.type.displayName)"
                )
            }
        } catch {
            errorMessage = "Failed to update challenge results: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Friends Management
    
    func fetchFriendsForChallenge() async -> [FriendForChallenge] {
        return await friendsService.fetchFriendsForChallenge(
            for: supabaseService.currentUserId
        )
    }
    
    // MARK: - Private Methods
    
    private func fetchLeaderboard(for challengeId: String) async throws -> [ChallengeLeaderboardEntry] {
        let results = try await supabaseService.fetch(
            ChallengeResult.self,
            from: "challenge_results",
            where: "challengeId", equals: challengeId
        )
        
        let ranked = results
            .sorted { $0.value > $1.value }
            .enumerated()
            .map { index, result -> ChallengeResult in
                var updated = result
                // Update rank based on sorted position
                return updated
            }
        
        var entries: [ChallengeLeaderboardEntry] = []
        for (index, result) in ranked.enumerated() {
            let user = try? await supabaseService.fetch(
                AppUser.self,
                from: "users",
                where: "id", equals: result.userId
            ).first
            
            let badges = try await fetchBadges(for: result.userId, challengeId: challengeId)
            let streak = try await fetchStreak(for: result.userId, challengeId: challengeId)
            
            entries.append(ChallengeLeaderboardEntry(
                id: result.id,
                userId: result.userId,
                userName: user?.displayName ?? "Unknown",
                userAvatar: user?.avatarURL,
                rank: index + 1,
                value: result.value,
                unit: result.unit,
                streak: streak?.count ?? 0,
                badges: badges
            ))
        }
        
        return entries
    }
    
    private func fetchStreaks(for challengeId: String) async throws -> [Streak] {
        return try await supabaseService.fetch(
            Streak.self,
            from: "streaks",
            where: "challengeId", equals: challengeId
        )
    }
    
    private func fetchStreak(for userId: String, challengeId: String) async throws -> Streak? {
        let streaks = try await supabaseService.fetch(
            Streak.self,
            from: "streaks",
            where: "userId", equals: userId
        )
        return streaks.first(where: { $0.challengeId == challengeId })
    }
    
    private func fetchBadges(for userId: String, challengeId: String) async throws -> [Badge] {
        return try await supabaseService.fetch(
            Badge.self,
            from: "badges",
            where: "userId", equals: userId
        ).filter { badge in
            // Filter badges earned in this challenge
            badge.description.contains(challengeId)
        }
    }
    
    private func initializeResults(
        for participantIds: [String],
        challengeId: String
    ) -> [ChallengeResult] {
        return participantIds.map { userId in
            ChallengeResult(
                id: UUID().uuidString,
                challengeId: challengeId,
                userId: userId,
                rank: participantIds.count,
                value: 0,
                unit: "lbs",
                lastUpdated: Date()
            )
        }
    }
    
    private func notifyParticipants(
        _ participantIds: [String],
        aboutChallenge challenge: Challenge
    ) async {
        for participantId in participantIds {
            if participantId != supabaseService.currentUserId {
                await notificationService.sendChallengeInvitation(
                    title: "New Challenge Invite",
                    body: "\(challenge.createdBy) invited you to a \(challenge.type.displayName) challenge!"
                )
            }
        }
    }
}

// MARK: - Mock Supabase Service
class SupabaseService {
    static let shared = SupabaseService()
    var currentUserId = "user_123"
    
    func fetch<T: Decodable>(_ type: T.Type, from table: String) async throws -> [T] {
        // Mock implementation
        return []
    }
    
    func fetch<T: Decodable>(
        _ type: T.Type,
        from table: String,
        where column: String,
        equals value: String
    ) async throws -> [T] {
        return []
    }
    
    func fetch<T: Decodable>(
        _ type: T.Type,
        from table: String,
        where column: String,
        isContainedIn value: String
    ) async throws -> [T] {
        return []
    }
    
    func insert<T: Encodable>(_ object: T, into table: String) async throws {
        // Mock implementation
    }

    func update<T: Encodable>(_ object: T, in table: String, where column: String, equals value: String) async throws {
        // Mock implementation
    }
}

// MARK: - Mock Notification Service
class NotificationService {
    static let shared = NotificationService()
    
    func sendChallengeUpdate(title: String, body: String) async {
        // Implementation for sending notifications
    }
    
    func sendChallengeInvitation(title: String, body: String) async {
        // Implementation for sending invitations
    }
}
