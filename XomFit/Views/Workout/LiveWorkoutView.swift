import SwiftUI

/// Main view for displaying live workout with active lifter and real-time updates
struct LiveWorkoutView: View {
    @ObservedObject var viewModel: LiveWorkoutViewModel
    @State private var showReactions = false
    @State private var selectedReaction: String?
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(UIColor.systemBackground),
                    Color(UIColor.systemGray6)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with user info and duration
                if let liveWorkout = viewModel.currentLiveWorkout {
                    LiveWorkoutHeaderView(liveWorkout: liveWorkout)
                        .padding()
                        .background(Color(UIColor.systemBackground))
                }
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Current exercise display
                        if let exercise = viewModel.currentLiveWorkout?.currentExercise {
                            LiveExerciseCardView(exercise: exercise)
                                .padding()
                        }
                        
                        // Current set stats
                        if let set = viewModel.currentLiveWorkout?.currentSet {
                            LiveSetStatsView(set: set)
                                .padding()
                        }
                        
                        // Viewers list
                        LiveViewersView(viewers: viewModel.viewers)
                            .padding()
                        
                        // Recent reactions
                        RecentReactionsView(viewModel: viewModel)
                    }
                }
                
                // Reaction buttons at bottom
                LiveReactionInputView { emoji in
                    viewModel.addReaction(emoji)
                }
            }
            
            // Connection status indicator
            VStack {
                if viewModel.connectionStatus != .connected {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(viewModel.connectionStatus == .connecting ? Color.orange : Color.red)
                            .frame(width: 8, height: 8)
                        
                        Text(viewModel.connectionStatus.rawValue.capitalized)
                            .font(.caption)
                    }
                    .padding(8)
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(6)
                    .padding()
                }
                
                Spacer()
            }
        }
    }
}

/// Header showing user info and live status
struct LiveWorkoutHeaderView: View {
    let liveWorkout: LiveWorkout
    @State private var isLive = true
    
    var body: some View {
        HStack(spacing: 12) {
            // User avatar placeholder
            Circle()
                .fill(Color.blue.opacity(0.3))
                .frame(width: 44, height: 44)
                .overlay(
                    Text("👤")
                        .font(.system(size: 24))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(liveWorkout.user?.displayName ?? "Unknown")
                        .font(.headline)
                    
                    // Live indicator
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                        
                        Text("LIVE")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }
                }
                
                Text(liveWorkout.durationString)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Viewer count
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 2) {
                    Image(systemName: "eye.fill")
                        .font(.caption)
                    Text("\(liveWorkout.viewerCount)")
                        .font(.headline)
                }
                
                Text("watching")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

/// Card displaying current exercise information
struct LiveExerciseCardView: View {
    let exercise: WorkoutExercise
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Exercise")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(exercise.exercise.name)
                        .font(.headline)
                }
                
                Spacer()
                
                // Muscle groups
                HStack(spacing: 4) {
                    ForEach(exercise.exercise.muscleGroups.prefix(2), id: \.self) { muscle in
                        Text(muscle.emoji)
                            .font(.caption)
                    }
                }
            }
            
            Divider()
            
            // Exercise details
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sets")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(exercise.sets.count)")
                        .font(.headline)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Best Set")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let best = exercise.bestSet {
                        Text("\(Int(best.weight)) × \(best.reps)")
                            .font(.headline)
                    } else {
                        Text("—")
                            .font(.headline)
                    }
                }
                
                Spacer()
                
                if exercise.sets.contains(where: { $0.isPersonalRecord }) {
                    VStack(alignment: .center, spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        
                        Text("PR")
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

/// Display current set statistics
struct LiveSetStatsView: View {
    let set: WorkoutSet
    @State private var scale: CGFloat = 1
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Current Set")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 20) {
                StatItem(
                    label: "Weight",
                    value: "\(Int(set.weight))",
                    unit: "lbs",
                    icon: "dumbbell.fill",
                    color: .blue
                )
                
                StatItem(
                    label: "Reps",
                    value: "\(set.reps)",
                    unit: "reps",
                    icon: "repeat",
                    color: .green
                )
                
                if let rpe = set.rpe {
                    StatItem(
                        label: "RPE",
                        value: String(format: "%.1f", rpe),
                        unit: "/10",
                        icon: "bolt.fill",
                        color: .orange
                    )
                }
            }
            
            if set.isPersonalRecord {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.red)
                    Text("Personal Record! 🎉")
                        .font(.headline)
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .scaleEffect(scale)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                scale = 1
            }
        }
    }
}

/// Individual stat item component
struct StatItem: View {
    let label: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            HStack(spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
}

/// Display list of viewers watching the workout
struct LiveViewersView: View {
    let viewers: [LiveWorkoutViewer]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewers.isEmpty {
                HStack {
                    Image(systemName: "person.slash")
                        .foregroundColor(.secondary)
                    Text("No one watching yet")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(8)
            } else {
                Text("Watching (\(viewers.count))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 8) {
                    ForEach(viewers.prefix(5), id: \.id) { viewer in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.blue.opacity(0.3))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Text("👤")
                                        .font(.caption)
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(viewer.user?.displayName ?? "Unknown")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                
                                Text("Joined \(timeAgo(from: viewer.joinedAt))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                    
                    if viewers.count > 5 {
                        Text("and \(viewers.count - 5) more")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
    }
    
    private func timeAgo(from date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        
        if seconds < 60 {
            return "just now"
        } else if seconds < 3600 {
            let minutes = Int(seconds / 60)
            return "\(minutes)m ago"
        } else {
            let hours = Int(seconds / 3600)
            return "\(hours)h ago"
        }
    }
}

/// Input view for reactions
struct LiveReactionInputView: View {
    let onReactionTapped: (String) -> Void
    
    private let reactions = ["💪", "🔥", "👏", "🎯", "😤", "🙌"]
    
    var body: some View {
        VStack(spacing: 8) {
            Divider()
            
            HStack(spacing: 8) {
                ForEach(reactions, id: \.self) { emoji in
                    Button(action: {
                        onReactionTapped(emoji)
                    }) {
                        Text(emoji)
                            .font(.system(size: 24))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color(UIColor.systemGray5))
                            .cornerRadius(8)
                    }
                }
            }
            .padding()
        }
        .background(Color(UIColor.systemBackground))
    }
}

#Preview {
    LiveWorkoutView(viewModel: LiveWorkoutViewModel(userId: "preview-user"))
}
