import Foundation
import Combine

/// ViewModel for managing live workout sessions with real-time updates
@MainActor
class LiveWorkoutViewModel: ObservableObject {
    @Published var liveWorkouts: [LiveWorkout] = []
    @Published var currentLiveWorkout: LiveWorkout?
    @Published var isLiveWorkoutActive = false
    @Published var viewers: [LiveWorkoutViewer] = []
    @Published var recentReactions: [LiveReaction] = []
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var error: String?
    
    private var realtimeService: RealtimeDataSyncService?
    private var cancellables = Set<AnyCancellable>()
    private let userId: String
    
    enum ConnectionStatus: String, Codable {
        case connected
        case disconnected
        case connecting
        case error
    }
    
    init(userId: String) {
        self.userId = userId
        self.realtimeService = RealtimeDataSyncService(userId: userId)
        setupBindings()
    }
    
    private func setupBindings() {
        // Observe real-time service updates
        guard let service = realtimeService else { return }
        
        service.$connectionStatus
            .assign(to: &$connectionStatus)
        
        service.$liveWorkoutUpdate
            .compactMap { $0 }
            .sink { [weak self] update in
                self?.handleRealtimeUpdate(update)
            }
            .store(in: &cancellables)
    }
    
    /// Start broadcasting your workout as live
    func startLiveWorkout(from workout: Workout, user: AppUser) {
        let liveWorkout = LiveWorkout(
            id: UUID().uuidString,
            userId: userId,
            user: user,
            currentExercise: workout.exercises.first,
            currentSet: nil,
            reactions: [],
            viewers: [],
            startTime: Date(),
            lastUpdated: Date(),
            isActive: true
        )
        
        currentLiveWorkout = liveWorkout
        isLiveWorkoutActive = true
        
        // Sync to real-time service
        realtimeService?.broadcastLiveWorkout(liveWorkout)
    }
    
    /// Update live workout with new set completion
    func updateLiveWorkoutWithSet(_ set: WorkoutSet, forExercise exercise: WorkoutExercise) {
        guard var liveWorkout = currentLiveWorkout else { return }
        
        liveWorkout.currentSet = set
        liveWorkout.currentExercise = exercise
        liveWorkout.lastUpdated = Date()
        
        currentLiveWorkout = liveWorkout
        
        // Broadcast update
        realtimeService?.broadcastSetCompleted(setData: set, exerciseData: exercise, liveWorkoutId: liveWorkout.id)
    }
    
    /// Switch to a new exercise
    func updateLiveWorkoutExercise(_ exercise: WorkoutExercise) {
        guard var liveWorkout = currentLiveWorkout else { return }
        
        liveWorkout.currentExercise = exercise
        liveWorkout.currentSet = nil
        liveWorkout.lastUpdated = Date()
        
        currentLiveWorkout = liveWorkout
        
        // Broadcast update
        realtimeService?.broadcastExerciseChanged(exerciseData: exercise, liveWorkoutId: liveWorkout.id)
    }
    
    /// Add a reaction to the live workout
    func addReaction(_ emoji: String) {
        guard let liveWorkout = currentLiveWorkout else { return }
        
        let reaction = LiveReaction(
            id: UUID().uuidString,
            userId: userId,
            emoji: emoji,
            timestamp: Date()
        )
        
        recentReactions.insert(reaction, at: 0)
        
        // Keep only recent reactions (last 50)
        if recentReactions.count > 50 {
            recentReactions = Array(recentReactions.prefix(50))
        }
        
        // Broadcast reaction
        realtimeService?.broadcastReaction(reaction, forLiveWorkoutId: liveWorkout.id)
    }
    
    /// Subscribe to a friend's live workout
    func subscribToLiveWorkout(_ liveWorkout: LiveWorkout) {
        realtimeService?.subscribeLiveWorkout(liveWorkout)
    }
    
    /// Handle incoming real-time updates
    private func handleRealtimeUpdate(_ update: LiveWorkoutUpdate) {
        switch update.type {
        case .setCompleted:
            // Update current set in display
            break
        case .exerciseChanged:
            // Update current exercise in display
            break
        case .reactionAdded:
            if let reaction = try? JSONDecoder().decode(LiveReaction.self, from: JSONEncoder().encode(update.data.value)) {
                recentReactions.insert(reaction, at: 0)
                if recentReactions.count > 50 {
                    recentReactions = Array(recentReactions.prefix(50))
                }
            }
        case .viewerJoined:
            // Add viewer to list
            break
        case .viewerLeft:
            // Remove viewer from list
            break
        case .workoutEnded:
            endLiveWorkout()
        }
    }
    
    /// End the live workout session
    func endLiveWorkout() {
        if let liveWorkout = currentLiveWorkout {
            realtimeService?.broadcastWorkoutEnded(liveWorkoutId: liveWorkout.id)
        }
        
        currentLiveWorkout = nil
        isLiveWorkoutActive = false
        recentReactions = []
        viewers = []
    }
    
    /// Fetch active friends' live workouts
    func fetchActiveLiveWorkouts() async {
        guard let service = realtimeService else { return }
        do {
            liveWorkouts = try await service.fetchActiveLiveWorkouts()
        } catch {
            self.error = "Failed to fetch live workouts: \(error.localizedDescription)"
        }
    }
    
    /// Get list of friends currently viewing your workout
    func getViewers() -> [LiveWorkoutViewer] {
        return viewers
    }
}
