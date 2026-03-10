import Foundation
import ActivityKit
import SwiftUI

/// Manages Live Activities for real-time workout display on Lock Screen
/// Requires iOS 16.1+ and the app to be configured for Live Activities
@available(iOS 16.1, *)
class LiveActivityManager: NSObject {
    static let shared = LiveActivityManager()
    
    private var currentLiveActivity: Activity<LiveWorkoutActivityAttributes>?
    
    // MARK: - Live Activity Management
    
    /// Start a new live activity for the current workout
    func startLiveActivity(for workout: Workout, user: AppUser) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities are not enabled")
            return
        }
        
        let attributes = LiveWorkoutActivityAttributes(
            userId: user.id,
            userName: user.displayName,
            workoutName: workout.name
        )
        
        let initialState = LiveWorkoutActivityAttributes.ContentState(
            currentExercise: workout.exercises.first?.exercise.name ?? "Starting...",
            completedSets: 0,
            totalSets: workout.exercises.reduce(0) { $0 + max(1, $1.sets.count) },
            currentWeight: 0,
            currentReps: 0,
            duration: 0,
            viewerCount: 0
        )
        
        do {
            currentLiveActivity = try Activity<LiveWorkoutActivityAttributes>.request(
                attributes: attributes,
                contentState: initialState,
                pushType: .token
            )
            print("Live Activity started: \(currentLiveActivity?.id ?? "unknown")")
        } catch {
            print("Failed to start live activity: \(error.localizedDescription)")
        }
    }
    
    /// Update the live activity with new set information
    func updateLiveActivity(
        currentExercise: String,
        completedSets: Int,
        totalSets: Int,
        weight: Double,
        reps: Int,
        duration: TimeInterval,
        viewerCount: Int
    ) {
        guard let activity = currentLiveActivity else { return }
        
        let updatedState = LiveWorkoutActivityAttributes.ContentState(
            currentExercise: currentExercise,
            completedSets: completedSets,
            totalSets: totalSets,
            currentWeight: weight,
            currentReps: reps,
            duration: duration,
            viewerCount: viewerCount
        )
        
        Task {
            await activity.update(using: updatedState)
        }
    }
    
    /// End the live activity
    func endLiveActivity() {
        guard let activity = currentLiveActivity else { return }
        
        let finalState = LiveWorkoutActivityAttributes.ContentState(
            currentExercise: "Workout Complete!",
            completedSets: 0,
            totalSets: 0,
            currentWeight: 0,
            currentReps: 0,
            duration: 0,
            viewerCount: 0
        )
        
        Task {
            await activity.end(using: finalState, dismissalPolicy: .immediate)
            currentLiveActivity = nil
        }
    }
    
    /// Push a live activity update (for remote notifications)
    func pushLiveActivityUpdate(_ token: Data) {
        // Send this token to your server for push updates
        let tokenString = token.map { String(format: "%02x", $0) }.joined()
        print("Live Activity Push Token: \(tokenString)")
    }
}

// MARK: - Live Activity Attributes & State

/// Attributes for the live workout live activity
struct LiveWorkoutActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let currentExercise: String
        let completedSets: Int
        let totalSets: Int
        let currentWeight: Double
        let currentReps: Int
        let duration: TimeInterval
        let viewerCount: Int

        var formattedDuration: String {
            let minutes = Int(duration / 60)
            if minutes < 60 {
                return "\(minutes)m"
            }
            return "\(minutes / 60)h \(minutes % 60)m"
        }

        var progressPercentage: Double {
            totalSets > 0 ? Double(completedSets) / Double(totalSets) : 0
        }
    }

    let userId: String
    let userName: String
    let workoutName: String
}

// MARK: - Lock Screen UI Component (SwiftUI)

@available(iOS 16.1, *)
struct LiveWorkoutLockScreenView: View {
    let state: LiveWorkoutActivityAttributes.ContentState
    let attributes: LiveWorkoutActivityAttributes
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with name and time
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(attributes.userName)
                        .font(.headline)
                        .lineLimit(1)
                    Text(attributes.workoutName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Viewer count
                HStack(spacing: 2) {
                    Image(systemName: "eye.fill")
                    Text("\(state.viewerCount)")
                        .font(.caption)
                }
                .foregroundColor(.blue)
            }
            
            // Current exercise
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(state.currentExercise)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        Text("\(Int(state.currentWeight)) lbs")
                            .font(.headline)
                        Text("×\(state.currentReps)")
                            .font(.headline)
                    }
                }
                
                Spacer()
                
                // Progress indicator
                VStack(alignment: .center, spacing: 2) {
                    Circle()
                        .trim(from: 0, to: state.progressPercentage)
                        .stroke(Color.green, lineWidth: 3)
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(state.completedSets)/\(state.totalSets)")
                        .font(.caption2)
                        .fontWeight(.bold)
                }
            }
            
            // Time elapsed
            HStack {
                Image(systemName: "clock")
                    .font(.caption)
                Text(state.formattedDuration)
                    .font(.caption)
            }
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
}
