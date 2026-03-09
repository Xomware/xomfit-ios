import SwiftUI

struct WorkoutCardView: View {
    let post: FeedPost
    let onLike: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header — User info + time
            HStack {
                Circle()
                    .fill(Theme.accent.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(post.user.displayName.prefix(1)))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Theme.accent)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.user.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                    Text(post.createdAt.timeAgo)
                        .font(Theme.fontCaption)
                        .foregroundColor(Theme.textSecondary)
                }
                
                Spacer()
                
                if post.workout.totalPRs > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "trophy.fill")
                            .foregroundColor(Theme.prGold)
                            .font(.system(size: 12))
                        Text("PR!")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.prGold)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.prGold.opacity(0.15))
                    .cornerRadius(Theme.cornerRadiusSmall)
                }
            }
            
            // Workout Name
            Text(post.workout.name)
                .font(Theme.fontHeadline)
                .foregroundColor(Theme.textPrimary)
            
            // Stats Row
            HStack(spacing: 20) {
                StatBadge(icon: "clock", value: post.workout.durationString, label: "Duration")
                StatBadge(icon: "flame.fill", value: post.workout.formattedVolume, label: "Volume")
                StatBadge(icon: "number", value: "\(post.workout.totalSets)", label: "Sets")
                StatBadge(icon: "figure.strengthtraining.traditional", value: "\(post.workout.exercises.count)", label: "Exercises")
            }
            
            // Exercise Summary
            VStack(alignment: .leading, spacing: 6) {
                ForEach(post.workout.exercises) { ex in
                    HStack {
                        Text(ex.exercise.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Theme.textPrimary)
                        Spacer()
                        if let best = ex.bestSet {
                            Text(best.displaySet)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Theme.accent)
                        }
                    }
                }
            }
            .padding(12)
            .background(Theme.secondaryBackground)
            .cornerRadius(Theme.cornerRadiusSmall)
            
            // Actions
            HStack(spacing: 24) {
                Button(action: onLike) {
                    HStack(spacing: 6) {
                        Image(systemName: post.isLiked ? "heart.fill" : "heart")
                            .foregroundColor(post.isLiked ? .red : Theme.textSecondary)
                        Text("\(post.likes)")
                            .foregroundColor(Theme.textSecondary)
                    }
                    .font(.system(size: 14))
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "bubble.left")
                        .foregroundColor(Theme.textSecondary)
                    Text("\(post.comments.count)")
                        .foregroundColor(Theme.textSecondary)
                }
                .font(.system(size: 14))
                
                Spacer()
                
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(Theme.textSecondary)
                    .font(.system(size: 14))
            }
        }
        .cardStyle()
    }
}

struct StatBadge: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(Theme.accent)
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Theme.textPrimary)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Theme.textSecondary)
        }
    }
}
