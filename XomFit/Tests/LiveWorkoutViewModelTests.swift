import XCTest
@testable import XomFit

@MainActor
final class LiveWorkoutViewModelTests: XCTestCase {
    var viewModel: LiveWorkoutViewModel!
    let testUserId = "test-user-1"
    
    override func setUp() {
        super.setUp()
        viewModel = LiveWorkoutViewModel(userId: testUserId)
    }
    
    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }
    
    // MARK: - Starting Live Workout
    
    func testStartLiveWorkout() {
        let workout = Workout.mock
        let user = User.mock
        
        viewModel.startLiveWorkout(from: workout, user: user)
        
        XCTAssertNotNil(viewModel.currentLiveWorkout)
        XCTAssertTrue(viewModel.isLiveWorkoutActive)
        XCTAssertEqual(viewModel.currentLiveWorkout?.userId, testUserId)
        XCTAssertEqual(viewModel.currentLiveWorkout?.user?.id, user.id)
        XCTAssertEqual(viewModel.currentLiveWorkout?.workoutName, workout.name)
    }
    
    func testLiveWorkoutHasUniqueID() {
        let workout = Workout.mock
        let user = User.mock
        
        viewModel.startLiveWorkout(from: workout, user: user)
        let firstID = viewModel.currentLiveWorkout?.id
        
        viewModel.endLiveWorkout()
        viewModel.startLiveWorkout(from: workout, user: user)
        let secondID = viewModel.currentLiveWorkout?.id
        
        XCTAssertNotEqual(firstID, secondID, "Each live workout should have a unique ID")
    }
    
    // MARK: - Updating Live Workout
    
    func testUpdateLiveWorkoutWithSet() {
        let workout = Workout.mock
        let user = User.mock
        viewModel.startLiveWorkout(from: workout, user: user)
        
        let exercise = workout.exercises.first!
        let set = WorkoutSet(
            id: "set-1",
            exerciseId: exercise.id,
            weight: 225,
            reps: 5,
            rpe: 8.5,
            isPersonalRecord: false,
            completedAt: Date()
        )
        
        viewModel.updateLiveWorkoutWithSet(set, forExercise: exercise)
        
        XCTAssertEqual(viewModel.currentLiveWorkout?.currentSet?.id, "set-1")
        XCTAssertEqual(viewModel.currentLiveWorkout?.currentSet?.weight, 225)
        XCTAssertEqual(viewModel.currentLiveWorkout?.currentSet?.reps, 5)
    }
    
    func testUpdateLiveWorkoutExercise() {
        let workout = Workout.mock
        let user = User.mock
        viewModel.startLiveWorkout(from: workout, user: user)
        
        let firstExercise = workout.exercises.first!
        let newExercise = WorkoutExercise(
            id: "ex-new",
            exercise: .squat,
            sets: [],
            notes: nil
        )
        
        viewModel.updateLiveWorkoutExercise(newExercise)
        
        XCTAssertEqual(viewModel.currentLiveWorkout?.currentExercise?.id, "ex-new")
        XCTAssertEqual(viewModel.currentLiveWorkout?.currentExercise?.exercise.name, "Barbell Squat")
        XCTAssertNil(viewModel.currentLiveWorkout?.currentSet, "Current set should be cleared when exercise changes")
    }
    
    // MARK: - Reactions
    
    func testAddReaction() {
        let workout = Workout.mock
        let user = User.mock
        viewModel.startLiveWorkout(from: workout, user: user)
        
        viewModel.addReaction("💪")
        
        XCTAssertEqual(viewModel.recentReactions.count, 1)
        XCTAssertEqual(viewModel.recentReactions.first?.emoji, "💪")
        XCTAssertEqual(viewModel.recentReactions.first?.userId, testUserId)
    }
    
    func testMultipleReactions() {
        let workout = Workout.mock
        let user = User.mock
        viewModel.startLiveWorkout(from: workout, user: user)
        
        viewModel.addReaction("💪")
        viewModel.addReaction("🔥")
        viewModel.addReaction("👏")
        
        XCTAssertEqual(viewModel.recentReactions.count, 3)
        XCTAssertEqual(viewModel.recentReactions[0].emoji, "👏")
        XCTAssertEqual(viewModel.recentReactions[1].emoji, "🔥")
        XCTAssertEqual(viewModel.recentReactions[2].emoji, "💪")
    }
    
    func testReactionLimitEnforcement() {
        let workout = Workout.mock
        let user = User.mock
        viewModel.startLiveWorkout(from: workout, user: user)
        
        // Add 60 reactions
        for i in 0..<60 {
            viewModel.addReaction(String(i % 2 == 0 ? "💪" : "🔥"))
        }
        
        // Should only keep 50 most recent
        XCTAssertEqual(viewModel.recentReactions.count, 50)
    }
    
    // MARK: - Ending Workout
    
    func testEndLiveWorkout() {
        let workout = Workout.mock
        let user = User.mock
        viewModel.startLiveWorkout(from: workout, user: user)
        viewModel.addReaction("💪")
        
        XCTAssertTrue(viewModel.isLiveWorkoutActive)
        XCTAssertEqual(viewModel.recentReactions.count, 1)
        
        viewModel.endLiveWorkout()
        
        XCTAssertFalse(viewModel.isLiveWorkoutActive)
        XCTAssertNil(viewModel.currentLiveWorkout)
        XCTAssertEqual(viewModel.recentReactions.count, 0)
    }
    
    // MARK: - Viewers
    
    func testGetViewers() {
        viewModel.viewers = [
            LiveWorkoutViewer(
                id: "viewer-1",
                userId: "user-2",
                user: User.mockFriend
            ),
            LiveWorkoutViewer(
                id: "viewer-2",
                userId: "user-3",
                user: User.mockFriend
            )
        ]
        
        let viewers = viewModel.getViewers()
        
        XCTAssertEqual(viewers.count, 2)
        XCTAssertEqual(viewers.first?.userId, "user-2")
    }
    
    // MARK: - Connection Status
    
    func testConnectionStatusInitialization() {
        let newViewModel = LiveWorkoutViewModel(userId: "new-user")
        
        XCTAssertEqual(newViewModel.connectionStatus, .disconnected)
    }
}

