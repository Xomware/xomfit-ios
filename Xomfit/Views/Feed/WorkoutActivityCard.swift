import SwiftUI

struct WorkoutActivityCard: View {
    let post: FeedPost
    let onLikeTap: () -> Void
    @State private var showComments = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.paddingSmall) {
            // Header with user info
            HStack(spacing: Theme.paddingSmall) {
                // Avatar placeholder
                Circle()
                    .fill(Theme.accentColor.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Text(String(post.user.displayName.prefix(1)))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Theme.accentColor)
                    }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.user.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Text(post.user.username)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Text(post.createdAt.timeAgoDisplay)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            
            // Workout info
            VStack(alignment: .leading, spacing: Theme.paddingSmall) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(post.workout.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        HStack(spacing: Theme.paddingMedium) {
                            Label(post.workout.durationString, systemImage: "clock")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            
                            Label("\(post.workout.totalSets) sets", systemImage: "list.number")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            
                            Label("\(post.workout.formattedVolume) lbs", systemImage: "scalemass")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                    
                    if post.workout.totalPRs > 0 {
                        VStack(alignment: .center, spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.accentColor)
                            Text("\(post.workout.totalPRs)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                            Text("PRs")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, Theme.paddingSmall)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(8)
                    }
                }
                
                // Exercise preview
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(post.workout.exercises.prefix(2)) { exercise in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(exercise.exercise.name)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                                
                                if let bestSet = exercise.bestSet {
                                    Text("\(Int(bestSet.weight)) lbs × \(bestSet.reps)")
                                        .font(.system(size: 11))
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Spacer()
                            
                            if exercise.sets.contains(where: { $0.isPersonalRecord }) {
                                HStack(spacing: 2) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 10))
                                    Text("PR")
                                        .font(.system(size: 10, weight: .semibold))
                                }
                                .foregroundColor(Theme.accentColor)
                            }
                        }
                        .padding(.horizontal, Theme.paddingSmall)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.02))
                        .cornerRadius(6)
                    }
                    
                    if post.workout.exercises.count > 2 {
                        Text("+\(post.workout.exercises.count - 2) more")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                            .padding(.horizontal, Theme.paddingSmall)
                    }
                }
            }
            .padding(Theme.paddingSmall)
            .background(Color.white.opacity(0.03))
            .cornerRadius(10)
            
            // Notes
            if let notes = post.workout.notes, !notes.isEmpty {
                Text(notes)
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .padding(.horizontal, Theme.paddingSmall)
            }
            
            // Engagement
            HStack(spacing: Theme.paddingMedium) {
                Button(action: onLikeTap) {
                    HStack(spacing: 4) {
                        Image(systemName: post.isLiked ? "heart.fill" : "heart")
                            .foregroundColor(post.isLiked ? .red : .gray)
                        Text("\(post.likes)")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
                
                Button(action: { showComments.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right")
                            .foregroundColor(.gray)
                        Text("\(post.comments.count)")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
                
                Button(action: {}) {
                    HStack(spacing: 4) {
                        Image(systemName: "paperplane")
                            .foregroundColor(.gray)
                        Text("Share")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, Theme.paddingSmall)
            
            // Comments preview
            if !post.comments.isEmpty && !showComments {
                VStack(alignment: .leading, spacing: Theme.paddingSmall) {
                    Divider()
                        .background(.white.opacity(0.1))
                    
                    ForEach(post.comments.prefix(2)) { comment in
                        HStack(alignment: .top, spacing: Theme.paddingSmall) {
                            Circle()
                                .fill(Theme.accentColor.opacity(0.2))
                                .frame(width: 24, height: 24)
                                .overlay {
                                    Text(String(comment.user.displayName.prefix(1)))
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(Theme.accentColor)
                                }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(comment.user.displayName)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                Text(comment.text)
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    
                    if post.comments.count > 2 {
                        Text("View all \(post.comments.count) comments")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.accentColor)
                    }
                }
                .padding(.horizontal, Theme.paddingSmall)
            }
        }
        .padding(Theme.paddingMedium)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .sheet(isPresented: $showComments) {
            CommentThreadView(post: post)
        }
    }
}

#Preview {
    WorkoutActivityCard(
        post: FeedPost.mockFeed[0],
        onLikeTap: {}
    )
    .padding()
    .background(Theme.background)
}
