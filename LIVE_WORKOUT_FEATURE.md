# Live Workout Mode Feature

## Overview

Live Workout Mode allows users to broadcast their workouts in real-time to friends, who can watch and send reactions/cheers. This feature includes:

- **Real-time workout broadcasting** - Friends can see live set updates, exercise changes, and stats
- **Live Activity support** - Lock Screen widget showing current workout
- **Reactions/Cheers** - Friends can send emoji reactions (💪, 🔥, 👏, etc.)
- **Viewer notifications** - Know who's watching your workout
- **Activity notifications** - Get notified when friends start live workouts or hit PRs
- **Real-time data sync** - Placeholder for Supabase Realtime integration

## Architecture

### Components

#### Models (`XomFit/Models/LiveWorkout.swift`)
- `LiveWorkout` - Main model for a live workout session
- `LiveReaction` - Reaction/cheer from a friend
- `LiveWorkoutViewer` - Friend watching your workout
- `LiveWorkoutUpdate` - Real-time update message

#### ViewModels (`XomFit/ViewModels/LiveWorkoutViewModel.swift`)
- `LiveWorkoutViewModel` - Main view model managing live workout state and real-time updates

#### Services
- **RealtimeDataSyncService** (`XomFit/Services/RealtimeDataSyncService.swift`)
  - Handles WebSocket connection for real-time updates
  - Placeholder for Supabase Realtime integration
  - Broadcasts workout updates, reactions, viewer changes

- **ActivityNotificationService** (`XomFit/Services/ActivityNotificationService.swift`)
  - Push notifications for friend activities
  - Handles notification permissions and user actions

- **LiveActivityManager** (`XomFit/Services/LiveActivityManager.swift`)
  - Manages iOS 16.1+ Live Activities
  - Lock Screen widget updates
  - Real-time stats display

#### Views
- **LiveWorkoutView** (`XomFit/Views/Workout/LiveWorkoutView.swift`)
  - Main UI for displaying active lifter
  - Shows current exercise, set stats, viewers, reactions
  - Connection status indicator

- **LiveReactionView** (`XomFit/Views/Workout/LiveReactionView.swift`)
  - Emoji reaction UI with animations
  - Floating emoji particles
  - Reaction button grid

## Usage

### Starting a Live Workout

```swift
import SwiftUI

struct WorkoutStartView: View {
    @ObservedObject var workoutVM: WorkoutViewModel
    @ObservedObject var liveVM: LiveWorkoutViewModel
    
    var body: some View {
        Button("Start Live Workout") {
            if let activeWorkout = workoutVM.activeWorkout,
               let currentUser = authService.currentUser {
                liveVM.startLiveWorkout(from: activeWorkout, user: currentUser)
            }
        }
    }
}
```

### Updating Live Workout During Exercise

```swift
// When a set is completed
let set = WorkoutSet(
    id: UUID().uuidString,
    exerciseId: currentExercise.id,
    weight: 225,
    reps: 5,
    rpe: 8.5,
    isPersonalRecord: false,
    completedAt: Date()
)

liveVM.updateLiveWorkoutWithSet(set, forExercise: currentExercise)

// When switching exercises
liveVM.updateLiveWorkoutExercise(newExercise)
```

### Displaying Live Workout

```swift
struct WorkoutInProgressView: View {
    @ObservedObject var liveVM: LiveWorkoutViewModel
    
    var body: some View {
        if liveVM.isLiveWorkoutActive {
            LiveWorkoutView(viewModel: liveVM)
        }
    }
}
```

### Viewing Friend's Live Workout

```swift
@ObservedObject var liveVM: LiveWorkoutViewModel

// Subscribe to friend's live workout
if let liveWorkout = friendsLiveWorkout {
    liveVM.subscribToLiveWorkout(liveWorkout)
}

// Display with reactions enabled
LiveWorkoutView(viewModel: liveVM)
```

### Adding Reactions

```swift
// Manually add reaction
liveVM.addReaction("💪")

// Or use reaction buttons in LiveWorkoutView
```

### Handling Notifications

```swift
// Request notification permissions on app launch
ActivityNotificationService.shared.requestNotificationPermissions()

// Notify friend started live workout
ActivityNotificationService.shared.notifyFriendStartedLiveWorkout(
    user: friend,
    workoutName: "Leg Day"
)

// Notify reaction received
ActivityNotificationService.shared.notifyReactionReceived(
    reactor: friend,
    emoji: "🔥"
)
```

## Integration with Supabase Realtime

The `RealtimeDataSyncService` is currently a placeholder. To integrate with Supabase Realtime:

1. **Install Supabase SDK** (when available for iOS)
   ```
   pod install Supabase
   ```

2. **Replace WebSocket implementation** in `RealtimeDataSyncService`
   ```swift
   private let client = SupabaseClient(url: URL(string: "YOUR_SUPABASE_URL")!, apiKey: "YOUR_API_KEY")
   
   func setupRealtimeConnection() {
       let channel = client.realtime.channel("live-workouts:\(userId)")
       channel.on("broadcast", event: "update") { payload in
           self.handleRealtimeUpdate(payload)
       }
       channel.subscribe()
   }
   ```

3. **Create Supabase tables**
   ```sql
   CREATE TABLE live_workouts (
       id UUID PRIMARY KEY,
       user_id UUID REFERENCES auth.users,
       current_exercise_id UUID,
       current_set JSONB,
       viewers TEXT[],
       reactions JSONB[],
       created_at TIMESTAMP DEFAULT NOW(),
       updated_at TIMESTAMP DEFAULT NOW()
   );
   
   CREATE TABLE live_reactions (
       id UUID PRIMARY KEY,
       live_workout_id UUID REFERENCES live_workouts,
       user_id UUID REFERENCES auth.users,
       emoji TEXT,
       created_at TIMESTAMP DEFAULT NOW()
   );
   ```