// MARK: - Real-time Update Tests

@MainActor
final class RealtimeDataSyncServiceTests: XCTestCase {
    var service: RealtimeDataSyncService!
    let testUserId = "test-user-1"
    
    override func setUp() {
        super.setUp()
        service = RealtimeDataSyncService(userId: testUserId)
    }
    
    override func tearDown() {
        service = nil
        super.tearDown()
    }
    
    func testServiceInitialization() {
        XCTAssertEqual(service.connectionStatus, .disconnected)
    }
    
    func testBroadcastLiveWorkout() {
        let liveWorkout = LiveWorkout(
            id: "live-1",
            userId: testUserId,
            user: User.mock,
            currentExercise: nil,
            currentSet: nil,
            reactions: [],
            viewers: [],
            startTime: Date(),
            lastUpdated: Date(),
            isActive: true
        )
        
        service.broadcastLiveWorkout(liveWorkout)
        // In production, verify broadcast was sent to WebSocket
    }
    
    func testBroadcastSetCompleted() {
        let set = WorkoutSet(
            id: "set-1",
            exerciseId: "ex-1",
            weight: 225,
            reps: 5,
            rpe: 8.5,
            isPersonalRecord: false,
            completedAt: Date()
        )
        
        let exercise = WorkoutExercise(
            id: "ex-1",
            exercise: .benchPress,
            sets: [set],
            notes: nil
        )
        
        service.broadcastSetCompleted(setData: set, exerciseData: exercise, liveWorkoutId: "live-1")
        // Verify message creation
    }
    
    func testBroadcastReaction() {
        let reaction = LiveReaction(
            id: "reaction-1",
            userId: "user-2",
            user: User.mockFriend,
            emoji: "💪",
            timestamp: Date()
        )
        
        service.broadcastReaction(reaction, forLiveWorkoutId: "live-1")
        // Verify broadcast
    }
    
    func testFetchActiveLiveWorkouts() async {
        let liveWorkout = LiveWorkout(
            id: "live-1",
            userId: "user-2",
            user: User.mockFriend,
            currentExercise: nil,
            currentSet: nil,
            reactions: [],
            viewers: [],
            startTime: Date(),
            lastUpdated: Date(),
            isActive: true
        )
        
        service.broadcastLiveWorkout(liveWorkout)
        
        do {
            let workouts = try await service.fetchActiveLiveWorkouts()
            XCTAssertGreaterThan(workouts.count, 0)
        } catch {
            XCTFail("Failed to fetch active live workouts: \(error)")
        }
    }
}

// MARK: - Notification Tests

final class ActivityNotificationServiceTests: XCTestCase {
    let service = ActivityNotificationService.shared
    
    func testNotifyFriendStartedLiveWorkout() {
        let user = User.mock
        
        // This should not crash
        service.notifyFriendStartedLiveWorkout(user, workoutName: "Push Day")
    }
    
    func testNotifyReactionReceived() {
        let reactor = User.mockFriend
        
        // This should not crash
        service.notifyReactionReceived(reactor, emoji: "💪")
    }
    
    func testNotifyViewerJoined() {
        let viewer = User.mockFriend
        
        // This should not crash
        service.notifyViewerJoined(viewer)
    }
}

// MARK: - Mock Extensions

extension LiveWorkout {
    static let mock = LiveWorkout(
        id: "live-1",
        userId: "user-1",
        user: User.mock,
        currentExercise: WorkoutExercise(
            id: "ex-1",
            exercise: .benchPress,
            sets: [],
            notes: nil
        ),
        currentSet: nil,
        reactions: [],
        viewers: [],
        startTime: Date(),
        lastUpdated: Date(),
        isActive: true
    )
}

extension LiveReaction {
    static let mock = LiveReaction(
        id: "reaction-1",
        userId: "user-2",
        user: User.mockFriend,
        emoji: "💪",
        timestamp: Date()
    )
}

extension LiveWorkoutViewer {
    static let mock = LiveWorkoutViewer(
        id: "viewer-1",
        userId: "user-2",
        user: User.mockFriend
    )
}
