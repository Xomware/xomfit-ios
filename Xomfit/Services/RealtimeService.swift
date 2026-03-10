import Foundation
import Combine

@MainActor
class RealtimeService: NSObject, ObservableObject {
    static let shared = RealtimeService()
    
    @Published var challengeUpdates = PassthroughSubject<ChallengeUpdate, Never>()
    @Published var leaderboardChanges = PassthroughSubject<LeaderboardChangeEvent, Never>()
    @Published var streakUpdates = PassthroughSubject<StreakUpdate, Never>()
    
    private var realtimeSubscriptions: [String: AnyCancellable] = [:]
    private let supabaseService: SupabaseService
    
    override init() {
        self.supabaseService = .shared
        super.init()
    }
    
    // MARK: - Subscription Management
    
    func subscribeToChallengeUpdates(
        challengeId: String
    ) {
        let subscriptionKey = "challenge_\(challengeId)"
        
        // Cancel existing subscription
        realtimeSubscriptions[subscriptionKey]?.cancel()
        
        // Create new subscription
        // In a real implementation, this would use Supabase Realtime
        let subscription = Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.pollChallengeUpdates(challengeId: challengeId)
                }
            }
        
        realtimeSubscriptions[subscriptionKey] = subscription
    }
    
    func subscribeToLeaderboardUpdates(
        challengeId: String
    ) {
        let subscriptionKey = "leaderboard_\(challengeId)"
        
        // Cancel existing subscription
        realtimeSubscriptions[subscriptionKey]?.cancel()
        
        // Create new subscription
        let subscription = Timer.publish(every: 3, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.pollLeaderboardUpdates(challengeId: challengeId)
                }
            }
        
        realtimeSubscriptions[subscriptionKey] = subscription
    }
    
    func subscribeToStreakUpdates(
        userId: String,
        challengeId: String
    ) {
        let subscriptionKey = "streak_\(userId)_\(challengeId)"
        
        // Cancel existing subscription
        realtimeSubscriptions[subscriptionKey]?.cancel()
        
        // Create new subscription
        let subscription = Timer.publish(every: 10, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.pollStreakUpdates(userId: userId, challengeId: challengeId)
                }
            }
        
        realtimeSubscriptions[subscriptionKey] = subscription
    }
    
    func unsubscribe(from subscriptionKey: String) {
        realtimeSubscriptions[subscriptionKey]?.cancel()
        realtimeSubscriptions.removeValue(forKey: subscriptionKey)
    }
    
    func unsubscribeAll() {
        realtimeSubscriptions.values.forEach { $0.cancel() }
        realtimeSubscriptions.removeAll()
    }
    
    // MARK: - Polling Methods (Fallback for Real-time)
    
    private func pollChallengeUpdates(challengeId: String) async {
        // In a production app, you'd query Supabase for recent updates
        // and publish them through the challengeUpdates subject
        
        do {
            // Example: Fetch updated challenge
            // let challenge = try await supabaseService.fetch(Challenge.self, from: "challenges", where: "id", equals: challengeId)
            // challengeUpdates.send(ChallengeUpdate(challenge: challenge))
        } catch {
            print("Error polling challenge updates: \(error)")
        }
    }
    
    private func pollLeaderboardUpdates(challengeId: String) async {
        do {
            // Query recent rank changes
            // This would typically involve comparing current leaderboard with cached version
        } catch {
            print("Error polling leaderboard updates: \(error)")
        }
    }
    
    private func pollStreakUpdates(userId: String, challengeId: String) async {
        do {
            // Check for streak changes
            if let streak = await StreakService.shared.getStreak(userId: userId, challengeId: challengeId) {
                streakUpdates.send(StreakUpdate(streak: streak, timestamp: Date()))
            }
        } catch {
            print("Error polling streak updates: \(error)")
        }
    }
}

// MARK: - Update Models

struct ChallengeUpdate {
    let challengeId: String
    let type: ChallengeUpdateType
    let timestamp: Date = Date()
    
    enum ChallengeUpdateType {
        case statusChanged(ChallengeStatus)
        case daysRemainingChanged(Int)
        case participantAdded(String)
        case participantRemoved(String)
    }
}

struct LeaderboardChangeEvent {
    let challengeId: String
    let changes: [RankChange]
    let timestamp: Date = Date()
    
    struct RankChange {
        let userId: String
        let oldRank: Int
        let newRank: Int
        let valueChange: Double
    }
}

struct StreakUpdate {
    let streak: Streak
    let timestamp: Date
    let changeType: StreakChangeType
    
    init(streak: Streak, timestamp: Date) {
        self.streak = streak
        self.timestamp = timestamp
        
        // Determine change type based on streak status
        self.changeType = streak.isActive ? .updated : .broken
    }
    
    enum StreakChangeType {
        case created
        case updated
        case broken
        case resetOnDay
    }
}

// MARK: - Real Supabase Realtime Integration (Future)
// This extension would use the supabase-swift RealtimeChannelV2 API
extension RealtimeService {
    
    /// Future: Connect to actual Supabase Realtime instead of polling
    func setupRealtimeConnection() {
        // TODO: Implement with supabase-swift v3+ RealtimeChannelV2
        // Example:
        // let channel = supabase.realtime.channel("challenges")
        // channel.on(.update) { payload in
        //     if let update = try? JSONDecoder().decode(ChallengeUpdate.self, from: payload.data) {
        //         self.challengeUpdates.send(update)
        //     }
        // }
    }
}