4. **Enable Realtime** on these tables in Supabase dashboard

## Live Activity Integration (iOS 16.1+)

### Configuration in Xcode

1. **Enable Live Activities capability**
   - Signing & Capabilities → + Capability → "Live Activities"

2. **Add to Info.plist**
   ```xml
   <key>NSSupportsLiveActivities</key>
   <true/>
   ```

3. **Create ActivityWidget** in WidgetKit
   ```swift
   #Preview(as: .dynamicIsland(.compact)) {
       LiveWorkoutActivityWidget()
   } timeline: {
       LiveWorkoutActivityAttributes.ContentState(
           currentExercise: "Bench Press",
           completedSets: 3,
           totalSets: 4,
           currentWeight: 225,
           currentReps: 5,
           duration: 600,
           viewerCount: 2
       )
   }
   ```

### Usage

```swift
// Start live activity when workout begins
LiveActivityManager.shared.startLiveActivity(for: workout, user: currentUser)

// Update during workout
LiveActivityManager.shared.updateLiveActivity(
    currentExercise: "Bench Press",
    completedSets: 3,
    totalSets: 4,
    weight: 225,
    reps: 5,
    duration: 600,
    viewerCount: 2
)

// End when workout completes
LiveActivityManager.shared.endLiveActivity()
```

## Testing

Run the test suite:

```bash
cd XomFit
xcodebuild test -scheme XomFit -testPlan LiveWorkoutTests
```

Key test files:
- `XomFit/Tests/LiveWorkoutViewModelTests.swift` - ViewModel & service tests
- `XomFit/Tests/ReactionHandlingTests.swift` - Reaction logic tests
- `XomFit/Tests/RealtimeUpdatesTests.swift` - Real-time sync tests

## Known Limitations

1. **WebSocket Connection** - Currently uses timer simulation instead of actual WebSocket
2. **Supabase Integration** - Placeholder only, requires SDK integration
3. **Live Activity** - Requires iOS 16.1+ and app configuration
4. **Notifications** - Requires user permission and app installation

## Future Enhancements

- [ ] Integrate actual Supabase Realtime SDK
- [ ] Add video/photo sharing during workout
- [ ] Implement workout history/replays
- [ ] Add friend-following for notifications
- [ ] Implement workout leaderboards during live sessions
- [ ] Add customizable reactions/cheers
- [ ] Support group workouts with multiple broadcasters

## Files Modified/Created

### New Files
- `XomFit/Models/LiveWorkout.swift` - Live workout models
- `XomFit/ViewModels/LiveWorkoutViewModel.swift` - Main view model
- `XomFit/Services/RealtimeDataSyncService.swift` - Real-time sync
- `XomFit/Services/ActivityNotificationService.swift` - Notifications
- `XomFit/Services/LiveActivityManager.swift` - Live Activities
- `XomFit/Views/Workout/LiveWorkoutView.swift` - Main UI
- `XomFit/Views/Workout/LiveReactionView.swift` - Reaction UI
- `XomFit/Tests/LiveWorkoutViewModelTests.swift` - Tests

### Files to Update
- `XomFit/ViewModels/WorkoutViewModel.swift` - Add integration with live workout
- `XomFit/Views/Workout/WorkoutInProgressView.swift` - Add live workout button
- `XomFitApp.swift` - Initialize notification service

## API Reference

### LiveWorkoutViewModel

```swift
// Properties
@Published var liveWorkouts: [LiveWorkout]
@Published var currentLiveWorkout: LiveWorkout?
@Published var isLiveWorkoutActive: Bool
@Published var viewers: [LiveWorkoutViewer]
@Published var recentReactions: [LiveReaction]
@Published var connectionStatus: ConnectionStatus

// Methods
func startLiveWorkout(from: Workout, user: User)
func updateLiveWorkoutWithSet(_ set: WorkoutSet, forExercise: WorkoutExercise)
func updateLiveWorkoutExercise(_ exercise: WorkoutExercise)
func addReaction(_ emoji: String)
func subscribToLiveWorkout(_ liveWorkout: LiveWorkout)
func endLiveWorkout()
func fetchActiveLiveWorkouts() async
func getViewers() -> [LiveWorkoutViewer]
```

### ActivityNotificationService

```swift
// Notifications
func notifyFriendStartedLiveWorkout(_ user: User, workoutName: String)
func notifyReactionReceived(_ reactor: User, emoji: String, onYourWorkout: Bool)
func notifyViewerJoined(_ user: User)
func notifyFriendPersonalRecord(_ user: User, exercise: Exercise, weight: Double)
func notifyFriendFinishedWorkout(_ user: User, workoutStats: WorkoutStats)
```

### RealtimeDataSyncService

```swift
// Broadcast
func broadcastLiveWorkout(_ liveWorkout: LiveWorkout)
func broadcastSetCompleted(setData: WorkoutSet, exerciseData: WorkoutExercise, liveWorkoutId: String)
func broadcastExerciseChanged(exerciseData: WorkoutExercise, liveWorkoutId: String)
func broadcastReaction(_ reaction: LiveReaction, forLiveWorkoutId: String)
func broadcastWorkoutEnded(liveWorkoutId: String)

// Subscribe
func subscribeLiveWorkout(_ liveWorkout: LiveWorkout)

// Fetch
func fetchActiveLiveWorkouts() async throws -> [LiveWorkout]
```

## Support

For issues or questions about the Live Workout feature, please open a GitHub issue with the label `live-workout-mode`.
